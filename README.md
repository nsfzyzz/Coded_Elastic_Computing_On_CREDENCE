# Coded Elastic Computing using CREDENCE

The implementation of coded elastic computing is done using CREDENCE:
https://github.com/Credence-Research-Org/credence

Note that the following steps are not free and need payment by your AWS account!!!

Step 1: Go to deployment_scripts sub-directory

cd ./deployment_scripts

Step 2: Run the following command and follow the script commands

./deploy_infra.sh all

This will deploy the application to master and worker nodes on Amazon EC2. Use 20 worker machines. Choose m4.4xlarge instance for the master and m4.large instances for the workers. Choose ONDEMAND instances for both masters and workers. 

Step 3: Send the following request to master node to initiate experiment:
curl http://${master_dns}/master?startMaster=1

Step 4: Once the request is complete, run the command ./get_results.sh. 
It will return all the results logged by the logger to the parent directory with name results_${current_date_time}. This directory will have sub-directories named after the instance dns name for easier analysis.

Step 5: After you have downloaded the results, run ./clean_infra.sh all to clean all the resources and follow the script commands.

If you find our implementation useful, please consider citing the following paper:

@inproceedings{yang2019coded,
  title={Coded elastic computing},
  author={Yang, Yaoqing and Grover, Pulkit and Kar, Soummya and Interlandi, Matteo and Amizadeh, Saeed and Weimer, Markus},
  booktitle={IEEE International Symposium on Information Theory (ISIT)},
  year={2019}
}
