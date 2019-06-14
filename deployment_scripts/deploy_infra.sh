#!/bin/bash

# Description: This script is used for launching a cluster of EC2 nodes, on which the master and worker application are setup.
# 			   It can support SPOT and ONDEMAND instances, All At Once Deployment using CodeDeploy and Pushing only updated changes to nodes without the need to relaunch nodes.
# Author:      Malhar Chaudhari
# Version:     2.0

# Define setup functions

# Configure AWS CLI
function aws_cli_configure {
	printf "INFO: FUNC: Configure AWS CLI.\\n"
	printf "\\nINPUT: AWS CLI: Is AWS CLI configured (Y/N): "
	read -r ifin

	if [ "$ifin" == "Y" ]; then
		return
	else
		printf "\\nINPUT: CLI: Provide values: 'AWS Access Key ID' 'AWS Secret Access Key' 'Deault Region' :"
		read -r -a config
		aws configure set aws_access_key_id "${config[0]}"
		aws configure set aws_secret_access_key "${config[1]}"
		aws configure set default.region "${config[2]}"
	fi

	printf "SUCCESS: CLI: Configured AWS CLI.\\n\\n"
}


# Create IAM Role and IAM Instance Profile
function create_iam_role_profile {
	printf "INFO: FUNC: Create IAM Role and Instance Profile.\\n"
	# AWS IAM create role
	# Verify: IAM role already exists
	if aws iam get-role --role-name aws_mwf_iam_role 2>/dev/null; then
		printf "ERROR: IAM: IAM Role aws_mwf_iam_role exists. Run \"./clean_infra.sh delete_iam_role\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Create: IAM role
	aws iam create-role --role-name aws_mwf_iam_role --assume-role-policy-document file://aws_iam_role_trust.json 1>/dev/null 2>&1
	# Verify: IAM role was created
	comm_resp="$(aws iam get-role --role-name aws_mwf_iam_role)"
	iam_role_name="$(echo "$comm_resp" | jq '.Role.RoleName' | sed -e 's/^"//' -e 's/"$//')"
	if [ "$iam_role_name" != "aws_mwf_iam_role" ]; then
		printf "ERROR: IAM: IAM Role aws_mwf_iam_role could not be created. Try running \"./clean_infra.sh delete_iam_role\" and \"./deploy_infra.sh create_iam_role_profile\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	printf "INFO: IAM: Created IAM Role.\\n"
	# AWS IAM put role policy
	# Verify: IAM role policy already exists
	if aws iam get-role-policy --role-name aws_mwf_iam_role --policy-name aws_mwf_iam_policy 2>/dev/null; then
		printf "ERROR: IAM: IAM Role Policy aws_mwf_iam_policy exists. Run \"./clean_infra.sh delete_iam_role\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Create: IAM role policy
	aws iam put-role-policy --role-name aws_mwf_iam_role --policy-name aws_mwf_iam_policy --policy-document file://aws_iam_role_perm.json 1>/dev/null 2>&1
	# Verify: IAM role policy was created
	comm_resp="$(aws iam get-role-policy --role-name aws_mwf_iam_role --policy-name aws_mwf_iam_policy)"
	iam_role_policy_name="$(echo "$comm_resp" | jq '.PolicyName' | sed -e 's/^"//' -e 's/"$//')"
	if [ "$iam_role_policy_name" != "aws_mwf_iam_policy" ]; then
		printf "ERROR: IAM: IAM Role Policy aws_mwf_iam_policy could not be created. Try running script \"./clean_infra.sh delete_iam_role\" and \"./deploy_infra.sh create_iam_role_profile\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	printf "INFO: IAM: Created IAM Role Policy.\\n"
	# AWS IAM Create Instance Profile
	# Verify: IAM Instance Profile already exists
	if aws iam get-instance-profile --instance-profile-name aws_mwf_iam_instance_profile 2>/dev/null; then
		printf "ERROR: IAM: IAM Instance Profile aws_mwf_iam_instance_profile exists. Run \"./clean_infra.sh delete_iam_role\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Create: IAM Instance Profile and Add Role to Profile
	aws iam create-instance-profile --instance-profile-name aws_mwf_iam_instance_profile 1>/dev/null 2>&1
	aws iam add-role-to-instance-profile --instance-profile-name aws_mwf_iam_instance_profile --role-name aws_mwf_iam_role 1>/dev/null 2>&1
	# Verify: IAM role was created
	comm_resp="$(aws iam get-instance-profile --instance-profile-name aws_mwf_iam_instance_profile)"
	iam_role_name="$(echo "$comm_resp" | jq '.InstanceProfile.Roles[0].RoleName' | sed -e 's/^"//' -e 's/"$//')"
	iam_instance_profile_name="$(echo "$comm_resp" | jq '.InstanceProfile.InstanceProfileName' | sed -e 's/^"//' -e 's/"$//')"
	if [ "$iam_role_name" != "aws_mwf_iam_role" ] || [ "$iam_instance_profile_name" != "aws_mwf_iam_instance_profile" ]; then
		printf "ERROR: IAM: IAM Instance Profile aws_mwf_iam_instance_profile could not be created. Try running script \"./clean_infra.sh delete_iam_role\" and \"./deploy_infra.sh create_iam_role_profile\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	printf "INFO: IAM: Created Instance Profile and Added IAM Role to the Profile.\\n"

	printf "SUCCESS: IAM: Created IAM Role and IAM Instance Profile.\\n\\n"
}


# Create Security Group
function create_sec_group {
	printf "INFO: FUNC: Create Security Group.\\n"
	# AWS EC2 Create Security Group
	# Verify: EC2 Security Group already exists
	if aws ec2 describe-security-groups --group-names aws_mwf_sg_allow_all 2>/dev/null; then
		printf "ERROR: EC2 Security Group: Security Group aws_mwf_sg_allow_all exists. Run \"./clean_infra.sh delete_security_group\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Verify: Account has permission to create EC2 Security Group
	comm_resp="$(aws ec2 create-security-group --dry-run --group-name aws_mwf_sg_allow_all --description "AWS EC2 MWF Framework Security Group" 1>/dev/null 2>&1)"
	if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
		printf "ERROR: EC2 Security Group: Dry Run Operation to create Security Group aws_mwf_sg_allow_all failed. Try running script \"./clean_infra.sh delete_security_group\" and \"./deploy_infra.sh create_sec_group\". Exiting Infrastructure Setup.\\n Dry Run Operation Command: aws ec2 create-security-group --dry-run --group-name aws_mwf_sg_allow_all --description \"AWS EC2 MWF Framework Security Group\"\\n"
		exit
	fi
	# Create: EC2 Security Group
	aws ec2 create-security-group --group-name aws_mwf_sg_allow_all --description "AWS EC2 MWF Framework Security Group" 1>/dev/null 2>&1
	aws ec2 authorize-security-group-ingress --group-name aws_mwf_sg_allow_all --protocol tcp --port 0-65535 --cidr "0.0.0.0/0" 1>/dev/null 2>&1
	# Verify: EC2 Security Group was created
	comm_resp="$(aws ec2 describe-security-groups --group-names aws_mwf_sg_allow_all)"
	sec_group_name="$(echo "$comm_resp" | jq '.SecurityGroups[0].GroupName' | sed -e 's/^"//' -e 's/"$//')"
	sec_group_cidr="$(echo "$comm_resp" | jq '.SecurityGroups[0].IpPermissions[0].IpRanges[0].CidrIp' | sed -e 's/^"//' -e 's/"$//')"
	if [ "$sec_group_name" != "aws_mwf_sg_allow_all" ] || [ "$sec_group_cidr" != "0.0.0.0/0" ]; then
		printf "ERROR: EC2 Security Group: Security Group aws_mwf_sg_allow_all could not be created. Try running script \"./clean_infra.sh delete_security_group\" and \"./deploy_infra.sh create_sec_group\". Exiting Infrastructure Setup.\\n"
		exit
	fi

	printf "SUCCESS: EC2 Security Group: Created Security Group with access to All Ports and IPs.\\n\\n"
}


