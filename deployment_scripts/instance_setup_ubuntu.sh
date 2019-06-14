#!/bin/bash

# Description: This script is used to install CodeDeploy agent to EC2 Nodes.
# Author: 	   Malhar Chaudhari
# Version: 	   1.0

sudo apt-get -y update >/dev/null 2>&1
sudo apt-get -y install ruby >/dev/null 2>&1
sudo apt-get -y install wget >/dev/null 2>&1
cd /home/ubuntu
wget https://aws-codedeploy-us-east-2.s3.amazonaws.com/latest/install >/dev/null 2>&1
sudo chmod +x ./install >/dev/null 2>&1
./install auto >/dev/null 2>&1