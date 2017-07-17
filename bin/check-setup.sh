#!/bin/bash
#
# check-setup.sh
#
# Checks that your local development system is setup correctly
#
# Make sure you have DEV_UTILS_PATH set 
#
if [ -z $DEV_UTILS_PATH ]; then
    echo "You have not set the environment variable DEV_UTILS_PATH. Please set."
    echo ""
    echo "For example:"
    echo "    export DEV_UTILS_PATH=/Users/danvir/Masterbox/sideprojects/github/newtonsystems/dev-utils/"
    echo ""
fi

. $DEV_UTILS_PATH/common/bash-colours.sh


# Basic Prerequisite test: Is docker installed?
if [ ! -x "$(which docker)" ]; then
    echo -e "$ERROR It appears that docker is not executable. Please make sure docker is installed."
    exit 1
fi

# Basic Prerequisite test: Is minikube installed?
if [ ! -x "$(which minikube)" ]; then
    echo -e "$ERROR It appears that minikube is not executable. Please make sure minikube is installed."
    exit 1
fi

# Basic Prerequisite test: Is kubectl installed?
if [ ! -x "$(which kubectl)" ]; then
    echo -e "$ERROR It appears that kubectl is not executable. Please make sure kubectl is installed."
    exit 1
fi

# Basic Prerequisite test: Is nghttpx installed?
if [ ! -x "$(which nghttpx)" ]; then
    echo -e "$ERROR It appears that nghttpx is not executable. Please make sure nghttpx is installed."
    exit 1
fi

# Basic Prerequisite test: Is docker running?
docker ps > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "$ERROR It appears that docker is not running. Unable to connect to docker daemon."
    exit 1
fi

# Basic Prerequisite test: Is minikube running?
if [[ "$(minikube status | grep minikube:)" != "minikube: Running" ]]; then
    echo -e "$ERROR It appears that minikube is not running. Please type 'minikube start'."
    exit 1
fi