# Create a Key Pair
function create_keypair {
	printf "INFO: FUNC: Create KeyPair.\\n"
	# AWS EC2 Create KeyPair for instances
	# Verify: EC2 KeyPair already exists
	if aws ec2 describe-key-pairs --key-name aws_mwf_ec2_keypair 2>/dev/null; then
		printf "ERROR: EC2 KeyPair: KeyPair aws_mwf_ec2_keypair exists. Run \"./clean_infra.sh delete_keypair_pem_file\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Verify: Account has permission to create EC2 KeyPair
	comm_resp="$(aws ec2 create-key-pair --dry-run --key-name aws_mwf_ec2_keypair 1>/dev/null 2>&1)"
	if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
		printf "ERROR: EC2 KeyPair: Dry Run Operation to create KeyPair aws_mwf_ec2_keypair failed. Try running script \"./clean_infra.sh delete_keypair_pem_file\" and \"./deploy_infra.sh create_keypair\". Exiting Infrastructure Setup.\\n Dry Run Operation Command: aws ec2 create-key-pair --dry-run --key-name aws_mwf_ec2_keypair"
		exit
	fi
	# Create: EC2 KeyPair
	rm -f aws_mwf_ec2_keypair.pem
	aws ec2 create-key-pair --key-name aws_mwf_ec2_keypair --query 'KeyMaterial' --output text > aws_mwf_ec2_keypair.pem
	chmod 400 aws_mwf_ec2_keypair.pem
	# Verify: EC2 KeyPair was created
	comm_resp="$(aws ec2 describe-key-pairs --key-name aws_mwf_ec2_keypair)"
	key_name="$(echo "$comm_resp" | jq '.KeyPairs[0].KeyName' | sed -e 's/^"//' -e 's/"$//')"
	if [ "$key_name" != "aws_mwf_ec2_keypair" ]; then
		printf "ERROR: EC2 KeyPair: KeyPair aws_mwf_ec2_keypair could not be created. Try running script \"./clean_infra.sh delete_keypair_pem_file\" and \"./deploy_infra.sh create_keypair\". Exiting Infrastructure Setup.\\n"
		exit
	fi

	printf "SUCCESS: EC2 KeyPair: Created KeyPair and saved Private Key to local directory.\\n\\n"
}


