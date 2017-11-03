#!/bin/bash
#
# mkubectl.sh
#
# A utility control script for working with minikube for development
#
# Make sure you have DEV_UTILS_PATH, NEWTON_PATH set
#
if [ -z $NEWTON_PATH ]; then
    echo "You have not set the environment variable NEWTON_PATH. Please set."
    echo ""
    echo "For example:"
    echo "    export NEWTON_PATH=/Users/danvir/Masterbox/sideprojects/github/newtonsystems/"
    echo ""
    exit
fi

if [ -z $DEV_UTILS_PATH ]; then
    echo "You have not set the environment variable DEV_UTILS_PATH. Please set."
    echo ""
    echo "For example:"
    echo "    export DEV_UTILS_PATH=/Users/danvir/Masterbox/sideprojects/github/newtonsystems/dev-utils/"
    echo ""
    exit
fi

. $DEV_UTILS_PATH/common/bash-colours.sh


CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
TIMESTAMP=$(date +%s )

# Usage
usage ()
{
	echo "mkubectl.sh (
    --hot-reload-deployment|  Hot-reloaded swap of deployment for <service>
    --swap-deployment|
    --compile|
    --shell
  )"
}

# ------------------------------------------------------------------------------
# Useful CircleCI commands

# circleci-build-push-to-dockerhub: Builds and pushs docker image for go application
circleci-build-push-to-dockerhub()
{
  if [ -z $DOCKER_USER ]; then
      echo "You have not set the environment variable DOCKER_USER. Please set."
      exit
  fi

  if [ -z $DOCKER_PASS ]; then
      echo "You have not set the environment variable DOCKER_PASS. Please set."
      exit
  fi

  if [ -z $DOCKER_PROJECT_NAME ]; then
      echo "You have not set the environment variable DOCKER_PROJECT_NAME. Please set."
      exit
  fi

  if [ -z $CIRCLE_BRANCH ]; then
      echo "You have not set the environment variable CIRCLE_BRANCH. Please set."
      exit
  fi

  echo -e "$INFO Updating & installing dependencies ..."
  update
  install

  echo -e "$INFO Building go binary ..."
  # Cannot use volumes in circleci so we cant use 'make build-build'
  docker build -t $DOCKER_PROJECT_NAME:compile -f Dockerfile.build .
  docker run --name compiler $DOCKER_PROJECT_NAME:compile
  docker cp compiler:/go/src/github.com/newtonsystems/agent-mgmt/main $PWD

  echo -e "$INFO Building docker image and then push to dockerhub ..."
  docker build -t newtonsystems/$DOCKER_PROJECT_NAME:$CIRCLE_BRANCH .
  docker login -u $DOCKER_USER -p $DOCKER_PASS
  docker push newtonsystems/$DOCKER_PROJECT_NAME:$CIRCLE_BRANCH

  # Push "latest" tag if in master branch
  if [ "${CIRCLE_BRANCH}" == "master" ]; then
      docker tag newtonsystems/$DOCKER_PROJECT_NAME:$CIRCLE_BRANCH newtonsystems/$DOCKER_PROJECT_NAME:latest
      docker push newtonsystems/$DOCKER_PROJECT_NAME:latest
  fi

}

# circleci-go-run-tests: Runs go tests & saves report (for use in CircleCI only)
# You must have a 'check' in your Makefile + the env variable TEST_REPORTS
circleci-go-run-tests()
{
  if [[ ! -f Makefile ]]; then
      echo "You do NOT have a Makefile in the current working directory."
      exit 1
  fi

  if [[ $(grep 'check:' Makefile | wc -l) -eq 0 ]]; then
      echo -e "$ERROR It looks like you haven't got a 'check' target in your Makefile."
      echo -e "The 'check' target should run go tests for your current repo."
      exit 1
  fi

  if [ -z $TEST_REPORTS ]; then
      echo "You have not set the environment variable TEST_REPORTS. Please set."
      exit 1
  fi

  echo -e "Updating and installing dependencies"
  update
  install

  mkdir -p $TEST_REPORTS
  trap "go-junit-report <${TEST_REPORTS}/go-test.out > ${TEST_REPORTS}/go-test-report.xml" EXIT
  make check | tee ${TEST_REPORTS}/go-test.out
}

# ------------------------------------------------------------------------------
# Useful debug/inspection commands

# shell-debug: Run shell through telepresence (to debug and print some useful help)
shell-tele() {
  telepresence --port $1
}

