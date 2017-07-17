#!/bin/bash
if [ "$#" -ne 2 ]
then
		(>&2 echo "call is:  $(basename "$0") <kube-namespace> <search-string>")
		exit 1
fi
boxes=$(kubectl get pods -o wide --namespace=$1 | grep -e "$2" | awk '{ print $7 }' | sort -u)
box_count=$(echo $boxes | wc -w)
if [ "$box_count" -eq 1 ]
then
		box=$boxes
else
		if [ "$box_count" -eq 0 ]
		then
				(>&2 echo "No boxes found")
				exit 1
		else
				(>&2 echo "Multiple boxes found; choose one:")
				n=1
				for box in $boxes
				do
						boxarray[$n]=$box
						apps=$(kubectl get pods -o wide --namespace=$1 | grep $2 | grep "$box" | awk '{ print $1 }' | xargs)
						(>&2 echo "$n. $box: $apps")
						((n++))
				done
				read -p "Enter number: " boxnum
				box=${boxarray[$boxnum]}
				if [ -z "$box" ]
				then
						(>&2 echo "bad input number '$boxnum'")
						exit 1
				fi
		fi
fi
echo $box