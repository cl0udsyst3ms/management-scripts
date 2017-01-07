#!/bin/bash

docker run -v /home/miszcz:/home/developer --name cloudsys -it terraform-managment 
# Clean 
docker ps -a | grep -e Exit -e cloudsys| cut -d ' ' -f 1 | xargs sudo docker rm