# Create AWS Master Node
function create_master_node {
	printf "INFO: FUNC: Create Master Node.\\n"
	# AWS EC2 Create Master Node
	# Verify: Any instance with tag Type:aws_mwf_ec2_master exists
	comm_resp="$(aws ec2 describe-instances --filter "Name=tag:Type,Values=aws_mwf_ec2_master" "Name=instance-state-name,Values=running")"
	if [[ "$comm_resp" == *aws_mwf_ec2_master* ]]; then
		printf "ERROR: EC2 Master Node: Node with Tag Type=aws_mwf_ec2_master exists. Run \"./clean_infra.sh remove_master_node\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Input: Get Master Node Instance Type
	printf "\\nINPUT: EC2 Master Node: Enter the Master Node Instance Type (eg. \"t2.small\"). Press Enter for Default: "
	read -r master_type
	if [ -z "$master_type" ]; then
		master_type="t2.small"
		printf "WARN: EC2 Master Node: Default Instance Type 't2.small' selected."
	fi
	# Input: Get Master Node Custom Tags
	printf "\\nINPUT: EC2 Master Node: Enter the Master Project Tag Name. No Default Available. Enter Tag \"Key Value\" Pair (eg. \"Project TestDeploy\"): "
	read -r -a master_tag
	if [ -z "${master_tag[0]}" ]; then
		master_tag="Project aws_mwf_ec2_expt"
		printf "WARN: EC2 Master Node: No EC2 Tags detected. Instances may not be categorized effectively for cost center analysis.\\n"
	fi
	# Input: Get Master Node Size
	printf "\\nINPUT: EC2 Master Node: Enter the Master Node Volume Size (in GB). Press Enter for Default: "
	read -r master_volume_size
	if [ -z "$master_volume_size" ]; then
		master_volume_size="8"
		printf "WARN: EC2 Master Node: No Volume Size Detected. Creating Master with Volume Size of 8GB.\\n"
	fi
	# Input: Get Master Node Placement
	printf "\\nINPUT: EC2 Master Node: Enter the Master Node Placement Availability Zone (eg. \"us-east-1b\"). Press Enter for Default: "
	read -r master_placement
	if [ -z "${master_placement}" ]; then
		master_placement="us-east-1b"
		printf "WARN: EC2 Master Node: No Placement Availability Zone detected. 'us-east-1b' selected as default Availability Zone.\\n"
	fi
	# Input: Get Master Node On-Demand or Spot Request Launch
	printf "\\nINPUT: EC2 Master Node: Enter \"SPOT\" or \"ONDEMAND\" for launching Master Node as a spot or an on-demand instance respectively. Press Enter for Default: "
	read -r master_launch_type
	if [ -z "${master_launch_type}" ]; then
		master_launch_type="SPOT"
		printf "WARN: EC2 Master Node: No Launch Type Specified. Starting SPOT Instance."
	fi
	# Branch to Spot or On-Demand Instance
	comm_resp="$(aws ec2 describe-security-groups --group-names aws_mwf_sg_allow_all)"
	sec_group_id="$(echo "$comm_resp" | jq '.SecurityGroups[0].GroupId' | sed -e 's/^"//' -e 's/"$//')"
	instance_id_master=""
	if [[ "$master_launch_type" == "SPOT" ]]; then
		# Verify: Account has permission to launch spot instance request
		launch_spec='{"ImageId": "ami-66506c1c", "KeyName": "aws_mwf_ec2_keypair", "SecurityGroupIds": [ '\"$sec_group_id\"' ], "BlockDeviceMappings": [ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$master_volume_size'}} ], "InstanceType": '\"$master_type\"', "Placement": {"AvailabilityZone": '\"$master_placement\"'}, "IamInstanceProfile": {"Name": "aws_mwf_iam_instance_profile"}}'
		comm_resp="$(aws ec2 request-spot-instances --dry-run --instance-count 1 --launch-specification "$launch_spec" 1>/dev/null 2>&1)"
		if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
			printf "ERROR: EC2 Master Node: Dry Run Operation to create Master Node failed. Try Launching Spot Instance with same parameters from Console. If Sucessful, Try running script \"./clean_infra.sh remove_master_node\" and \"./deploy_infra.sh create_master_node\". Exiting Infrastructure Setup.\\n Dry Run Operation Command: aws ec2 request-spot-instances --dry-run --instance-count 1 --launch-specification $launch_spec\\n"
			exit
		fi
		# Create: Spot Instance Request and Export Master Spot Request ID and Instance ID
		comm_resp="$(aws ec2 request-spot-instances --instance-count 1 --launch-specification "$launch_spec")"
		spot_req_id_master="$(echo "$comm_resp" | jq '.SpotInstanceRequests[0].SpotInstanceRequestId' | sed -e 's/^"//' -e 's/"$//')"
		# Verify: Spot Instance Request Fulfilled
		printf "INFO: EC2 Master Node: Submitted Spot Request. Waiting for Spot Request Fulfilment.\\n"
		aws ec2 wait spot-instance-request-fulfilled --spot-instance-request-id "$spot_req_id_master"
		if [ "$?" -eq "255" ]; then
			printf "ERROR: EC2 Master Node: Creating Instance from Spot Request failed. Try Launching Spot Instance with same parameters from Console. If Sucessful, Try running script \"./clean_infra.sh remove_master_node\" and \"./deploy_infra.sh create_master_node\". Exiting Infrastructure Setup.\\n"
			exit
		fi
		printf "INFO: EC2 Master Node: Completed Spot Request.\\n"
		instance_id_master="$(aws ec2 describe-spot-instance-requests --filters "Name=spot-instance-request-id,Values=$spot_req_id_master" | jq '.SpotInstanceRequests[0].InstanceId' | sed -e 's/^"//' -e 's/"$//')"
	else
		# Verify: Account has permission to launch On-Demand instance requests
		comm_resp="$(aws ec2 run-instances --dry-run --count 1 --image-id ami-66506c1c --key-name aws_mwf_ec2_keypair --security-group-ids $sec_group_id --block-device-mappings '[ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$master_volume_size'}} ]' --instance-type $master_type --placement AvailabilityZone=$master_placement --iam-instance-profile Name=aws_mwf_iam_instance_profile 1>/dev/null 2>&1)"
		if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
			printf "ERROR: EC2 Master Node: Dry Run Operation to create Master Node failed. Try Launching On-Demand Instance with same parameters from Console. If Sucessful, Try running script \"./clean_infra.sh remove_master_node\" and \"./deploy_infra.sh create_master_node\". Exiting Infrastructure Setup.\\n Dry Run Operation Command: aws ec2 run-instances --dry-run --count 1 --image-id ami-66506c1c --key-name aws_mwf_ec2_keypair --security-group-ids $sec_group_id --block-device-mappings '[ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$master_volume_size'}} ]' --instance-type $master_type --placement AvailabilityZone=$master_placement --iam-instance-profile Name=aws_mwf_iam_instance_profile\\n"
			exit
		fi
		# Create: On-Demand Instance Request and Export Instance ID
		comm_resp="$(aws ec2 run-instances --count 1 --image-id ami-66506c1c --key-name aws_mwf_ec2_keypair --security-group-ids $sec_group_id --block-device-mappings '[ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$master_volume_size'}} ]' --instance-type $master_type --placement AvailabilityZone=$master_placement --iam-instance-profile Name=aws_mwf_iam_instance_profile)"
		printf "INFO: EC2 Master Node: Launched On-Demand Instance.\\n"
		instance_id_master="$(echo "$comm_resp" | jq '.Instances[0].InstanceId' | sed -e 's/^"//' -e 's/"$//')"
	fi
	# Create: Tags for Instances created as a part of the spot request
	printf "INFO: EC2 Master Node: Creating Tags for Master Node.\\n"
	aws ec2 create-tags --resources "$instance_id_master" --tags Key=Type,Value=aws_mwf_ec2_master 1>/dev/null 2>&1
	aws ec2 create-tags --resources "$instance_id_master" --tags Key="${master_tag[0]}",Value="${master_tag[1]}" 1>/dev/null 2>&1
	printf "INFO: EC2 Master Node: Created Tags for Master Node. Waiting for Master to reach Running State.\\n"
	# Verify: Master Instance Running
	aws ec2 wait instance-running --filters "Name=instance-id,Values=$instance_id_master"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: EC2 Master Node: Spot Request fulfilled and Instance Created, but Master Instance Not Running (Check Console If Master Running). Run \"./clean_infra.sh remove_master_node\" and Try Running \"./deploy_infra.sh create_master_node\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Verify: Master Instance Status Check OK
	printf "INFO: EC2 Master Node: Master Node is Running. Waiting for Master Instance to Pass All Status Checks.\\n"
	aws ec2 wait instance-status-ok --instance-ids "$instance_id_master"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: EC2 Master Node: Master Instance Running, but not passed all status checks (Check Console If Master Passed All Status Checks). Wait for Master to Pass All Status Checks before resuming to next step in deployment (create_worker_nodes). Exiting Infrastructure Setup.\\n"
		exit
	fi

	printf "SUCCESS: EC2 Master Node: Master Node Running Successfully.\\n\\n"
}

