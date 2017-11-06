#!/bin/bash
#
# go-tail.sh
#
# Tail a k8s pod from a specific namespace
#
# go-tail.sh <namespace> <pod name>
#

if [ -z $DEV_UTILS_PATH ]; then
    echo "You have not set the environment variable DEV_UTILS_PATH. Please set."
    echo ""
    echo "For example:"
    echo "    export DEV_UTILS_PATH=/Users/danvir/Masterpod/sideprojects/github/newtonsystems/dev-utils/"
    echo ""
    exit
fi

. $DEV_UTILS_PATH/common/bash-colours.sh

if [ "$#" -ne 2 ]
then
		(>&2 echo "call is:  $(basename "$0") <kube-namespace> <search-string>")
		exit 1
fi
pods=$(kubectl get pods -o wide --namespace=$1 | grep -e "$2" | awk '{ print $1 }' | sort -u)
pod_count=$(echo $pods | wc -w)

if [ "$pod_count" -eq 1 ]
then
		pod=$pods
else
		if [ "$pod_count" -eq 0 ]
		then
				(>&2 echo "No pods found")
				exit 1
		else
				(>&2 echo "Multiple pods found; choose one:")
				n=1
				for pod in $pods
				do
						podarray[$n]=$pod
						apps=$(kubectl get pods -o wide --namespace=$1 | grep $2 | grep "$pod" | awk '{ print $1 }' | xargs)
            status=$(kubectl get pods -o wide --namespace=$1 | grep $2 | grep "$pod" | awk '{ print $3 }' | xargs)
						(>&2 echo "$n. $pod: $apps ($status)")
						((n++))
				done
				read -p "Enter number: " podnum
				pod=${podarray[$podnum]}
				if [ -z "$pod" ]
				then
						(>&2 echo "bad input number '$podnum'")
						exit 1
				fi
		fi
fi

echo -e "$INFO Connecting to $BLUE'$pod'$NO_COLOUR in namespace $BLUE'$1'$NO_COLOUR "
kubectl logs -f $pod --namespace=$1
