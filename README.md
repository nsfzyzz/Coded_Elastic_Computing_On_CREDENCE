# Coded Elastic Computing using CREDENCE

The implementation of coded elastic computing is done using CREDENCE:
https://github.com/Credence-Research-Org/credence
The CREDENCE is under the following license:

BSD 3-Clause License

Copyright (c) 2018, Carnegie Mellon University All rights reserved.

Note that the following steps are not free!!!

Step 0: Setup an AWS account.

Step 1: Go to deployment_scripts sub-directory

cd ./deployment_scripts

Step 2: Run the following command and follow the script commands

./deploy_infra.sh all

This will let you configure CLI, launch EC2 instances, and deploy the application to master and worker nodes on Amazon EC2. In our experiment, we use 20 worker machines. We use m4.4xlarge instance for the master and m4.large instances for the workers. We use ONDEMAND instances for both masters and workers. 

Step 3: Send the following request to master node to initiate experiment:

curl http://${master_dns}/master?startMaster=1

This may take some time to finish (should be less than half of an hour).

Step 4: Once the request is complete, run the command 

./get_results.sh. 

It will return all the results logged by the logger to the parent directory with name results_${current_date_time}. This directory will have sub-directories named after the instance dns name for easier analysis.

Step 5: After you have downloaded the results, run ./clean_infra.sh all to clean all the resources and follow the script commands.

If you find our implementation useful, please consider citing the following paper:

@inproceedings{yang2019coded,
  title={Coded elastic computing},
  author={Yang, Yaoqing and Grover, Pulkit and Kar, Soummya and Interlandi, Matteo and Amizadeh, Saeed and Weimer, Markus},
  booktitle={IEEE International Symposium on Information Theory (ISIT)},
  year={2019}
}