# Create AWS Worker Nodes
function create_worker_nodes {
	printf "INFO: FUNC: Create Worker Nodes.\\n"
	# AWS EC2 Create Worker Nodes
	# Verify: Any instance with tag Type:aws_mwf_ec2_worker exists
	comm_resp="$(aws ec2 describe-instances --filter "Name=tag:Type,Values=aws_mwf_ec2_worker" "Name=instance-state-name,Values=running")"
	if [[ "$comm_resp" == *aws_mwf_ec2_worker* ]]; then
		printf "ERROR: EC2 Worker Nodes: Nodes with Tag Type=aws_mwf_ec2_worker exists. Run \"./clean_infra.sh remove_worker_node\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Input: Get Number of Worker Nodes
	printf "\\nINPUT: EC2 Worker Nodes: Enter the Number of Worker Nodes to be Started: "
	read -r num_worker
	if [ -z "$num_worker" ] || [ "$num_worker" -lt "1" ]; then
		num_worker=1
		printf "WARN: EC2 Worker Nodes: Invalid Input provided. Selecting default 1 worker node.\\n"
	fi
	# Input: Get Worker Nodes Instance Type
	printf "\\nINPUT: EC2 Worker Nodes: Enter the Worker Node Instance Type (eg. \"t2.small\"). Press Enter for Default: "
	read -r worker_type
	if [ -z "$worker_type" ]; then
		worker_type="t2.small"
		printf "WARN: EC2 Worker Node: Default Instance Type 't2.small' selected.\\n"
	fi
	# Input: Get Worker Nodes Custom Tags
	printf "\\nINPUT: EC2 Worker Nodes: Enter the Worker Project Tag Name. No Default Available. Enter Tag \"Key Value\" Pair (eg. \"Project TestDeploy\"): "
	read -r -a worker_tag
	if [ -z "${worker_tag[0]}" ]; then
		worker_tag="Project aws_mwf_ec2_expt"
		printf "WARN: EC2 Worker Nodes: No EC2 Tags detected. Instances may not be categorized effectively for cost center analysis.\\n"
	fi
	# Input: Get Master Node Size
	printf "\\nINPUT: EC2 Woker Nodes: Enter the Worker Nodes Volume Size (in GB). Press Enter for Default: "
	read -r worker_volume_size
	if [ -z "$worker_volume_size" ]; then
		worker_volume_size="8"
		printf "WARN: EC2 Worker Node: No Volume Size Detected. Creating Worker with Volume Size of 8GB.\\n"
	fi
	# Input: Get Worker Nodes Placement
	printf "\\nINPUT: EC2 Worker Nodes: Enter the Worker Node Placement Availability Zone (eg. \"us-east-1b\"). Press Enter for Default: "
	read -r worker_placement
	if [ -z "${worker_placement}" ]; then
		worker_placement="us-east-1b"
		printf "WARN: EC2 Worker Nodes: No Placement Availability Zone detected. 'us-east-1b' selected as default Availability Zone.\\n"
	fi
	# Input: Get Worker Node On-Demand or Spot Request Launch
	printf "\\nINPUT: EC2 Worker Node: Enter \"SPOT\" or \"ONDEMAND\" for launching Worker Nodes as spot or on-demand instances respectively. Press Enter for Default: "
	read -r worker_launch_type
	if [ -z "${worker_launch_type}" ]; then
		worker_launch_type="SPOT"
		printf "WARN: EC2 Worker Node: No Launch Type Specified. Starting SPOT Instance."
	fi
	# Branch to Spot or On-Demand Instance
	sec_group_id="$(aws ec2 describe-security-groups --group-names aws_mwf_sg_allow_all | jq '.SecurityGroups[0].GroupId' | sed -e 's/^"//' -e 's/"$//')"
	worker_instance_ids=""
	if [[ "$worker_launch_type" == "SPOT" ]]; then
		# Verify: Account has permission to launch spot instance request
		launch_spec='{"ImageId": "ami-66506c1c", "KeyName": "aws_mwf_ec2_keypair", "SecurityGroupIds": [ '\"$sec_group_id\"' ], "BlockDeviceMappings": [ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$worker_volume_size'}} ], "InstanceType": '\"$worker_type\"', "Placement": {"AvailabilityZone": '\"$worker_placement\"'}, "IamInstanceProfile": {"Name": "aws_mwf_iam_instance_profile"}}'
		comm_resp="$(aws ec2 request-spot-instances --instance-count $num_worker --dry-run --launch-specification "$launch_spec" 1>/dev/null 2>&1)"
		if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
			printf "ERROR: EC2 Worker Nodes: Dry Run Operation to create Worker Node failed.  Try Launching Spot Instance with same parameters from Console. If Sucessful, Try running script \"./clean_infra.sh remove_worker_node\" and \"./deploy_infra.sh create_worker_nodes\". Exiting Infrastructure Setup.\\n Dry Run Operation Command: aws ec2 request-spot-instances --instance-count $num_worker --dry-run --launch-specification $launch_spec\\n"
			exit
		fi
		# Create: Create Spot Instance Request and Export Worker Spot Request ID
		printf "INFO: EC2 Worker Nodes: Submitted Spot Request. Waiting for Spot Request Fulfilment.\\n"
		comm_resp="$(aws ec2 request-spot-instances --instance-count $num_worker --launch-specification "$launch_spec")"
		spot_reqs="$(echo "$comm_resp" | jq '.SpotInstanceRequests[].SpotInstanceRequestId')"
		# Loop over all spot requests
		IFS=$'\n'
		while read -r row; do
			temp_spot_id="$(echo "$row" | sed -e 's/^"//' -e 's/"$//')"
			aws ec2 create-tags --resources "$temp_spot_id" --tags Key=Type,Value=aws_mwf_ec2_worker_spot
			# Verify: Spot Instance Request Fulfilled
			aws ec2 wait spot-instance-request-fulfilled --spot-instance-request-id "$temp_spot_id"
			if [ "$?" -eq "255" ]; then
				printf "ERROR: EC2 Worker Nodes: Creating Instance from Spot Request failed. Try Launching Spot Instance with same parameters from Console. If Sucessful, Try running script \"./clean_infra.sh remove_worker_node\" and \"./deploy_infra.sh create_worker_nodes\". Exiting Infrastructure Setup.\\n"
				exit
			fi
			temp_instance_id="$(aws ec2 describe-spot-instance-requests --filters "Name=spot-instance-request-id,Values=$temp_spot_id" | jq '.SpotInstanceRequests[0].InstanceId' | sed -e 's/^"//' -e 's/"$//')"
			printf "INFO: EC2 Worker Nodes: Completed Spot Request for Instance with ID %s.\\n" "$temp_instance_id"
		done <<< "$spot_reqs"
		worker_instance_ids="$(aws ec2 describe-spot-instance-requests --filters "Name=tag-value,Values=aws_mwf_ec2_worker_spot" | jq '.SpotInstanceRequests[].InstanceId' | sed -e 's/^"//' -e 's/"$//')"
	else
		# Verify: Account has permission to launch On-Demand instance request
		comm_resp="$(aws ec2 run-instances --dry-run --count $num_worker --image-id ami-66506c1c --key-name aws_mwf_ec2_keypair --security-group-ids $sec_group_id --block-device-mappings '[ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$worker_volume_size'}} ]' --instance-type $worker_type --placement AvailabilityZone=$worker_placement --iam-instance-profile Name=aws_mwf_iam_instance_profile 1>/dev/null 2>&1)"
		if ! [ -z "${comm_resp##*DryRunOperation*}" ]; then
			printf "ERROR: EC2 Worker Nodes: Dry Run Operation to create Worker Node failed. Try Launching On-Demand Instance with same parameters from Console. If Sucessful, Try running script \"./clean_infra.sh remove_worker_node\" and \"./deploy_infra.sh create_worker_nodes\". Exiting Infrastructure Setup.\\n Dry Run Operation Command: aws ec2 run-instances --dry-run --count $num_worker --image-id ami-66506c1c --key-name aws_mwf_ec2_keypair --security-group-ids $sec_group_id --block-device-mappings '[ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$worker_volume_size'}} ]' --instance-type $worker_type --placement AvailabilityZone=$worker_placement --iam-instance-profile Name=aws_mwf_iam_instance_profile\\n"
			exit
		fi
		# Create: Create Worker On-Demand Instance Request and Export Worker Instance ID
		comm_resp="$(aws ec2 run-instances --count $num_worker --image-id ami-66506c1c --key-name aws_mwf_ec2_keypair --security-group-ids $sec_group_id --block-device-mappings '[ {"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$worker_volume_size'}} ]' --instance-type $worker_type --placement AvailabilityZone=$worker_placement --iam-instance-profile Name=aws_mwf_iam_instance_profile)"
		worker_instance_ids="$(echo "$comm_resp" | jq '.Instances[].InstanceId')"
		printf "INFO: EC2 Worker Node: Launched Worker On-Demand Instances.\\n"
	fi
	# Loop over all on-demand instance requests
	IFS=$'\n'
	while read -r row; do
		temp_instance_id="$(echo "$row" | sed -e 's/^"//' -e 's/"$//')"
		printf "INFO: EC2 Worker Nodes: Creating Tags for Instance with ID %s.\\n" "$temp_instance_id"
		aws ec2 create-tags --resources "$temp_instance_id" --tags Key=Type,Value=aws_mwf_ec2_worker 1>/dev/null 2>&1
		aws ec2 create-tags --resources "$temp_instance_id" --tags Key="${worker_tag[0]}",Value="${worker_tag[1]}" 1>/dev/null 2>&1
		printf "INFO: EC2 Worker Nodes: Created Tags for Instance with ID %s. Waiting for Instance to reach Running State.\\n" "$temp_instance_id"
		aws ec2 wait instance-running --filters "Name=instance-id,Values=$temp_instance_id"
		if [ "$?" -eq "255" ]; then
			printf "ERROR: EC2 Worker Nodes: Spot Request fulfilled and Instance Created, but Worker Instance Not Running (Check Console If Worker Nodes are Running). Run \"./clean_infra.sh remove_worker_node\" and Try Running Script Again. Exiting Infrastructure Setup.\\n"
			exit
		fi
		printf "INFO: EC2 Worker Node: Worker %s reached Running state.\\n" $temp_instance_id
		printf "INFO: EC2 Worker Nodes: Waiting for Instance %s to pass all Status Checks.\\n" "$temp_instance_id"
		aws ec2 wait instance-status-ok --instance-ids "$temp_instance_id"
		if [ "$?" -eq "255" ]; then
			printf "ERROR: EC2 Worker Node: Worker Instance Running, but not passed all status checks. (Check Console If All Worker Nodes Passed All Status Checks). Wait for Worker Nodes to Pass All Status Checks before resuming to next step in deployment (update_dns_verify_codedeploy). Exiting Infrastructure Setup.\\n"
			exit
		fi
	done <<< "$worker_instance_ids"
	
	printf "SUCCESS: EC2 Worker Nodes: Worker Nodes Running Successfully.\\n\\n"
}


