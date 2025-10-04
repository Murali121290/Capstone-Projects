# All-in-One CI/CD on AWS (Terraform + Jenkins + SonarQube + K3s)

## Overview
This project provisions an EC2 instance via Terraform and boots Jenkins, SonarQube, and K3s on that instance using Docker. A vulnerable Flask app (`app.py`) is provided with two seeded vulnerabilities (SQL injection and insecure `eval`). The Jenkins pipeline runs SonarQube analysis (first run expected to fail Quality Gate), then after you fix the vulnerabilities it will build, push to ECR, and deploy to K3s.

## High-level architecture

GitHub --> Jenkins --> SonarQube
                     \
                      --> Docker image --> ECR --> K3s

## Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform v1.0+
- An SSH public key at `~/.ssh/id_rsa.pub` (or change `variables.tf`)
- A GitHub repo where you will push this code

## Steps
1. **Configure Terraform variables** (in `terraform/variables.tf`) if you want to change region/AMI.
2. `cd terraform`
3. `terraform init`
4. `terraform apply -var 'public_key_path=~/.ssh/id_rsa.pub' -auto-approve`
5. Note the `instance_public_ip` output. SSH in:
   `ssh -i ~/.ssh/id_rsa ubuntu@<public_ip>`
6. Retrieve Jenkins initial password:
   `sudo cat /var/jenkins_home/secrets/initialAdminPassword`
7. Open Jenkins at `http://<public_ip>:8080` and complete setup (install recommended plugins).
8. Create SonarQube token via Sonar UI `http://<public_ip>:9000` (default admin/admin) and add to Jenkins credentials as `sonar-token`.
9. Create an ECR repo (Terraform already created). Use the `ecr_repository_url` output.
10. In Jenkins, create a Pipeline job that points to your GitHub repo and run it.

## Demonstration of Quality Gate
- On the **first** run the SonarQube analysis should fail the quality gate because the app contains obvious vulnerabilities (SQL injection and `eval`).
- Fix the vulnerabilities in `app/app.py` (see guidance below), push changes, re-run the pipeline. The SonarQube gate should pass and the pipeline will proceed to build and deploy.

## Fix suggestions (example)
- Replace the SQL query with a parameterized query using `?` placeholders.
- Remove `eval()` and replace with a safe expression parser or whitelist operations.

## Start/Stop EC2 (cost control)
After `terraform apply`, the `instance_id` is output. Use the helper scripts in `scripts/`:
- `./scripts/aws_stop_instances.sh <instance-id>`
- `./scripts/aws_start_instances.sh <instance-id>`

Or directly with AWS CLI:
- `aws ec2 stop-instances --instance-ids <id>`
- `aws ec2 start-instances --instance-ids <id>`

## Cleanup
1. `terraform destroy -auto-approve` from `terraform/` folder to delete resources created by Terraform.
2. Manually clean up ECR images if needed.

## Notes, limitations, and tips
- K3s inside an EC2 instance uses Docker driver (no nested VM). Ensure instance type has enough memory (>=4GB). We used `t3.medium` as a starting point.
- The user-data script does a lot of heavy lifting; it may take several minutes for services to become healthy.
- SonarQube may require tuning for production - this is a demo setup for CI/CD learning.
