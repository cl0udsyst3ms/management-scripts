#!/bin/bash

HOST_USER_ID=$(id -u)
: ${USER_NAME:="developer"}
if [ -n "$1" ]; then
  USER_NAME=$1
fi
echo $USER_NAME
docker run -v /home/$USER_NAME:/home/developer --name cloudsys -it terraform-managment 
# Clean 
docker ps -a | grep -e Exit -e cloudsys | cut -d ' ' -f 1 | xargs sudo docker rm
