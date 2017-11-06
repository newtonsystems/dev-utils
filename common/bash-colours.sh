#!/bin/bash

NO_COLOUR="\033[0m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[31;01m"
YELLOW="\033[33;01m"
WHITE="\033[33;07m"

INFO="$GREEN[INFO]  `basename "$0"`:$NO_COLOUR"
ERROR="$RED[ERROR]  `basename "$0"`:$NO_COLOUR"
WARN="$YELLOW[WARN]  `basename "$0"`:$NO_COLOUR"
