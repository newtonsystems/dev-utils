#!/bin/bash
NO_COLOR="\033[0m"
GREEN="\033[0;32m"
RED="\033[31;01m"

ERROR="$RED====>>[ERROR] go-mattermost.sh:$NO_COLOR"

if [ -z "$AWS_CERT_FOLDER" ]; then
    echo -e "$ERROR You have not set the environment variable AWS_CERT_FOLDER - location of aws certs"
    echo -e "$GREEN Try the following: $NO_COLOR"
    echo -e "$GREEN \texport AWS_CERT_FOLDER=/Users/danvir/aws_certs/ $NO_COLOR"
    exit 1
fi

ssh -i "$AWS_CERT_FOLDER/rancher.pem" ubuntu@ec2-34-225-145-96.compute-1.amazonaws.com