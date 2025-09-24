#!/bin/bash -xe
# Bootstrap: Docker, Docker Compose, Java, Jenkins, SonarQube, Minikube, Scanner

apt-get update -y
apt-get install -y \
  docker.io \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  conntrack \
  socat \
  unzip \
  openjdk-11-jdk

# Add ubuntu user to docker group
usermod -aG docker ubuntu || true

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Install latest Docker Compose (v2.x)
DOCKER_COMPOSE_VERSION="2.29.7"
curl -SL https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Prepare SonarQube + PostgreSQL with docker-compose
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

chown ubuntu:ubuntu /home/ubuntu/sonar-docker-compose.yml

# Run Jenkins container
mkdir -p /var/jenkins_home
chown -R 1000:1000 /var/jenkins_home
docker run -d --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v /var/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Start SonarQube + DB
sudo -u ubuntu docker-compose -f /home/ubuntu/sonar-docker-compose.yml up -d

# Install kubectl
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/

# Install minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube && mv minikube /usr/local/bin/

# Start minikube (with Docker driver)
sudo -u ubuntu bash -lc "minikube start --driver=docker --memory=4096 --cpus=2 || true"

# Install SonarScanner CLI
SCANNER_VERSION="4.7.0.2747"
curl -sSLo /tmp/sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCANNER_VERSION}-linux.zip
unzip /tmp/sonar-scanner.zip -d /opt
ln -s /opt/sonar-scanner-*/bin/sonar-scanner /usr/local/bin/sonar-scanner
rm -f /tmp/sonar-scanner.zip

# Fix ownership
chown -R ubuntu:ubuntu /home/ubuntu
