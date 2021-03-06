# Demo deployment of BIG-IPs using Terraform
# Pre-Req
This example creates the following resources inside of AWS.  Please ensure your IAM user or IAM Role has privileges to create these objects.

**Note 1:** This example requires 4 Elastic IPs, please ensure your EIP limit on your account can accommodate this (information on ElasticIP limits can be found at https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html#limits_ec2)
 - AWS VPC
 - AWS Route Tables
 - AWS Nat Gateways
 - AWS Elastic IPs
 - AWS EC2 Instances
 - AWS Subnets
 - AWS Security Groups

 **Note 2:** In order to use this demo your AWS account must be subscribed to the F5 AMI and its associated terms and conditions. If your account is not subscribed, the first time ```terraform apply``` is run you will receive an error similar to the following:

 **Error:** Error launching source instance: OptInRequired: In order to use this AWS Marketplace product you need to accept terms and subscribe. To do so please 
visit https://aws.amazon.com/marketplace/pp?sku=XXXXXXXXXXXXXXXXXXXXXXXX

The url embedded within the error message will load the appropriate location in order to subscribe the AWS account to the F5 AMI.
After subscribing, re-run the ```terraform apply``` command and the error should not occur again.

 **Note 3:** An authentication token must be generated and recorded as documented below in order to access the modules required by this demo
https://www.terraform.io/docs/commands/cli-config.html
- Log into terraform.io
- Go to Account > User Settings > Tokens
- Record token in safe place
# 1. Running Using a Docker container
You can choose to run this from your workstation or a container although container will be much more straight forward to get working. Follow the instructions below as appropriate;
You can run the container locally or use a jumpbox. I chose to deploy a free tier ubuntu 18 box in aws.
**Docker Container Setup**

**Note:** Port 8089 is opened in order to use the gui of the locust load generating tool should you choose to use it.

**Using Docker**
Deploy an ubuntu jumpbox and install Docker CE - 
  - `sudo apt install apt-transport-https ca-certificates curl software-properties-common`
  - `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -`
  - `sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic test"`
  - `sudo apt update`
  - `sudo apt upgrade`
  - `sudo apt install docker-ce`
  - `docker -v`

**Using your Workstation - (alot more work than the container deployment method above)**
  - install Terraform https://learn.hashicorp.com/terraform/getting-started/install.html
  - install inpsec https://www.inspec.io/downloads/
  - install locust https://docs.locust.io/en/stable/installation.html
  - install jq https://stedolan.github.io/jq/download/
  - if on a Windows workstation, install Putty for scp support https://putty.org
# 2. Configuring Docker on jumphost: 
- `cd $home`
- `git clone https://github.com/dober-man/terraform-aws-bigip-setup.git`
- `cd terraform-aws-bigip-setup/`
- `sudo docker run -it -v $(pwd):/workspace -p 8089:8089 mmenger/tfdemoenv:1.6.2 /bin/bash`

**Note:** -v is volume option and maps host directory (bi-directionally and dynamically) to allow host to share files into guest container. Now all tools from repo are available in the docker container - any other files put into /home/ubuntu/terraform-aws-bigip-setup on the jumpbox will replicate dynamically to the container workspace directory. 
# 3. Configure Access Credentials
**Pre-req** - Created new user in AWS IAM and granted admin access and saved keys for use below

Start from within the clone of this repository on the jumphost **(/home/ubuntu/terraform-aws-bigip-setup)**
- `vi secrets.auto.tfvars`

enter the following in the *secrets.auto.tfvars* file
```hcl
AccessKeyID         = "<AN ACCESS KEY FOR YOUR AWS ACCOUNT>" 
SecretAccessKey     = "<THE SECRET KEY ASSOCIATED WITH THE AWS ACCESS KEY>" 
ec2_key_name        = "<THE NAME OF AN AWS KEY PAIR WHICH IS ASSOCIATE WITH THE AWS ACOUNT>"
ec2_key_file        = "<THE PATH TO AN SSH KEY FILE USED TO CONNECT TO THE UBUNTU SERVER ONCE IT IS CREATED. NOTE: THIS PATH SHOULD BE RELATIVE TO THE CONTAINER ROOT>"
```
- save the file and quit vi

#Example
```hcl
AccessKeyID         = "AKIAUEKXXXXXXITHV"
SecretAccessKey     = "+CXMydN+DJXXXXXXSq2MWQlA6o/+fkSS"
ec2_key_name        = "bhs-f5aws"
ec2_key_file        = "./bhs-f5aws.pem"
```

* If using a jumpbox you will need to copy your pem file to the jumpbox into the terraform-aws-bigip-setup directory and make sure mapping for ec2_key_file is correct in the secrets.auto.tfvars* file. **Make sure pem file is in (/home/ubuntu/terraform-aws-bigip-setup)**
# 4. Setup AWS Environment with Terraform
**Note 1:** When initializing Terraform it scans all tf files and looks for references to modules and providers and pulls down any necessary code
- From within the docer container; Run: ```terraform init```
This creates .terraform hidden directory and prepares the builds for the BIG-IPS and the underpinning infrastructure

- Run: ```terraform apply```

**Note 2:** Running ```terraform plan``` - will show what would happen under ```terraform apply``` without adding the deploy option

**Note 3:** Terraform checks three things when running ```plan``` or ```apply```; 
1. .tf files
2. Terraform state files (.tfstate)
3. Terraform looks at what is actually built - (it logs into AWS and checks for what has been built that it believes should exist)
4. Next terraform creates a "plan"

```terraform apply``` always shows a plan and item count - double check that this looks right

Ex: Plan: 86 to add, 0 to change, 0 to destroy.

Selecting **yes** will build the entire infrastructure 

```Depending upon how you intend to use the environment you may need to wait until after Terraform is complete. The configuration of the BIG-IPs is completed asynchoronously. If you need the BIG-IPs to be fully configured before proceeding, the following Inspec tests validate the connectivity of the BIG-IP and the availability of the management API end point.```
# 5. Check the status of the BIG-IPs
Run: 
- ````terraform output --json > inspec/bigip-ready/files/terraform.json````
- ````inspec exec inspec/bigip-ready````
**Note:** These steps can also be performed using ./runtests.sh

Once the tests all pass the BIG-IPs are ready!

**You will get an error about telemetry streaming module not being available. This is expected since the terraform  doesn't support/install TS at this time. ​The ansible playbook from https://github.com/mjmenger/ansible-uber-demo does the TS configuration.**

If terraform returns an error (other than telemetry streaming), rerun ```terraform apply```.
# 6. Log into the BIG-IP
Find the connection info for the BIG-IP: 

```hcl
export BIGIPHOST0=`terraform output --json | jq -r '.bigip_mgmt_public_ips.value[0]'`
export BIGIPMGMTPORT=`terraform output --json | jq -r '.bigip_mgmt_port.value'`
export BIGIPPASSWORD=`terraform output --json | jq -r '.bigip_password.value'`
export JUMPHOSTIP=`terraform output --json | jq -r '.jumphost_ip.value[0]'`
echo connect at https://$BIGIPHOST0:$BIGIPMGMTPORT with $BIGIPPASSWORD
echo connect to jumphost at with
echo ssh -i "<THE AWS KEY YOU IDENTIFIED ABOVE>" ubuntu@$JUMPHOSTIP
```

**Note:** These steps can also be performed by using ./findthehosts.sh script

- Connect to the BIGIP at https://<bigip_mgmt_public_ips>:<bigip_mgmt_port> and login as user:admin and password:<bigip_password>

# 7. Teardown
When you are done using the demo environment you will need to decommission it

```terraform destroy```

As a final step check that terraform doesn't think there's anything remaining

```terraform show```

This should return a blank line

