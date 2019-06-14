#!/usr/bin/env bash

# Description: Once experiments are completed on the deployed infrastructure, this script downloads the result logs from the worker and master nodes to the project root directory.
# Author:	   Malhar Chaudhari
# Version: 	   1.0

# Download Results from Master and Worker Nodes
master_dns="$(aws ec2 describe-instances --filters "Name=tag-value,Values=aws_mwf_ec2_master" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicDnsName" --output=text)"
worker_dns="$(aws ec2 describe-instances --filters "Name=tag-value,Values=aws_mwf_ec2_worker" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicDnsName" --output=text)"
IFS=$'\t'
worker_dns_arr=($worker_dns)

datetime="$(date +%Y%m%d%H%M%S)"
mkdir ../results_"$datetime"

dns="$(cut -d'.' -f1 <<<"$master_dns")"
mkdir ../results_"$datetime"/"$dns"
scp -o "StrictHostKeyChecking=no" -r -i aws_mwf_ec2_keypair.pem ubuntu@"$master_dns":/home/ubuntu/master_setup/results/* ../results_"$datetime"/"$dns"

for i in "${worker_dns_arr[@]}"
do
	dns="$(cut -d'.' -f1 <<<"$i")"
	mkdir ../results_"$datetime"/"$dns"
	scp -o "StrictHostKeyChecking=no" -r -i aws_mwf_ec2_keypair.pem ubuntu@"$i":/home/ubuntu/worker_setup/results/* ../results_"$datetime"/"$dns"
done

printf "SUCCESS: Downloaded All Results to results_%s directory.\\n" "$datetime"