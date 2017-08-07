#!/bin/bash
#
# check-setup.sh
#
# Checks that your local development system is setup correctly
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
	echo "tunnel.sh (start|stop|help)"
}


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
		kubectl delete deployment --all
		kubectl delete daemonset --all
		kubectl delete replicationcontroller --all
		kubectl delete services --all
		kubectl delete pods --all
		kubectl delete configmap --all
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


#-------------------------------------------------------

# "main"
case "$1" in
	--create)
		create
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