# shell: Run shell through kubectl
shell ()
{
  running_pods=$(kubectl get pods -o go-template='{{range $items := .items}}{{if eq .status.phase "Running"}}{{range .spec.containers}}{{if eq .name "'$1'"}}{{$items.metadata.name}} {{end}}{{end}}{{end}}{{end}}')
  pod_count=$(echo $running_pods | wc -w | xargs)
  if [[ $pod_count -eq 1 ]]; then
    kubectl exec $running_pods -it -- run.sh --kill-go ./server.go 50000
  fi

}

# ------------------------------------------------------------------------------
# Dependencies commands for go application

# --- Utils Functions for Dependencies ---

# update-deps-env: Updates glide dependencies
update-deps-env ()
{
  if [[ ! -f $1.lock || ! -f $1.yaml ]]; then
      echo -e "$ERROR File '$1.lock' or '$1.yaml' not found in current working directory!"
      return
  fi
  rm -rf ./.glide
	echo -e "$INFO Updating dependencies for $1 environment"
	cp $1.lock glide.lock
	glide -y $1.yaml update --force
	cp glide.lock $1.lock
}

# install-deps-env: Install glide dependencies
install-deps-env ()
{
  if [[ ! -f $1.lock || ! -f $1.yaml ]]; then
      echo -e "$ERROR File '$1.lock' or '$1.yaml' not found in current working directory!"
      return
  fi
	echo -e "$INFO Installing dependencies for $1 environment"
  cp $1.lock glide.lock
	glide -y $1.yaml install
	cp glide.lock $1.lock
}

# --- End of utils functions ---

# update: Updates dependencies based off the branch of the repo
update()
{
  echo -e "$INFO Updating go packages via glide ..."
  if [[ "$CURRENT_BRANCH" != "master" && "$CURRENT_BRANCH" != "featuretest" ]]; then
    echo -e "$INFO using branch ${BLUE}master${NO_COLOUR} ... "
    update-deps-env "master"
  else
      echo -e "$INFO using branch ${BLUE}$CURRENT_BRANCH${NO_COLOUR} ... "
      update-deps-env "$CURRENT_BRANCH"
  fi
}

# install: Installs dependencies based off the branch of the repo
install()
{
  echo -e "$INFO Installing go packages via glide ..."
  if [[ "$CURRENT_BRANCH" != "master" && "$CURRENT_BRANCH" != "featuretest" ]]; then
    echo -e "$INFO using branch ${BLUE}master${NO_COLOUR} ... "
    install-deps-env "master"
  else
      echo -e "$INFO using branch ${BLUE}$CURRENT_BRANCH${NO_COLOUR} ... "
      install-deps-env "$CURRENT_BRANCH"
  fi
}

# ------------------------------------------------------------------------------
# Logging commands

