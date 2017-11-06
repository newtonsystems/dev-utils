#!/bin/bash

NO_COLOUR="\033[0m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[31;01m"
YELLOW="\033[33;01m"

INFO="$GREEN[INFO]  `basename "$0"`:$NO_COLOUR"
ERROR="$RED[ERROR]  `basename "$0"`:$NO_COLOUR"
WARN="$YELLOW[WARN]  `basename "$0"`:$NO_COLOUR"

# Kill go
# $1 main go
# $2 port
kill-bin ()
{
  process=$(ps aux |grep "./$1" | grep -v grep)
  pid_app=$(echo $process | awk '{print $1}')
  pid_port=$(echo $2 | awk '{print $1}')

  echo -e "$INFO Process found: $process  "
  echo -e "$INFO pid: $pid_app  port: $pid_port"
  kill $pid_app || true
  lsof -ti:$pid_port || xargs kill
}

# $1 - binary
# Run a go file forever
looper ()
{
  # if [[ ! -f $1 ]]; then
  #     echo -e "$ERROR File '$1' not found in current working directory!"
  #     exit 1
  # fi

  while true; do
    echo -e "$INFO Running executable: ./$1"
    ./$1
    echo -e "$INFO Waiting 5 seconds before restarting $1"
    for i in `seq 1 5`; do
      echo -n "."
      sleep 1
    done
    echo ""
  done
}



# "main"
case "$1" in
	--hot-reload-bin)
		looper $2
		;;
  --kill-bin)
  	kill-bin $2 $3
  	;;
esac