# Update Application Instances List Master and Worker Public DNS values
# Verify Codedeploy Running on Master and Worker Instances
function update_dns_verify_codedeploy {
	# Wait for all the machines to reach stable state and release lock of ubuntu package manager
	printf "INFO: Waiting for all Machines to be Ready and Releasing Lock from Ubuntu Package Manager.\\n"
	sleep 30
	# Update Application Instances List Master and Worker Public DNS values
	# Verify: If There are Instances with Master and Worker Tags
	master_dns="$(aws ec2 describe-instances --filters "Name=tag-value,Values=aws_mwf_ec2_master" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicDnsName" --output=text)"
	worker_dns="$(aws ec2 describe-instances --filters "Name=tag-value,Values=aws_mwf_ec2_worker" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicDnsName" --output=text)"
	
	# Create Worker and Master Instance Public DNS Lists and Update Application Lists 
	IFS=$'\t'
	worker_dns_arr=($worker_dns)
	worker_dns_arr_print=$(IFS=,; echo "${worker_dns_arr[*]}")
	echo "$worker_dns_arr_print" > ../master_setup/src/main/resources/ec2_worker_dns_list
	echo "$worker_dns_arr_print" > ../worker_setup/src/main/resources/ec2_worker_dns_list
	echo "$master_dns" > ../worker_setup/src/main/resources/ec2_master_dns_list
	echo "$master_dns" > ../master_setup/src/main/resources/ec2_master_dns_list
	printf "Master Public DNS: %s\\n" "$master_dns"
	IFS=$','
	# Install Codedeploy on Worker Instances
	for i in "${worker_dns_arr[@]}"
	do
		scp -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem instance_setup_ubuntu.sh ubuntu@"$i:/home/ubuntu" 1>/dev/null 2>&1
		ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$i" 'cd /home/ubuntu/; chmod +x instance_setup_ubuntu.sh; ./instance_setup_ubuntu.sh' 1>/dev/null 2>&1 &
		printf "INFO: EC2 Worker Codedeploy: CodeDeploy Agent Installed on Worker Node: %s. Verifying if agent is active.\\n" "$i"
	done
	sleep 90
	# Verify Codedeploy Running on Worker Instances
	for i in "${worker_dns_arr[@]}"
	do
		if ! ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$i" 'sudo service codedeploy-agent status' 1>/dev/null 2>&1; then
			scp -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem instance_setup_ubuntu_repair.sh ubuntu@"$i:/home/ubuntu" 1>/dev/null 2>&1
			ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$i" 'cd /home/ubuntu/; chmod +x instance_setup_ubuntu_repair.sh; ./instance_setup_ubuntu_repair.sh' 1>/dev/null 2>&1
			printf "INFO: EC2 Worker Codedeploy: Copied CodeDeploy Agent Setup Repair Script to Worker: %s\\n" "$i"
			if ! ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$i" 'sudo service codedeploy-agent status' 1>/dev/null 2>&1; then
				printf "ERROR: EC2 Worker Codedeploy: Code Deploy Agent Installation Failed on Worker Node %s. SSH into a Worker Node and try to manually install and verify CodeDeploy Agent status. If Successful in agent installation, try runnning ./deploy_infra.sh update_dns_verify_codedeploy.\\n" "$i"
				exit
			fi
		fi
		printf "INFO: EC2 Worker Codedeploy: CodeDeploy Agent Running on Worker Node: %s\\n" "$i"
	done
	# Install Codedeploy on Master Instances
	scp -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem instance_setup_ubuntu.sh ubuntu@"$master_dns:/home/ubuntu" 1>/dev/null 2>&1
	ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$master_dns" 'cd /home/ubuntu/; chmod +x instance_setup_ubuntu.sh; ./instance_setup_ubuntu.sh' 1>/dev/null 2>&1
	printf "INFO: EC2 Master Codedeploy: Installed CodeDeploy Agent Setup Script to Master Node. Verifying if agent is active.\\n"
	# Verify Codedeploy Running on Master Instances
	if ! ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$master_dns" 'sudo service codedeploy-agent status' 1>/dev/null 2>&1; then
		scp -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem instance_setup_ubuntu_repair.sh ubuntu@"$master_dns:/home/ubuntu" 1>/dev/null 2>&1
		ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$master_dns" 'cd /home/ubuntu/; chmod +x instance_setup_ubuntu_repair.sh; ./instance_setup_ubuntu_repair.sh' 1>/dev/null 2>&1
		printf "INFO: EC2 Master Codedeploy: Copied CodeDeploy Agent Setup Repair Script to Master Node.\\n"
		if ! ssh -o "StrictHostKeyChecking=no" -i aws_mwf_ec2_keypair.pem ubuntu@"$master_dns" 'sudo service codedeploy-agent status' 1>/dev/null 2>&1; then
			printf "ERROR: EC2 Master Codedeploy: Code Deploy Agent Installation Failed on Master Node. SSH into Master Node and try to manually install and verify CodeDeploy Agent status. If Successful in agent installation, try runnning ./deploy_infra.sh update_dns_verify_codedeploy.\\n"
			exit
		fi
	fi
	printf "INFO: EC2 Master Codedeploy: CodeDeploy Agent Running on Master Node.\\n"
	
	printf "SUCCESS: Codedeploy Verify: Codedeploy agent was verified to be running and dns lists have been udpated in application.\\n\\n"	
}


