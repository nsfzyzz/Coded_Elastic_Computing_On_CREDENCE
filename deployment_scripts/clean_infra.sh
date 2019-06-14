#!/usr/bin/env bash

# Description: Deletes all the Infrastructure (worker and master nodes) launched by the deployment script.
# Author: 	   Malhar Chaudhari
# Version: 	   2.0

# Define Infrastructure Clean functions
# Terminate Master Node
function remove_master_node {
	printf "INFO: FUNC: Terminate Master Node.\\n"
	# Remove: Terminate Master Node	
	master_instance_id="$(aws ec2 describe-instances --filters "Name=tag-value,Values=aws_mwf_ec2_master" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output=text)"
	aws ec2 terminate-instances --instance-ids "$master_instance_id" 1>/dev/null 2>&1
	printf "INFO: EC2 Master Node: Submitted Termination Request for Master Node. Waiting for Termination of Master Node.\\n"
	# Verify: Master Node is terminated
	aws ec2 wait instance-terminated --filter "Name=tag:Type,Values=aws_mwf_ec2_master"
	if [ "$?" -eq "255" ]; then
	printf "ERROR: EC2 Master Node: Terminating Master Instance failed. Terminate Instances from AWS Console. Exiting Clean Infrastructure Setup.\\n"
	exit
	fi

	printf "SUCCESS: EC2 Master Node: Successfully Terminated Master Node.\\n\\n"
}

