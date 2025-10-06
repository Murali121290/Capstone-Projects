# 🚀 All-in-One CI/CD on AWS (Terraform + Jenkins + SonarQube + K3s)

This project provisions a complete **CI/CD environment on AWS EC2** using Terraform and a shell bootstrap script (`userdata.sh`).

The environment includes:
- **Jenkins (LTS JDK17)** — CI/CD pipeline orchestrator  
- **SonarQube (LTS Community Edition)** — Static code analysis  
- **K3s (Lightweight Kubernetes)** — Deployment cluster  
- **Docker** — Container build & runtime engine  
- **kubectl** — CLI for K3s management  

Everything is automatically installed and configured with a single Terraform apply.

---

## 🧩 Architecture Overview

---

## ⚙️ Features

✅ **Automated EC2 provisioning** via Terraform  
✅ **Bootstrap script (`userdata.sh`)** installs and configures all components  
✅ **Jenkins Docker container** with access to:
- `/var/run/docker.sock` (for Docker builds)
- `/run/k3s/containerd/containerd.sock` (for K3s image load)
✅ **SonarQube** runs in a separate container on port `9000`
✅ **K3s cluster** installed and accessible from Jenkins using `.kube/config`
✅ **Security Fixes**
- Correct group and socket permissions for Docker and containerd  
- Jenkins automatically added to `docker` and `containerd` groups  
✅ **Automatic service startup** on EC2 boot  

---

## 🧰 Prerequisites

Before starting, ensure you have:
- AWS CLI configured with access keys  
- Terraform installed (`>= 1.5`)  
- SSH keypair available in AWS  
- Inbound ports open:  
  - `8080` → Jenkins  
  - `9000` → SonarQube  
  - `22` → SSH (optional)  

---

## 🧱 Setup Steps

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/yourusername/ci-cd-aws.git
cd ci-cd-aws

2️⃣ Update Terraform Variables

In terraform/variables.tf, set:

aws_region  = "ap-south-1"
instance_type = "t3.medium"
key_name = "your-keypair"

3️⃣ Deploy Infrastructure
cd terraform
terraform init
terraform apply -auto-approve


Terraform will:

Create an EC2 instance with security groups

Attach the userdata.sh script for automatic bootstrap

🔧 Bootstrap Script Highlights (userdata.sh)

The script performs:

System update and installs dependencies

Installs and starts Docker

Installs K3s and configures kubeconfig

Fixes Docker & containerd socket permissions

Runs Jenkins and SonarQube containers

Adds Jenkins to docker and containerd groups

Verifies access to both Docker and K3s containerd

Prints Jenkins initial admin password at the end

🧪 Accessing the Environment
🟦 Jenkins

URL: http://<EC2-Public-IP>:8080

Initial Password:

sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword


Install recommended plugins and create an admin user.

🟨 SonarQube

URL: http://<EC2-Public-IP>:9000

Default Login: admin / admin
(You’ll be prompted to reset password on first login.)

🟩 K3s

From inside Jenkins:

kubectl get nodes


or from EC2 host:

kubectl --kubeconfig=/home/ubuntu/.kube/config get nodes

🧩 Pipeline Example

Example Jenkins stages:

pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('SonarQube Analysis') {
      steps {
        script {
          withSonarQubeEnv('MySonarQube') {
            sh 'sonar-scanner'
          }
        }
      }
    }
    stage('Build Docker Image') {
      steps {
        sh 'docker build -t myapp:latest .'
      }
    }
    stage('Deploy to K3s') {
      steps {
        sh 'kubectl apply -f k8s/deployment.yaml'
      }
    }
  }
}

🔒 Security Notes

Docker socket permissions (/var/run/docker.sock) are temporarily set to 666 to ensure Jenkins build success.
In production, prefer adding Jenkins to the docker group and using tighter permissions.

Do not expose ports 8080 or 9000 to the public internet without proper firewall rules.

Always change default credentials after first login.

🧹 Cleanup

To destroy the EC2 and all resources:

terraform destroy -auto-approve

🧠 Troubleshooting
Issue	Cause	Fix
permission denied /var/run/docker.sock	Jenkins not in docker group	sudo usermod -aG docker jenkins && sudo docker restart jenkins
containerd.sock permission denied	Wrong socket perms	sudo chmod 666 /run/k3s/containerd/containerd.sock
SonarQube not accessible	Still starting up	Wait ~2–3 minutes after first boot
kubectl not found in Jenkins	PATH issue	Ensure /usr/local/bin/kubectl is mounted in container
📜 License

This project is licensed under the MIT License — feel free to use and modify.
