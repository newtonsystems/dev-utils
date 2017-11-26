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

echo -e "$INFO Connecting to $BLUE'mongo-$hostnum'$NO_COLOUR in namespace $BLUE'$namespace'$NO_COLOUR "
echo "Checking the status of the replica set"
kubectl run mongoshell0 --image=marcob/mongo-watch -i -t --rm --restart=OnFailure -- mongo --host mongo-0.mongo --quiet workload --eval "rs.status()"
