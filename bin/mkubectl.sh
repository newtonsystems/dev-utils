#!/bin/bash
#
# mkubectl.sh
#
# A utility control script for deploying to minikube for development
#
# Make sure you have DEV_UTILS_PATH set
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

# Usage
usage ()
{
	echo "infra-minikube.sh (--create|--delete|--ui|--clean)"
}


# Build, push to docker hub (used for circleci)

# Deploy to kubernetes environment


# run shell (to debug and print some useful help)

# Run hot reloaded to minikube

# update / install repo



# ------------------------------------------------------------------------------
CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
TIMESTAMP=tmp-$(date +%s )

# -- Utils Functions ---

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
      echo -e "$ERROR Failed to set service/repo name"
      return
  fi
  while true; do
    sleep 30
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





# replace image with: latest-release, latest-branch, custom (e.g. master)
# $1 - REPO
# $2 - LOCAL_DEPLOYMENT_FILENAME
# $3 - watch dir/files
# EXPECT HEALTHZ PROBE ON DEPLOYMENT
reload-deployment()
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

  echo -e "$INFO Updating and installing dependencies in case anything has changed ..."
  update
  install

  eval `minikube docker-env`
  echo -e "$INFO Entering ${BLUE}$NEWTON_PATH/dev-utils/docker${NO_COLOUR} to build dev docker image ..."
  pushd $NEWTON_PATH/dev-utils/docker > /dev/null
  echo -e "Running command: ${BLUE}docker image build -t newtonsystems/$1:kube-dev${TIMESTAMP} --build-arg GO_MAIN=$3 --build-arg GO_PORT=$4 --build-arg REPO_DIR=/go/src/github.com/newtonsystems/ping -f Dockerfile.dev .${NO_COLOUR}"
  docker image build -t newtonsystems/$1:kube-dev${TIMESTAMP} --build-arg GO_MAIN=$3 --build-arg GO_PORT=$4 -f Dockerfile.dev .
  popd > /dev/null

  kubectl replace -f $NEWTON_PATH/devops/k8s/deploy/local/$2
	kubectl set image -f $NEWTON_PATH/devops/k8s/deploy/local/$2 $1=newtonsystems/$1:kube-dev${TIMESTAMP}
  #kubectl label pods `kubectl get pods -o wide | grep $REPO | awk '{ print $1 }'` mkube-dev=true
  echo -e "$INFO Waiting till service is ready, attaching logs and then will watch for changes to ${BLUE}$3${NO_COLOUR}"

  update-tail-when-ready $1 &

  READINESS_PORT=`kubectl get svc $1 -o jsonpath='{.spec.ports[?(@.name=="debug")].nodePort}'`
  for i in `seq 1 20`;
  do
    nc -z `minikube ip` $READINESS_PORT  > /dev/null && echo -e "$INFO Readiness PROBE: ${GREEN}Success${NO_COLOUR}" && break
    echo -e "$INFO Readiness probe: ${RED}Unsuccessful${NO_COLOUR} "
    sleep 30
  done

  echo -ne "$INFO checking health probe before connecting to logs"
  while [[ "$(curl -s $(minikube ip):$READINESS_PORT/healthz)" != "ok" ]]; do
    echo -n .
    sleep 5
  done
  started=$(curl -s $(minikube ip):$READINESS_PORT/started)
  echo -e ": ${GREEN}Success${NO_COLOUR}   started: $started"


  echo -e "$INFO Waiting on changes ... "
  fswatch ~/go/src/github.com/newtonsystems/ping | while read; do
     echo -e "$INFO Detected a change, killing app to restart $3"
     kubectl exec `kubectl get pods -o wide | grep $1` -- /usr/bin/run.sh --kill-go $3 $4
  done
}




# bUILD GO binary
# build-bin() {}
#
# build-command() {
#   CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./app/main.go
# }
#
# # build binary
# #
#
# compile (){
#   update
#   install
#   build-command
# }
















