#!/bin/bash

# Description: This script is used to upload large files to worker nodes individually, in case CodeDeploy fails to upload them.
# Author:	   Malhar Chaudhari
# Version:	   2.0

: '
INFO: 
This Script is used to move data from local files to worker nodes. 
Usually Comes Handy when AWS CodeDeploy Failes to Upload Large Data Files to the Worker Nodes.
This script can be used to send different data files to different worker nodes (via numbering the data_files folder) and initiating the worker node application.

INPUTS:
Populate the Worker Array with the EC2 Worker Node DNS Values
Provide the AWS Key Location to the Files
Provide the Local Path where the data folders are present in the format /Worker_${worker_number}
'
declare -a workers=("" "")
declare -r awskey=""
declare -r local_path
count=0
for i in "${workers[@]}"
do
   ssh -o "StrictHostKeyChecking=no" -i $awskey ubuntu@$i 'sudo mkdir ~/worker_setup/data_files'
   ssh -o "StrictHostKeyChecking=no" -i $awskey ubuntu@$i 'sudo chmod -R 777 ~/worker_setup'
   scp -o "StrictHostKeyChecking=no" -r -i $awskey ~/$local_path/Worker_$count/ ubuntu@$i:/home/ubuntu/worker_setup/data_files
   curl http://$i/worker?startWorker=$count
   count=$((count+1))
   echo "setup completed on $i"
   sleep 5
done

echo "setup completed on all infrastructure"