# Create S3 Bucket and Update Policy
function create_s3_bucket_update_policy {
	printf "INFO: FUNC: Create S3 Buckets.\\n"
	# Create: Get Account ID for the IAM User and Create Bucket Names
	aws_account_id="$(aws sts get-caller-identity | jq '.Account' | sed -e 's/^"//' -e 's/"$//')"
	aws_mwf_s3_master="awsmwfs3master"
	aws_mwf_s3_master="$aws_mwf_s3_master$aws_account_id"
	aws_mwf_s3_worker="awsmwfs3worker"
	aws_mwf_s3_worker="$aws_mwf_s3_worker$aws_account_id"
	# Verify: S3 Bucket aws_mwf_s3_master_acct_id and aws_mwf_s3_worker_acct_id does not exist
	aws s3api wait bucket-not-exists --bucket "$aws_mwf_s3_master"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Master Bucket: S3 Bucket aws_mwf_s3_master_acct_id exists. Run \"./clean_infra.sh delete_s3_buckets\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	aws s3api wait bucket-not-exists --bucket "$aws_mwf_s3_worker"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Worker Bucket: S3 Bucket aws_mwf_s3_worker_acct_id exists. Run \"./clean_infra.sh delete_s3_buckets\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Create: S3 Bucket aws_mwf_s3_master and aws_mwf_s3_worker
	aws s3 mb s3://"$aws_mwf_s3_master" 1>/dev/null 2>&1
	printf "INFO: S3 Master Bucket: Created Master Bucket.\\n"
	aws s3 mb s3://"$aws_mwf_s3_worker" 1>/dev/null 2>&1
	printf "INFO: S3 Worker Bucket: Created Worker Bucket.\\n"
	# Verify: S3 Buckets aws_mwf_s3_master and aws_mwf_s3_worker were created
	aws s3api wait bucket-exists --bucket "$aws_mwf_s3_master"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Master Bucket: S3 Bucket aws_mwf_s3_master_acct_id could not be created. Run \"./clean_infra.sh delete_s3_buckets\" and \"./deploy_infra.sh create_s3_bucket_update_policy\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	aws s3api wait bucket-exists --bucket "$aws_mwf_s3_worker"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Worker Bucket: S3 Bucket aws_mwf_s3_worker_acct_id could not be created. Run \"./clean_infra.sh delete_s3_buckets\" and \"./deploy_infra.sh create_s3_bucket_update_policy\". Exiting Infrastructure Setup.\\n"
		exit
	fi

	# Create: S3 Bucket Policy for buckets aws_mwf_s3_master and aws_mwf_s3_worker
	aws s3api put-bucket-policy --bucket "$aws_mwf_s3_master" --policy '{"Statement": [{"Action": ["s3:*"], "Effect": "Allow", "Resource": "arn:aws:s3:::'$aws_mwf_s3_master'/*", "Principal": {"AWS": ["'$aws_account_id'", "arn:aws:iam::'$aws_account_id':role/aws_mwf_iam_role"]}}]}' 1>/dev/null 2>&1
	printf "INFO: S3 Master Bucket: Created Master Bucket Policy.\\n"
	aws s3api put-bucket-policy --bucket "$aws_mwf_s3_worker" --policy '{"Statement": [{"Action": ["s3:*"], "Effect": "Allow", "Resource": "arn:aws:s3:::'$aws_mwf_s3_worker'/*", "Principal": {"AWS": ["'$aws_account_id'", "arn:aws:iam::'$aws_account_id':role/aws_mwf_iam_role"]}}]}' 1>/dev/null 2>&1
	printf "INFO: S3 Worker Bucket: Created Worker Bucket Policy.\\n"
	# Verify: S3 Bucket Policy were applied to buckets aws_mwf_s3_master and aws_mwf_s3_worker
	comm_resp="$(aws s3api get-bucket-policy --bucket "$aws_mwf_s3_master")"
	if [ -z "$comm_resp" ]; then
		printf "ERROR: S3 Master Bucket Policy: Policy for S3 Bucket aws_mwf_s3_master_acct_id could not be created. Run \"./clean_infra.sh delete_s3_buckets\" and \"./deploy_infra.sh create_s3_bucket_update_policy\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	comm_resp="$(aws s3api get-bucket-policy --bucket "$aws_mwf_s3_worker")"
	if [ -z "$comm_resp" ]; then
		printf "ERROR: S3 Worker Bucket Policy: Policy for S3 Bucket aws_mwf_s3_worker_acct_id could not be created. Run \"./clean_infra.sh delete_s3_buckets\" and \"./deploy_infra.sh create_s3_bucket_update_policy\". Exiting Infrastructure Setup.\\n"
		exit
	fi

	printf "SUCCESS: S3 Bucket: S3 Buckets aws_mwf_s3_master_acct_id and aws_mwf_s3_worker_acct_id created with appropriate policies.\\n\\n"
}


