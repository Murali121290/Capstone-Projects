1. SSH to EC2: ssh -i ~/.ssh/id_rsa ubuntu@<public_ip>
2. Get Jenkins initial admin password: sudo cat /var/jenkins_home/secrets/initialAdminPassword
3. Open Jenkins at http://<public_ip>:8080 and complete first-run wizard.
4. Install required plugins: Git, Pipeline, Docker Pipeline, SonarQube Scanner, Amazon ECR.
5. Add credentials:
   - Username/password or GitHub token for checkout (if private repo)
   - SonarQube token (create from Sonar UI)
   - AWS credentials for pushing to ECR (or rely on instance role if IAM profile attached)
6. Create a new pipeline job that points to this repository and uses the included Jenkinsfile.
