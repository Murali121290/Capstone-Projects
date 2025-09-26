#!/bin/bash
set -xe

# Update system
apt-get update -y
apt-get upgrade -y

# Install basic tools
apt-get install -y docker.io git curl wget unzip openjdk-11-jdk apt-transport-https ca-certificates gnupg lsb-release

# Enable and start Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-key.gpg > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-key.gpg] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins
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