# Scenarios:
# If a pod we are tailing get deleted we want to automatically switch to the new pod's log
# If the pod is not ready yet - example the container is being created
# quite often we will have two pods one terminating and one creating we need to connect
# to the right one at the right time
# If we have multiple we want to know
# FUTURE: With multiple we may want to tail multiple logs instead (Need some investigation)
# $1 - REPO_NAME/SERVICE_NAME
update-tail-when-ready() {
  if [[ -z $1 ]]; then
      echo -e "$ERROR Failed to set service/repo name. Will not tail log."
      echo -e "$INFO Attach logs: ${RED}off${NO_COLOUR}"
      return
  fi
  echo -e "$INFO Attach logs: ${GREEN}on${NO_COLOUR}"

  while true; do
    sleep 60
    TAIL_PS=`ps aux |grep "kubectl logs -f $1" | grep -v grep | awk '{print $2}'`
    POD_NAME=`ps aux |grep "kubectl logs -f $1" | grep -v grep | sed -n -e 's/^.*\('$1'\)/\1/p'`

    if [  -z "$TAIL_PS" ]; then
      running_pods=$(kubectl get pods -o go-template='{{range $items := .items}}{{if eq .status.phase "Running"}}{{range .spec.containers}}{{if eq .name "'$1'"}}{{$items.metadata.name}} {{end}}{{end}}{{end}}{{end}}')
      pod_count=$(echo $running_pods | wc -w | xargs)
      ((VERBOSE)) && echo -e "$INFO No current tail for $1 (Found running pods: ${BLUE}$running_pods${NO_COLOUR}  count: ${BLUE}$pod_count${NO_COLOUR})"

      if [[ "$pod_count" -eq 0 ]]; then
        # If no running pods found we want to double check info
        # status.phase is not as accurate as -o wide information we need better information
        echo -e "$INFO Currently no pods for $1 to attach logs to ..."
      elif [[ "$pod_count" -eq 1 ]]; then
        ((VERBOSE)) && echo -e "$INFO Currently one pod running for $1 ..."
        status=$(kubectl get pods $running_pods -o wide | grep -e "$1" |  awk '{print $3}')

        if [[ "$status" == "Running" ]]; then
          echo -e "$INFO Attaching logs to ${BLUE}$running_pods${NO_COLOUR}"
          kubectl logs -f $running_pods &
          continue
        fi

        echo -e "$INFO ${BLUE}$running_pods${NO_COLOUR} is currently ${BLUE}'$status'${NO_COLOUR} will not attach this time ..."
      else
        echo -e "$INFO Doing nothing - multiple pods ($pod_count) found ... "
      fi
    else
      running_pods=$(kubectl get pods -o go-template='{{range $items := .items}}{{if eq .status.phase "Running"}}{{range .spec.containers}}{{if eq .name "'$1'"}}{{$items.metadata.name}} {{end}}{{end}}{{end}}{{end}}')
      pod_count=$(echo $running_pods | wc -w | xargs)
      ((VERBOSE)) && echo -e "$INFO Found existing tail for $1: ${BLUE}${POD_NAME}${NO_COLOUR} (Found running pods: ${BLUE}$running_pods${NO_COLOUR}  count: ${BLUE}$pod_count${NO_COLOUR})"

      if [[ "$pod_count" -eq 0 ]]; then
        ((VERBOSE)) && echo -e "$INFO Currently no pods for $1 to attach logs to so we kill existing tail ..."
        kill $TAIL_PS || true
      elif [[ "$pod_count" -eq 1 ]]; then
        running_pods="$(echo "$running_pods" | tr -d ' ')"
        ((VERBOSE)) && echo -e "$INFO Found one pod: $running_pods"
        if [[ "$running_pods" == "$POD_NAME" ]]; then
          echo -e "$INFO Attached log ${GREEN}ok${NO_COLOUR}"
        else
          echo -e "$INFO Attached log ${RED}old${NO_COLOUR}"
          ((VERBOSE)) && echo -e "$INFO Replacing attached log with a tail to ${BLUE}$running_pods${NO_COLOUR} (was to $POD_NAME)"
          kill $TAIL_PS || true
          kubectl logs -f $running_pods &
        fi
      else
        echo -e "$INFO Doing nothing - multiple pods ($pod_count) found ... "
      fi
    fi
  done
}

# ------------------------------------------------------------------------------
# Compile commands
# Used inside docker container to build the executable for the correct platform

#
# Creates binary
#
# $1 - The .go file to compile to an executable
build-binary()
{
  echo -e "$INFO Compiling $1 to create executable ${BLUE}./main${NO_COLOUR} "
  CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main $1
}

#
# Compiles go application
#
# $1 - The .go file to compile to an executable
compile()
{
  update
  install
  build-binary $1
}

# ------------------------------------------------------------------------------
# Minikube local development

# --- Utils Functions for local development ---

# Generic swap minikube deployment with image
# $1 - service name / repo name
# $2 - k8s deployment filename in $NEWTON_PATH/devops/k8s/deploy/local/ folder
# $3 - docker image in the normal docker form <reponame>:<tag>
swap-deployment() {
  kubectl replace -f $NEWTON_PATH/devops/k8s/deploy/local/$2
	kubectl set image -f $NEWTON_PATH/devops/k8s/deploy/local/$2 $1=$3

  update-tail-when-ready $1
}

check_probe_port() {
  DEBUG_PORT=`kubectl get svc $1 -o jsonpath='{.spec.ports[?(@.name=="debug")].nodePort}'`
  ((VERBOSE)) && echo -e "$INFO Debug port for $1: $DEBUG_PORT"

  if [[ -z "$DEBUG_PORT" ]]; then
    echo -e "$WARN No debug port found for service: $1. Will not monitor port."
    echo -e "$INFO Debug port check: ${RED}off${NO_COLOUR}"
    return
  fi
  echo -e "$INFO Debug port check: ${GREEN}on${NO_COLOUR}"

  while true; do
    sleep 120
    nc -z `minikube ip` $DEBUG_PORT  > /dev/null 2>&1 && echo -e "$INFO debug port (Readiness/Live) ${GREEN}up${NO_COLOUR}" && continue
    echo -e "$INFO Debug port ($DEBUG_PORT) (Readiness/Live) ${RED}down${NO_COLOUR} "
  done
}

