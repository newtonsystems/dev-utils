#!/bin/bash
#
# glide-proj-setup.sh
#
# This is to setup glide project 
# ONLY RUN ONCE unless you know what you are doing!
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

prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac 
  done  
}

prompt_confirm "This should only be run ONCE. Are you sure?" || exit 0

echo -e "$INFO Removing & cleaning any old files ..."
rm -rf vendor/
rm featuretest.lock
rm featuretest.yaml
rm master.lock
rm master.yaml
rm main
rm glide.lock

echo -e "$INFO Creating glide files ..."
glide create
glide install

echo -e "$INFO Copying glide files for master and featuretest envs"
cp glide.lock featuretest.lock
cp glide.lock master.lock
cp glide.yaml featuretest.yaml
cp glide.yaml master.yaml




