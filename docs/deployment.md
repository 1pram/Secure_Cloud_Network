**Prerequisites**
- Terraform installed
- AWS account
- Existing EC2 key pair
- A text editor (Notepad, VIM etc.) or an IDE like VSCode

**Deployment Flow**
1. Initialize terraform
   terraform init

2. Format and validate configuration
   terraform fmt -recursive
   terraform validate

3. Plan and apply
  terraform plan
  terraform apply

***Terraform prompts for required variables such as region, key pair name, and admin IP.***

**Access Workflow**
1. SSH into the bastion host using your key pair
2. From the bastion, SSH into private instances
3. IAM roles automatically grant access to permitted AWS resources

***No direct access to instances is possible from the Internet.***
