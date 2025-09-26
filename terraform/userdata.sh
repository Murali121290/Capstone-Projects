#!/bin/bash
set -xe

# --- Wait for apt locks (important in cloud-init) ---
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
   echo "Waiting for apt lock..."
   sleep 10
done

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install basic tools
sudo apt-get install -y docker.io git curl wget unzip openjdk-11-jdk apt-transport-https ca-certificates gnupg lsb-release

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add ubuntu user to docker group (so 'docker ps' works without sudo)
sudo usermod -aG docker ubuntu

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-key.gpg > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-key.gpg] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

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
