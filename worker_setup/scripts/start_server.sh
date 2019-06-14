#!/bin/bash
cd /home/ubuntu/worker_setup
mvn clean package
sudo mvn exec:java > /dev/null 2>&1 &