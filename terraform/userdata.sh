#!/bin/bash
set -xe

# Update system
dnf update -y

# Install basic tools
dnf install -y docker git curl wget unzip java-11-openjdk

# Enable and start Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install Jenkins
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.repo -o /etc/yum.repos.d/jenkins.repo
dnf install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# Run SonarQube (Docker)
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