check_health_probe() {
  DEBUG_PORT=`kubectl get svc $1 -o jsonpath='{.spec.ports[?(@.name=="debug")].nodePort}'`
  ((VERBOSE)) && echo -e "$INFO Debug port for $1: $DEBUG_PORT"

  if [[ -z "$DEBUG_PORT" ]]; then
    echo -e "$WARN No debug port found for service: $1. Will not monitor healthz probe."
    echo -e "$INFO Healthz probe check: ${RED}off${NO_COLOUR}"
    return
  fi
  echo -e "$INFO Healthz probe check: ${GREEN}on${NO_COLOUR}"

  while true; do
    sleep 120

    if [[ "$(curl -s $(minikube ip):$DEBUG_PORT/healthz)" == "ok" ]]; then
      status="${GREEN}ok${NO_COLOUR}"
    else
      status="${RED}fail${NO_COLOUR}"
    fi

    echo -e "$INFO Probe healthz $status"
  done
}

check_started_probe() {
  DEBUG_PORT=`kubectl get svc $1 -o jsonpath='{.spec.ports[?(@.name=="debug")].nodePort}'`
  ((VERBOSE)) && echo -e "$INFO Debug port for $1: $DEBUG_PORT"

  if [[ -z "$DEBUG_PORT" ]]; then
    echo -e "$WARN No debug port found for service: $1. Will not monitor started probe."
    echo -e "$INFO Started probe check: ${RED}off${NO_COLOUR}"
    return
  fi
  echo -e "$INFO Started probe check: ${GREEN}on${NO_COLOUR}"

  while true; do
    sleep 120
    started=$(curl -s $(minikube ip):$DEBUG_PORT/started)
    if [[ -z "$started" ]]; then
      started="${RED}fail${NO_COLOUR}"
    else
      started="${BLUE}$started${NO_COLOUR}"
    fi
    echo -e "$INFO Probe started $started"
  done
}

kill-app ()
{
  running_pods=$(kubectl get pods -o go-template='{{range $items := .items}}{{if eq .status.phase "Running"}}{{range .spec.containers}}{{if eq .name "'$1'"}}{{$items.metadata.name}} {{end}}{{end}}{{end}}{{end}}')
  pod_count=$(echo $running_pods | wc -w | xargs)
  if [[ $pod_count -eq 1 ]]; then
    kubectl exec $running_pods -it -- run.sh --kill-go ./server.go 50000
  elif [[ $pod_count -eq 0 ]]; then
    echo -e "$ERROR No pods found - therefore cant kill app ..."
  else
    echo -e "$ERROR Multiple pods found - not sure what action to take, bailing ..."
  fi

}

# --- End of utils functions ---

# hot-reload-deployment: Replace image with local repo (hot-reloaded) for fast development
# $1 - REPO
# $2 - LOCAL_DEPLOYMENT_FILENAME
# $3 - watch dir/files
# EXPECT HEALTHZ PROBE ON DEPLOYMENT
hot-reload-deployment()
{
  check-setup.sh
  if [ $? -ne 0 ]; then
    echo -e "$ERROR Minikube/Docker not setup up correctly ... "
    return
  fi

  if [[ ! -f $3 ]]; then
      echo -e "$ERROR File '$1' not found in current working directory!"
      return
  fi


  action="${BLUE}Installing${NO_COLOUR}"
  ((UPDATE)) && action="${BLUE}Updating${NO_COLOUR} and ${BLUE}installing${NO_COLOUR}"
  echo -e "$INFO $action dependencies ..."
  ((UPDATE)) && update
  install

  eval `minikube docker-env`
  echo -e "$INFO Entering ${BLUE}$NEWTON_PATH/dev-utils/docker${NO_COLOUR} to build dev docker image ..."
  pushd $NEWTON_PATH/dev-utils/docker > /dev/null

  docker image build -t newtonsystems/$1:kube-dev \
    --build-arg GO_MAIN=$3 \
    --build-arg GO_PORT=$4 \
    --build-arg REPO_DIR=/go/src/github.com/newtonsystems/$1 \
    -f Dockerfile.dev .

  if [[ $? -ne 0 ]] ; then
    echo -e "$ERROR Failed to build docker image."
    exit 1
  fi

  popd > /dev/null

  kubectl replace --force -f $NEWTON_PATH/devops/k8s/deploy/local/$2
	kubectl set image -f $NEWTON_PATH/devops/k8s/deploy/local/$2 $1=newtonsystems/$1:kube-dev

  update-tail-when-ready $1 &

  check_probe_port $1 &
  check_started_probe $1 &
  check_health_probe $1 &

  echo -e "$INFO Watching for changes to ${BLUE}$PWD${NO_COLOUR} ... "
  fswatch $PWD | while read; do
     echo -e "$INFO Detected a change, killing app to restart $3 on port $4"
     kill-app $1
  done
}