# Create And Deploy Application
function create_deploy_application {
	printf "INFO: FUNC: Create and Deploy Application.\\n"
	# Get Account ID for the IAM User
	aws_account_id="$(aws sts get-caller-identity | jq '.Account' | sed -e 's/^"//' -e 's/"$//')"
	aws_mwf_s3_master="awsmwfs3master"
	aws_mwf_s3_master="$aws_mwf_s3_master$aws_account_id"
	aws_mwf_s3_worker="awsmwfs3worker"
	aws_mwf_s3_worker="$aws_mwf_s3_worker$aws_account_id"
	# Verify: Master Application zip does not exist in S3 Bucket
	aws s3api wait object-not-exists --bucket "$aws_mwf_s3_master" --key master_setup_app.zip 2>/dev/null
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Object Master App: Object master_setup_app.zip exists in S3 Bucket aws_mwf_s3_master_acct_id. Run \"./clean_infra.sh delete_s3_buckets\", \"./deploy_infra.sh create_s3_bucket_update_policy\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Verify: Master Application does not exist in Codedeploy
	comm_resp="$(aws deploy get-application --application-name master_setup_app 2>/dev/null)"
	if [ -n "$comm_resp" ]; then
		printf "ERROR: Deploy Master Application: Master Application master_setup_app already exists. Run \"./clean_infra.sh delete_application\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Verify: Worker Application zip does not exist in S3 Bucket
	aws s3api wait object-not-exists --bucket "$aws_mwf_s3_worker" --key worker_setup_app.zip 2>/dev/null
	if [ "$?" -eq "255" ]; then
		printf "ERROR: S3 Object Worker App: Object worker_setup_app.zip exists in S3 Bucket aws_mwf_s3_worker_acct_id. Run \"./clean_infra.sh delete_s3_buckets\", \"./deploy_infra.sh create_s3_bucket_update_policy\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Verify: Worker Application does not exist in Codedeploy
	comm_resp="$(aws deploy get-application --application-name worker_setup_app 2>/dev/null)"
	if [ -n "$comm_resp" ]; then
		printf "ERROR: Deploy Worker Application: Worker Application worker_setup_app already exists. Run \"./clean_infra.sh delete_application\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	# Create: Create Master Application, Push Master Application, Create Master Deployment Group
	iam_role_arn="$(aws iam get-role --role-name aws_mwf_iam_role | jq '.Role.Arn' | sed -e 's/^"//' -e 's/"$//')"
	chmod +x ../master_setup/scripts/*
	cd ../master_setup || return
	aws deploy create-application --application-name master_setup_app 1>/dev/null 2>&1
	printf "INFO: Deploy Master Application: Created Master Application.\\n"
	aws deploy push --application-name master_setup_app --s3-location s3://"$aws_mwf_s3_master"/master_setup_app.zip --ignore-hidden-files 1>/dev/null 2>&1
	printf "INFO: Deploy Master Application: Deployed Master Application to S3.\\n"
	aws deploy create-deployment-group --application-name master_setup_app --deployment-group-name master_setup_dep_group --deployment-config-name CodeDeployDefault.AllAtOnce --ec2-tag-filters Key=Type,Value=aws_mwf_ec2_master,Type=KEY_AND_VALUE --service-role-arn "$iam_role_arn" 1>/dev/null 2>&1
	comm_resp="$(aws deploy create-deployment --application-name master_setup_app --deployment-config-name CodeDeployDefault.AllAtOnce --deployment-group-name master_setup_dep_group --s3-location bucket="$aws_mwf_s3_master",bundleType=zip,key=master_setup_app.zip)"
	deployment_id="$(echo "$comm_resp" | jq '.deploymentId' | sed -e 's/^"//' -e 's/"$//')"
	printf "INFO: Deploy Master Application: Waiting for Deployment Application to Master Node.\\n"
	# Verify: Deployment Success on Master Node
	aws deploy wait deployment-successful --deployment-id "$deployment_id"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: Deploy Master Application: Master Application master_setup_app could not be deployed. (Check AWS CodeDeploy Console to See Logs for Failure Conditions). Run \"./clean_infra.sh delete_application\", \"./clean_infra.sh delete_s3_buckets\", \"./deploy_infra.sh create_s3_bucket_update_policy\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	printf "INFO: Deploy Master Application: Completed Application Deployment to Master Node.\\n"
	# Create: Create Worker Application, Push Worker Application, Create Worker Deployment Group
	chmod +x ../worker_setup/scripts/*
	cd ../worker_setup || return
	aws deploy create-application --application-name worker_setup_app 1>/dev/null 2>&1
	printf "INFO: Deploy Worker Application: Created Worker Application.\\n"
	aws deploy push --application-name worker_setup_app --s3-location s3://"$aws_mwf_s3_worker"/worker_setup_app.zip --ignore-hidden-files 1>/dev/null 2>&1
	printf "INFO: Deploy Worker Application: Deployed Worker Application to S3.\\n"
	aws deploy create-deployment-group --application-name worker_setup_app --deployment-group-name worker_setup_dep_group --deployment-config-name CodeDeployDefault.AllAtOnce --ec2-tag-filters Key=Type,Value=aws_mwf_ec2_worker,Type=KEY_AND_VALUE --service-role-arn "$iam_role_arn" 1>/dev/null 2>&1
	comm_resp="$(aws deploy create-deployment --application-name worker_setup_app --deployment-config-name CodeDeployDefault.AllAtOnce --deployment-group-name worker_setup_dep_group --s3-location bucket="$aws_mwf_s3_worker",bundleType=zip,key=worker_setup_app.zip)"
	deployment_id="$(echo "$comm_resp" | jq '.deploymentId' | sed -e 's/^"//' -e 's/"$//')"
	printf "INFO: Deploy Worker Application: Waiting for Deployment Application to Worker Nodes.\\n"
	# Verify: Deployment Success on Worker Node
	aws deploy wait deployment-successful --deployment-id "$deployment_id"
	if [ "$?" -eq "255" ]; then
		printf "ERROR: Deploy Worker Application: Worker Application worker_setup_app could not be deployed. (Check AWS CodeDeploy Console to See Logs for Failure Conditions). Run \"./clean_infra.sh delete_application\", \"./clean_infra.sh delete_s3_buckets\", \"./deploy_infra.sh create_s3_bucket_update_policy\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
		exit
	fi
	printf "INFO: Deploy Worker Application: Completed Application Deployment to Worker Nodes.\\n"
	printf "SUCCESS: Deploy Application: Master and Worker Application Successfully Deployed.\\n\\n"
}

# Push Application Updates to AWS Instances
function push_updated_application {
	printf "INFO: FUNC: Push Updated Application to Cloud.\\n"
	# Get Account ID for the IAM User
	aws_account_id="$(aws sts get-caller-identity | jq '.Account' | sed -e 's/^"//' -e 's/"$//')"
	aws_mwf_s3_master="awsmwfs3master"
	aws_mwf_s3_master="$aws_mwf_s3_master$aws_account_id"
	aws_mwf_s3_worker="awsmwfs3worker"
	aws_mwf_s3_worker="$aws_mwf_s3_worker$aws_account_id"
	# Input: Find out if Master or Worker or Both Applications Have to be Updated
	printf "\\nINPUT: Push Updated Application: Enter \"MASTER\" or \"WORKER\" or \"BOTH\" for updating Master or Worker or Both Nodes respectively. No Default Available: "
	read -r update_app_type
	if [ -z "${update_app_type}" ]; then
		printf "ERROR: Push Updated Application: No Input Provided. Exiting Setup."
		exit
	fi
	if [[ "$update_app_type" == "MASTER" ]] || [[ "$update_app_type" == "BOTH" ]]; then
		chmod +x ../master_setup/scripts/*
		cd ../master_setup || return
		# Create: Push Application Revision and Deploy to Nodes
		aws deploy push --application-name master_setup_app --description "This is a revision for the Master Application" --ignore-hidden-files --s3-location s3://"$aws_mwf_s3_master"/master_setup_app.zip --source . 1>/dev/null 2>&1
		printf "INFO: Push Updated Application: Pushed Revision to S3 Bucket.\\n"
		comm_resp="$(aws deploy create-deployment --application-name master_setup_app --deployment-config-name CodeDeployDefault.AllAtOnce --deployment-group-name master_setup_dep_group --s3-location bucket="$aws_mwf_s3_master",bundleType=zip,key=master_setup_app.zip)"
		deployment_id="$(echo "$comm_resp" | jq '.deploymentId' | sed -e 's/^"//' -e 's/"$//')"
		printf "INFO: Push Updated Application: Waiting for Deploying Application to Master Node.\\n"
		# Verify: Deployment Success on Master Node
		aws deploy wait deployment-successful --deployment-id "$deployment_id"
		if [ "$?" -eq "255" ]; then
			printf "ERROR: Push Updated Application: Master Application worker_setup_app could not be deployed. (Check AWS CodeDeploy Console to See Logs for Failure Conditions). Run \"./clean_infra.sh delete_application\", \"./clean_infra.sh delete_s3_buckets\", \"./deploy_infra.sh create_s3_bucket_update_policy\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
			exit
		fi
		printf "INFO: Push Updated Application: Completed Application Deployment to Master Node.\\n"
	fi
	if [[ "$update_app_type" == "WORKER" ]] || [[ "$update_app_type" == "BOTH" ]]; then
		chmod +x ../worker_setup/scripts/*
		cd ../worker_setup || return
		# Create: Push Application Revision and Deploy to Nodes
		aws deploy push --application-name worker_setup_app --description "This is a revision for the Worker Application" --ignore-hidden-files --s3-location s3://"$aws_mwf_s3_worker"/worker_setup_app.zip --source . 1>/dev/null 2>&1
		printf "INFO: Push Updated Application: Pushed Revision to S3 Bucket.\\n"
		comm_resp="$(aws deploy create-deployment --application-name worker_setup_app --deployment-config-name CodeDeployDefault.AllAtOnce --deployment-group-name worker_setup_dep_group --s3-location bucket="$aws_mwf_s3_worker",bundleType=zip,key=worker_setup_app.zip)"
		deployment_id="$(echo "$comm_resp" | jq '.deploymentId' | sed -e 's/^"//' -e 's/"$//')"
		printf "INFO: Push Updated Application: Waiting for Deploying Application to Worker Nodes.\\n"
		# Verify: Deployment Success on Worker Node
		aws deploy wait deployment-successful --deployment-id "$deployment_id"
		if [ "$?" -eq "255" ]; then
			printf "ERROR: Push Updated Application: Worker Application worker_setup_app could not be deployed. (Check AWS CodeDeploy Console to See Logs for Failure Conditions). Run \"./clean_infra.sh delete_application\", \"./clean_infra.sh delete_s3_buckets\", \"./deploy_infra.sh create_s3_bucket_update_policy\" and \"./deploy_infra.sh create_deploy_application\". Exiting Infrastructure Setup.\\n"
			exit
		fi
		printf "INFO: Push Updated Application: Completed Application Deployment to Worker Nodes.\\n"
	fi
	printf "SUCCESS: Push Updated Application: Application Revisions Successfully Deployed.\\n\\n"
}


# Introduction to AWS EC2 Infrastructure setup script
printf "Welcome to Master Worker Framework Deployment Setup for AWS.\\n"
printf "To use this deployment tool, specify the setup actions you want to perform as a command line argument.\\n"
printf "For Eg. './deploy_infra.sh all' will run all the setup steps.\\n"
printf "Possible Options are: \\n 0. help \\n 1. all \\n 2. aws_cli_configure \\n 3. create_iam_role_profile \\n 4. create_sec_group \\n 5. create_keypair \\n 6. create_master_node \\n 7. create_worker_nodes \\n 8. update_dns_verify_codedeploy \\n 9. create_s3_bucket_update_policy \\n 10. create_deploy_application \\n 11. push_updated_application\\n\\n"

# Choose a subset of functions to run
case $1 in
	"all" )
		aws_cli_configure
		create_iam_role_profile
		create_sec_group
		create_keypair
		create_master_node
		create_worker_nodes
		update_dns_verify_codedeploy
		create_s3_bucket_update_policy
		create_deploy_application
		;;
	"aws_cli_configure" )
		aws_cli_configure
		;;
	"create_iam_role_profile" )
		create_iam_role_profile
		;;
	"create_sec_group" )
		create_sec_group
		;;
	"create_keypair" )
		create_keypair
		;;
	"create_master_node" )
		create_master_node
		;;
	"create_worker_nodes" )
		create_worker_nodes
		;;
	"update_dns_verify_codedeploy" )
		update_dns_verify_codedeploy
		;;
	"create_s3_bucket_update_policy" )
		create_s3_bucket_update_policy
		;;
	"create_deploy_application" )
		create_deploy_application
		;;
	"push_updated_application" )
		push_updated_application
		;;
	"help" )
		echo "Choose one of the above actions."
		;;
	* )
		printf "ERROR: Command Line Argument not a valid input. Try Running this script again.\\n"
		;;
esac