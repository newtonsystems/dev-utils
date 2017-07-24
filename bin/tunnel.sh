#!/bin/bash
#
# Start/stop an EC2 instances
#
# Very simple! - will update for more complex scenarios in the future
#
# requires the aws package to be installed and configured locally -- sudo apt-get install awscli
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
# aws configure --profile ubuntu
#     AWS Access Key ID [****************JVVQ]: 
#     AWS Secret Access Key [****************aLGE]: 
#     Default region name [us-east-1b]: us-east-1
#     Default output format [None]: 
#
# set AWS_DEFAULT_PROFILE   (or you have to add --profile ubuntu to all commands in this script)
#     export AWS_DEFAULT_PROFILE=ubuntu
#
# I think environment variables override profile - be careful 
#
# usage: ./tunnel.sh start (spin up EC2 instances)
#        ./tunnel.sh stop (stops EC2 instances)
RANCHER_INSTANCE_ID="0054cbb4c8b251bd8"

# Start all instances
start ()
{
	echo "Starting instances for us-east-1 ..."
	instances=$(aws ec2 describe-instances --filters "Name=instance-state-name, Values=shutting-down, stopped, stopping" | grep InstanceId | grep -E -o "i\-[0-9A-Za-z]+")

	aws ec2 start-instances --instance-ids $instances --region us-east-1
}

# Stop all instances
stop ()
{
	echo "Stopping instances for us-east-1 ..."
	instance=$(aws ec2 describe-instances --filters "Name=instance-state-name, Values=running, pending" | grep InstanceId | grep -E -o "i\-[0-9A-Za-z]+" | grep -v $RANCHER_INSTANCE_ID)

	aws ec2 stop-instances --instance-ids $instance
}


# Usage
usage ()
{
	echo "tunnel.sh (start|stop|help)"
}


#-------------------------------------------------------

# "main"
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	help|*)
		usage
		;;
esac