# Terminate Worker Nodes
function remove_worker_node {
	printf "INFO: FUNC: Terminate Worker Nodes.\\n"
	# Remove: Terminate Worker Node	
	worker_instance_id="$(aws ec2 describe-instances --filters "Name=tag-value,Values=aws_mwf_ec2_worker" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output=text)"
	worker_instance_id_list=(${worker_instance_id// /,})
	for i in "${worker_instance_id_list[@]}"
	do
		aws ec2 terminate-instances --instance-ids "$i" 1>/dev/null 2>&1
		printf "INFO: EC2 Worker Node: Submitted Termination Request for Worker Node with Instance ID: %s.\\n" "$i"
	done
	# Verify: Worker Node is terminated
	printf "INFO: EC2 Worker Node: Waiting for Termination of All Worker Nodes.\\n"
	aws ec2 wait instance-terminated --filter "Name=tag:Type,Values=aws_mwf_ec2_worker"
	if [ "$?" -eq "255" ]; then
	printf "ERROR: EC2 Worker Nodes: Terminating Worker Instances failed. Terminate Instances from AWS Console. Exiting Clean Infrastructure Setup.\\n"
	exit
	fi

	printf "SUCCESS: EC2 Worker Nodes: Successfully Terminated Worker Nodes.\\n\\n"
}

	
# Delete KeyPair and Local Pem File
function delete_keypair_pem_file {
	printf "INFO: FUNC: Delete KeyPair Files.\\n"
	# Verify: Permission to delete Public KeyPair
	comm_resp="$(aws ec2 delete-key-pair --dry-run --key-name aws_mwf_ec2_keypair 1>/dev/null 2>&1)"
	if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
		printf "ERROR: EC2 KeyPair: Dry Run Operation to delete KeyPair failed. Check Permission and KeyPair Usage. Exiting Clean Infrastructure Setup.\\n Dry Run Operation Command: aws ec2 delete-key-pair --dry-run --key-name aws_mwf_ec2_keypair\\n"
		exit
	fi
	# Delete: Public KeyPair
	aws ec2 delete-key-pair --key-name aws_mwf_ec2_keypair 1>/dev/null 2>&1
	# Verify: Public KeyPair Delete Request Successful
	if aws ec2 describe-key-pairs --key-name aws_mwf_ec2_keypair 2>/dev/null; then
		printf "ERROR: EC2 KeyPair: KeyPair aws_mwf_ec2_keypair could not be successfully deleted. Delete KeyPair from Console and Local Key File. Exiting Clean Infrastructure Setup.\\n"
		exit
	fi
	# Delete: Local Pem File (Private Key)
	rm -f aws_mwf_ec2_keypair.pem

	printf "SUCCESS: KeyPair: Successfully Deleted KeyPair.\\n\\n"
}


# Delete Security Group
function delete_security_group {
	printf "INFO: FUNC: Delete Security Group.\\n"
	# Verify: Permission to delete security group
	comm_resp="$(aws ec2 delete-security-group --dry-run --group-name aws_mwf_sg_allow_all 1>/dev/null 2>&1)"
	if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
		printf "ERROR: Security Group: Dry Run Operation to delete security group aws_mwf_sg_allow_all failed.\\n Dry Run Operation Command: aws ec2 delete-security-group --dry-run --group-name aws_mwf_sg_allow_all\\n"
		exit
	fi
	# Delete: Security Group
	aws ec2 delete-security-group --group-name aws_mwf_sg_allow_all 1>/dev/null 2>&1
	# Verify: Securtiy Group was successfully deleted
	if aws ec2 describe-security-groups --group-names aws_mwf_sg_allow_all 2>/dev/null; then
		printf "ERROR: EC2 Security Group: Security Group aws_mwf_sg_allow_all could not be deleted. Delete Security Group from Console. Exiting Clean Infrastructure Setup.\\n"
		exit
	fi

	printf "SUCCESS: Security Group: Successfully Deleted Security Group.\\n\\n"
}


# Delete IAM Role
function delete_iam_role {
	printf "INFO: FUNC: Delete IAM Roles and Instance Profiles.\\n"
	# Delete: Remove Role, Policy and Instance Profile
	aws iam remove-role-from-instance-profile --instance-profile-name aws_mwf_iam_instance_profile --role-name aws_mwf_iam_role 1>/dev/null 2>&1
	aws iam delete-role-policy --role-name aws_mwf_iam_role --policy-name aws_mwf_iam_policy 1>/dev/null 2>&1
	aws iam delete-role --role-name aws_mwf_iam_role 1>/dev/null 2>&1
	aws iam delete-instance-profile --instance-profile-name aws_mwf_iam_instance_profile 1>/dev/null 2>&1
	# Verify: IAM Role Removed
	if aws iam get-role --role-name aws_mwf_iam_role 2>/dev/null; then
		printf "ERROR: IAM: IAM Role aws_mwf_iam_role could not be removed. Delete IAM Role from Console. Exiting Clean Infrastructure Setup.\\n"
		exit
	fi
	# Verify: IAM Instance Profile Removed
	if aws iam get-instance-profile --instance-profile-name aws_mwf_iam_instance_profile 2>/dev/null; then
		printf "ERROR: IAM: IAM Instance Profile aws_mwf_iam_instance_profile could not be removed. Delete IAM Profile from Console. Exiting Clean Infrastructure Setup.\\n"
		exit
	fi

	printf "SUCCESS: IAM Role: Successfully Deleted IAM Role.\\n\\n"
}


# Delete S3 Buckets
function delete_s3_buckets {
	printf "INFO: FUNC: Delete S3 Buckets.\\n"
	# Input: Get Account ID for the IAM User
	aws_account_id="$(aws sts get-caller-identity | jq '.Account' | sed -e 's/^"//' -e 's/"$//')"
	aws_mwf_s3_master="awsmwfs3master"
	aws_mwf_s3_master="$aws_mwf_s3_master$aws_account_id"
	aws_mwf_s3_worker="awsmwfs3worker"
	aws_mwf_s3_worker="$aws_mwf_s3_worker$aws_account_id"
	# Delete: S3 Master and Worker Bucket and all the objects
	aws s3 rm s3://"$aws_mwf_s3_master" --recursive 1>/dev/null 2>&1
	aws s3 rb s3://"$aws_mwf_s3_master" --force 1>/dev/null 2>&1
	aws s3 rm s3://"$aws_mwf_s3_worker" --recursive 1>/dev/null 2>&1
	aws s3 rb s3://"$aws_mwf_s3_worker" --force	1>/dev/null 2>&1
	# Verify: S3 Master Bucket Removed
	aws s3api wait bucket-not-exists --bucket "$aws_mwf_s3_master"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Bucket: Bucket aws_mwf_s3_master_acct_id could not be removed. Delete S3 Bucket From S3 Console. Exiting Clean Infrastructure Setup.\\n"
	fi
	# Verify: S3 Worker Bucket Removed
	aws s3api wait bucket-not-exists --bucket "$aws_mwf_s3_worker"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Bucket: Bucket aws_mwf_s3_worker_acct_id could not be removed. Delete S3 Bucket From S3 Console. Exiting Clean Infrastructure Setup.\\n"
	fi

	printf "SUCCESS: S3: Successfully Deleted Buckets.\\n\\n"
}


# Delete Application
function delete_application {
	printf "INFO: FUNC: Delete Application.\\n"
	# Delete: Delete Master and Worker
	aws deploy delete-application --application-name master_setup_app 1>/dev/null 2>&1
	aws deploy delete-application --application-name worker_setup_app 1>/dev/null 2>&1
	# Verify: Master Application is deleted
	comm_resp="$(aws deploy get-application --application-name master_setup_app 2>/dev/null)"
	if [ -n "$comm_resp" ]; then
		printf "ERROR: Deploy Application: Master Application could not be deleted. Delete Application From CodeDeploy Console. Exiting Clean Infrastructure Setup.\\n"
		exit
	fi
	# Verify: Worker Application is deleted
	comm_resp="$(aws deploy get-application --application-name worker_setup_app 2>/dev/null)"
	if [ -n "$comm_resp" ]; then
		printf "ERROR: Deploy Application: Worker Application could not be deleted. Delete Application From CodeDeploy Console. Exiting Clean Infrastructure Setup.\\n"
		exit
	fi

	printf "SUCCESS: CodeDeploy: Successfully Deleted CodeDeploy Applications.\\n\\n"
}


# Introduction to AWS EC2 Infrastructure Clean Setup script
printf "Welcome to AWS Master Worker Framework Infrastructure Clean and Termination Setup.\\n"
printf "To use this tool, specify the setup actions you want to perform as a command line argument.\\n"
printf "For Eg. './clean_infra.sh all' will run all the setup steps.\\n"
printf "Possible Options are: \\n 1. all \\n 2. remove_master_node \\n 3. remove_worker_node \\n 4. delete_keypair_pem_file \\n 5. delete_security_group \\n 6. delete_iam_role \\n 7. delete_s3_buckets \\n 8. delete_application\\n\\n"

# Choose a subset of functions to run
case "$1" in
	"all" )
		remove_master_node
		remove_worker_node
		delete_keypair_pem_file
		delete_security_group
		delete_iam_role
		delete_s3_buckets
		delete_application
		;;
	"remove_master_node" )
		remove_master_node
		;;
	"remove_worker_node" )
		remove_worker_node
		;;
	"delete_keypair_pem_file" )
		delete_keypair_pem_file
		;;
	"delete_security_group" )
		delete_security_group
		;;
	"delete_iam_role" )
		delete_iam_role
		;;
	"delete_s3_buckets" )
		delete_s3_buckets
		;;
	"delete_application" )
		delete_application
		;;
	"help" )
		echo "Choose one of the above actions."
		;;
	* )
		printf "ERROR: Command Line Argument not a valid input. Try Running the script again.\\n"
		;;
esac