# Start all instances
create ()
{
	check-setup.sh
	if [ $? -ne 0 ]; then
		exit 1
	fi
	echo -e "$INFO Creating all services locally inside minikube ..."
	kubectl apply -f $NEWTON_PATH/devops/k8s/deploy/local/
}


clean ()
{
	check-setup.sh
	if [ $? -ne 0 ]; then
		exit 1
	fi

	echo -e -n "$RED Will clean up the entire Kubernetes environment "
	echo -e -n "$RED deleting ALL Kubernetes components (services, pods, config, deployments) ... Are you sure? (y to continue) $NO_COLOR"
	read -n 1 -r
	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]] ; then
		echo -e "$INFO Deleting all services locally inside minikube ..."
    for namespace in `kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name} {end}'`
    do
      if [[ "$namespace" == "kube-system" || "$namespace" == "kube-public" ]];  then
        echo -e "$INFO Skipping deletion of namespace: $BLUE $namespace $NO_COLOUR"
      fi
      echo -e "$INFO Deleting components for namespace: $BLUE $namespace $NO_COLOUR"
  		kubectl delete deployment --all --namespace=$namespace
  		kubectl delete daemonset --all --namespace=$namespace
  		kubectl delete replicationcontroller --all --namespace=$namespace
  		kubectl delete services --all --namespace=$namespace
  		kubectl delete pods --all --namespace=$namespace
  		kubectl delete configmap --all --namespace=$namespace
  		kubectl delete statefulset --all --namespace=$namespace
  		kubectl delete jobs --all --namespace=$namespace
    done
		eval $(minikube docker-env); docker-rm-unnamed-images;
	else
		echo -e "$YELLOW Aborting ... $NO_COLOR"
	fi
}


delete ()
{
	echo -e "$INFO Deleting all services locally inside minikube ..."
	kubectl delete -f $NEWTON_PATH/devops/k8s/deploy/local/
}


ui ()
{
	check-setup.sh
	if [ $? -ne 0 ]; then
		exit 1
	fi
	echo -e "$INFO Opening minikube dashboard (Kubernetes dashboard) ..."
	minikube dashboard
	echo -e "$INFO Opening linkerd 's admin page ..."
	minikube service linkerd --url | tail -n1 | xargs open
	echo -e "$INFO Opening namerd 's admin page ..."
	minikube service namerd --url | tail -n1 | xargs open
	echo -e "$INFO Opening linkerd viz ..."
	open http://`minikube ip`:`kubectl get svc linkerd-viz -o jsonpath='{.spec.ports[?(@.name=="grafana")].nodePort}'`
	echo -e "$INFO Opening zipkin (distributed tracing)"
	minikube service zipkin
	echo -e "$WARN Not going to open minikube addon heapster. Heapster not currently working with minikube 0.19 (works with 0.18) (21/5/17)"
}


# #
# # Infrastructure
# #
# .PHONY: infra-recreate infra-create infra-delete

# ADMIN_PORT=`kubectl get svc linkerd -o jsonpath='{.spec.ports[?(@.name=="admin")].nodePort}'`
# NAMERD_PORT=`kubectl get svc namerd -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}'`
# PING_ADMIN=http://`minikube ip`:$(ADMIN_PORT)/admin/ping
# LINKERVIZ_PORT=`kubectl get svc linkerd-viz -o jsonpath='{.spec.ports[?(@.name=="grafana")].nodePort}'`
# NAMERCTL_BASE_URL = http://`minikube ip`:$(NAMERD_PORT)


# infra-set-environment:
# 	@echo "Set up namerd env NAMERCTL_BASE_URL so you can use namerctl"
# 	set NAMERCTL_BASE_URL="FSS"
# 	@echo export NAMERCTL_BASE_URL=$(NAMERCTL_BASE_URL)


# infra-recreate:              ##@infrastructure Recreates all critical infrastructure components to run with your service (via minikube/k8s)
# 	@echo "$(INFO) Re-creating Infrastructure Components"
# 	make infra-delete
# 	make infra-create

