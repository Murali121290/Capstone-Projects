#!/bin/bash
exec > /var/log/userdata.log 2>&1
set -xe

# --- Wait for apt locks ---
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
   echo "Waiting for apt lock..."
   sleep 10
done

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install basic tools + Java 17 (required for Jenkins)
sudo apt-get install -y docker.io git curl wget unzip openjdk-17-jdk apt-transport-https ca-certificates gnupg lsb-release software-properties-common fontconfig

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add ubuntu user to Docker group
sudo usermod -aG docker ubuntu

# Add Jenkins repo (secure method with .gpg key)
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | gpg --dearmor | sudo tee /usr/share/keyrings/jenkins-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt-get update -y
sudo apt-get install -y jenkins

# Enable and start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Add Jenkins user to Docker group
sudo usermod -aG docker jenkins

# Restart Jenkins to apply group changes
sudo systemctl restart jenkins

# Run SonarQube (only if not already running)
if [ ! "$(sudo docker ps -q -f name=sonarqube)" ]; then
  sudo docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
fi

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# --- Reboot if required ---
if [ -f /var/run/reboot-required ]; then
  echo "System reboot required. Rebooting..."
  sudo reboot
fi
