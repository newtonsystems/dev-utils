#!/bin/bash
if [ "$#" -ne 2 ]
then
		(>&2 echo "call is:  $(basename "$0") <kube-namespace> <search-string>")
		exit 1
fi
box=$(find-box.sh $1 $2)
if [ "$?" -ne 0 ]
then
	(>&2 echo Error calling '"'findbox "'"$1"'" "'"$2"'"'"') 
	exit 1
fi
echo "ssh rancher@$box"
ipaddr=$(aws ec2 describe-instances --filters="Name=key-name, Values=$box" | grep PublicIp | grep -E -m 1 -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
echo "Public IP is $ipaddr"
echo "If you get a permission denied you need to add your pem to your ssh keychain: "
echo -e "\t ssh-add <PEM>"
ssh ubuntu@$ipaddr