#!/bin/bash
#
# glide-proj-setup.sh
#
# This is to setup glide project 
# ONLY RUN ONCE unless you know what you are doing!
#
# Make sure you have DEV_UTILS_PATH set 
#
CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`

if [ -z $DEV_UTILS_PATH ]; then
    echo "You have not set the environment variable DEV_UTILS_PATH. Please set."
    echo ""
    echo "For example:"
    echo "    export DEV_UTILS_PATH=/Users/danvir/Masterbox/sideprojects/github/newtonsystems/dev-utils/"
    echo ""
fi

. $DEV_UTILS_PATH/common/bash-colours.sh

function get-deps-featuretest() {
	echo -e "$INFO Adding package $1 to vendor/ + glide for featuretest environment"
	cp featuretest.lock glide.lock
	glide -y featuretest.yaml get $1
	cp glide.lock featuretest.lock
}

function get-deps-master() {
	echo -e "$INFO Adding package $1 to vendor/ + glide for master environment"
	cp master.lock glide.lock
	glide -y master.yaml get --force $1
	cp glide.lock master.lock
}

echo -e "$INFO Adding package $1 ... "
if [[ "$CURRENT_BRANCH" != "master" && "$CURRENT_BRANCH" != "featuretest" ]]; then
	echo -e "$INFO for branch master"
	get-deps-master $1
else
	echo -e "$INFO for $CURRENT_BRANCH"
	get-deps-$CURRENT_BRANCH $1
fi
