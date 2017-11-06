#!/bin/bash
#
# go-mongo.sh
#
# Tail a k8s pod from a specific namespace
#
# go-mongo.sh <namespace> <pod name>
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

if [ -z "$1" ]; then
    echo -e "$WARN You have not specified a namespace. Setting to 'default' ..."
    namespace=default
else
    namespace=$1
fi

if [ -z "$2" ]; then
    (>&2 echo "select option:")
    (>&2 echo "0. mongo-0")
    (>&2 echo "1. mongo-1")
    (>&2 echo "2. mongo-2")
    read -p "Enter number: " hostnum
else
    hostnum=$2
fi

echo -e "$INFO Connecting to $BLUE'mongo-$hostnum'$NO_COLOUR in namespace $BLUE'$namespace'$NO_COLOUR "
kubectl --namespace $namespace exec -it mongo-$hostnum -- /usr/bin/mongo 