# swap-deployment-with-latest-release-image: Swap deployment with the latest release.
# Useful for debugging an issue (as a comparison)
# $1 - service name  / repo name
# $2 - k8s deployment filename in $NEWTON_PATH/devops/k8s/deploy/local/ folder
swap-deployment-with-latest-release-image() {
  echo -e "$INFO Running the most up-to-date image for branch ${CURRENT_BRANCH}"
  image="newtonsystems/$1:$(CURRENT_RELEASE_VERSION)"
  echo -e "$INFO Attempting to use image: $image"

  echo -n "${BLUE}"
  eval `minikube docker-env`
  docker pull $image;
  echo -n "${NO_COLOUR}"

  swap-deployment-image $1 $2 $image
}

# swap-deployment-with-latest-image: Swap deployment with the latest image based on the current branch.
# Useful for debugging an issue (as a comparison)
# $1 - service name  / repo name
# $2 - k8s deployment filename in $NEWTON_PATH/devops/k8s/deploy/local/ folder
swap-deployment-with-latest-image() {
  echo -e "$INFO Running the most up-to-date image for branch ${CURRENT_BRANCH}"
  image="newtonsystems/$1:${CURRENT_BRANCH}"
  echo -e "$INFO Attempting to use image: $image"

  eval `minikube docker-env`
  docker pull $image
  if [[ $? -ne 0 ]] ; then
    echo -e "$WARN Failed to find image in registry: $image"; \
    read -r -p "${GREEN} Specific your own image name or Ctrl+C to exit:${NO_COLOUR}   " reply; \

    image="newtonsystems/$(REPO):$reply;"
    docker pull $image;

    if [[ $? -ne 0 ]]; then
      echo -e "$ERROR failed to pull $image"
      exit 1
    fi
  fi

  swap-deployment-image $1 $2 $image
}

# swap-deployment-with-custom-image: Swap deployment with the latest release.
# Useful for debugging an issue
# $1 - service name  / repo name
# $2 - k8s deployment filename in $NEWTON_PATH/devops/k8s/deploy/local/ folder
# $3 - docker image in the normal docker form <reponame>:<tag>
swap-deployment-with-custom-image() {
  swap-deployment-image $1 $2 $3
}

# ------------------------------------------------------------------------------
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
#-------------------------------------------------------------------------------

while getopts ":vu" opt; do
  case $opt in
    #h) usage; exit;;
    v) VERBOSE=1;;
    u) UPDATE=1;;
  esac
done

# "main"
case "$1" in
  --circleci-build-push-to-dockerhub)
		circleci-build-push-to-dockerhub
		;;
  --circleci-go-run-tests)
		circleci-go-run-tests
		;;
	--update-deps)
		update
		;;
  --install-deps)
  	install
  	;;
  --update-install-deps)
    update
  	install
  	;;
  --tail-log)
    update-tail-when-ready $2
  	;;
  --shell)
    shell $2
  	;;
  --shell-tele)
    shell-tele
  	;;
  --compile)
    compile
  	;;
  --hot-reload-deployment)
    hot-reload-deployment ping ping-deployment.yml ./server.go 50000
  	;;
  --swap-deployment-with-latest-release-image)
    swap-deployment-with-latest-release-image $2 $3
  	;;
  --swap-deployment-with-latest-image)
    swap-deployment-with-latest-image $2 $3
  	;;
  --swap-deployment-with-custom-image)
    swap-deployment-with-custom-image $2 $3 $4
  	;;
	help|*)
		usage
		;;
esac