# infra-create:                ##@infrastructure Creates all critical infrastructure components (via minikube/k8s)
# 	@echo "$(INFO) Creating Infrastructure Components"
# 	kubectl apply -f ../devops/k8s/deploy/local/

# infra-delete:                ##@infrastructure Deletes all critical instructure components (via minikube/k8s)
# 	@echo "$(INFO) Deleting Infrastructure Components"
# 	kubectl delete -f ../devops/k8s/deploy/local/

# #
# # Infrastructure helper commands
# #
# .PHONY: infra-ui infra-linkerd-ping infra-linkerd-logs

# infra-ui:                    ##@infrastructure-helper-commands Open all infrastructure's UIs. Perfect for monitoring, debugging and tracing microservices.
# 	@echo "$(INFO) Opening minikube dashboard (Kubernetes dashboard)"
# 	@minikube dashboard
# 	@echo "$(INFO) Opening linkerd 's admin page ..."
# 	@minikube service linkerd --url | tail -n1 | xargs open
# 	@echo "$(INFO) Opening linkerd viz ..."
# 	@open http://`minikube ip`:$(LINKERVIZ_PORT)
# 	@echo "$(INFO) Opening zipkin (distributed tracing)"
# 	@minikube service zipkin
# 	@echo "$(WARN) Not going to open minikube addon heapster. Heapster not currently working with minikube 0.19 (works with 0.18) (21/5/17)"
# # @echo "$(INFO) Opening Heapster - Resource Usage Analysis and Monitoring"
# # @open `minikube service monitoring-grafana --namespace=kube-system  --url`

# infra-linkerd-ping:          ##@infrastructure-helper-commands Pings linkerd's admin. A useful way to see if linkerd is up and running.
# 	@printf "$(GREEN) Pinging Linkerd Admin Interface ... $(RESET)"
# 	@if [ '$(shell curl $(PING_ADMIN))' != 'pong' ]; then \
# 		echo "$(RED)Failed to receive a "'pong'" response. It looks like linkerd is not running...$(RESET)"; \
# 		exit 1; \
# 	else \
# 		echo "$(GREEN)Successful ping.$(RESET)"; \
# 	fi

# infra-linkerd-logs:     ##@infra-linkerd-logs Tails linkerd logs
# 	@echo "$(INFO) Attaching to service $(BLUE)$(LINKERD_POD_NAME)$(RESET) logs"
# 	kubectl logs -f --tail=50 $(LINKERD_POD_NAME) linkerd

# infra-namerd-logs:     ##@infra-namerd-logs Tails namerd logs
# 	@echo "$(INFO) Attaching to service $(BLUE)$(NAMERD_POD_NAME)$(RESET) logs"
# 	kubectl logs -f --tail=50 $(NAMERD_POD_NAME) namerd


# .PHONY: kube-clean

# kube-clean:                       ##@cleanup Cleans Up Kubernetes Environment. Deletes all kubernetes components (services, pods, config, deployments ... etc)
# 	kubectl delete deployment --all
# 	kubectl delete daemonset --all
# 	kubectl delete replicationcontroller --all
# 	kubectl delete services --all
# 	kubectl delete pods --all
# 	kubectl delete configmap --all
# 	-@eval $$(minikube docker-env); docker-rm-unnamed-images;

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
#-------------------------------------------------------
while getopts ":hv" opt; do
  case $opt in
    #h) usage; exit;;
    v) VERBOSE=1;;
    #\?) usage; exit 1;;
  esac
done

# "main"
case "$1" in
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
  --update-tail-when-ready)
    update-tail-when-ready $2
  	;;
    --hot-reload-deployment)
      reload-deployment ping ping-deployment.yml server.go 50000
    	;;
  --swap-deployment)
    swap-deployment
  	;;
	--delete)
		delete
		;;
	--clean)
		clean
		;;
	--ui)
		ui
		;;
	help|*)
		usage
		;;
esac
