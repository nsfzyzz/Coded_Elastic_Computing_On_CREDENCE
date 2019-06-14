#!/bin/bash

# Description: This script is used specifically in the case if the instance_setup_ubuntu.sh script fails to install codedeploy-agent
# Author: 	   Malhar Chaudhari
# Version: 	   1.0

until service codedeploy-agent status >/dev/null 2>&1; do
	sleep 10
	rm -f install
    wget https://aws-codedeploy-us-west-2.s3.amazonaws.com/latest/install >/dev/null 2>&1
    chmod +x ./install >/dev/null 2>&1
    sudo ./install auto >/dev/null 2>&1
    sudo service codedeploy-agent restart >/dev/null 2>&1
done