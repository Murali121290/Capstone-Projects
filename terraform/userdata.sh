#!/bin/bash -xe
# Runs on instance boot. Installs Docker, docker-compose, Java, Jenkins, SonarQube, Minikube prerequisites.

apt-get update
apt-get install -y docker.io docker-compose apt-transport-https ca-certificates curl gnupg lsb-release conntrack socat unzip

# Add ubuntu user to docker group (assumes ubuntu AMI)
usermod -aG docker ubuntu || true

# Install Java (required by SonarQube & Jenkins)
apt-get install -y openjdk-11-jdk

# Start Docker
systemctl enable docker
systemctl start docker

# Pull and run SonarQube and PostgreSQL (lightweight setup)
cat > /home/ubuntu/sonar-docker-compose.yml <<'EOF'
version: '3'
services:
  db:
    image: postgres:12
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - sonar-db:/var/lib/postgresql/data
  sonarqube:
    image: sonarqube:9-community
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    ports:
      - "9000:9000"
    depends_on:
      - db
volumes:
  sonar-db:
EOF

# Jenkins container
docker run -d --name jenkins -p 8080:8080 -p 50000:50000 -v /var/jenkins_home:/var/jenkins_home jenkins/jenkins:lts

# Start Sonar services
docker-compose -f /home/ubuntu/sonar-docker-compose.yml up -d

# Install kubectl and minikube
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl && mv kubectl /usr/local/bin/

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube && mv minikube /usr/local/bin/

# Start minikube using the docker driver
sudo -u ubuntu bash -lc "minikube start --driver=docker --container-runtime=docker --memory=4096 --cpus=2 || true"

# Install sonarqube scanner CLI for Jenkins & add to PATH
curl -sSLo /usr/local/bin/sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.7.0.2747-linux.zip || true
unzip /usr/local/bin/sonar-scanner.zip -d /opt || true
ln -s /opt/sonar-scanner-*/bin/sonar-scanner /usr/local/bin/sonar-scanner || true

chown -R ubuntu:ubuntu /home/ubuntu
