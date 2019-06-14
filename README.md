# Coded Elastic Computing using CREDENCE

The implementation of coded elastic computing is done using CREDENCE:

https://github.com/Credence-Research-Org/credence

The CREDENCE project is under the following license:

BSD 3-Clause License

Copyright (c) 2018, Carnegie Mellon University All rights reserved.

Step 0: Setup an AWS account.

Note that the following the steps below will incur cost to your AWS account!!!

Step 1: Go to deployment_scripts sub-directory

cd ./deployment_scripts

Step 2: Run the following command and follow the script commands

./deploy_infra.sh all

This will let you configure CLI, launch EC2 instances, and deploy the application to master and worker nodes on Amazon EC2. Here is an example of the answers to some of the questions. The whole process runs approximately 30 minutes on a personal MAC.

Master Node Instance Type: m4.4xlarge

Master Project Tag Name: arbitrary_key arbitrary_value

Master Node Volume Size: (do not type anything; use default)

Master Node Placement Availability Zone: (do not type anything; use default)

"SPOT" or "ONDEMAND": ONDEMAND

Number of Worker Nodes: 20

Worker Node Instance Type: m4.large

Worker Project Tag Name: arbitrary_key arbitrary_value

Worker Node Volume Size: (do not type anything; use default)

Worker Node Placement Availability Zone: (do not type anything; use default)

"SPOT" or "ONDEMAND": ONDEMAND

In our experiment, we used 20 worker machines. We used m4.4xlarge instance for the master and m4.large instances for the workers. We used ONDEMAND instances for both masters and workers.

Step 3: Send the following request to master node to initiate experiment:

curl http://${master_dns}/master?startMaster=1

This may take some time to finish (should be less than 30 minutes).

Step 4: Once the request is complete, run the command 

./get_results.sh. 

It will return all the results logged by the logger to the parent directory with name results_${current_date_time}. This directory will have sub-directories named after the instance dns name for easier analysis.

Step 5: After you have downloaded the results, run

./clean_infra.sh all 

to clean all the resources and follow the script commands.

If you find our implementation useful, please consider citing the following paper:

@inproceedings{yang2019coded,
  title={Coded elastic computing},
  author={Yang, Yaoqing and Grover, Pulkit and Kar, Soummya and Interlandi, Matteo and Amizadeh, Saeed and Weimer, Markus},
  booktitle={IEEE International Symposium on Information Theory (ISIT)},
  year={2019}
}
