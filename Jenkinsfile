pipeline {
    agent any
    triggers { githubPush() }
    options { timestamps(); disableConcurrentBuilds() }

    environment {
        APP_NAME    = 'myapp'
        IMAGE_TAG   = "${env.BUILD_NUMBER ?: 'latest'}"
        K3S_NODE_IP = ''   // set dynamically
    }

    stages {
        stage('Init Vars') {
            steps {
                script {
                    // Get EC2 private IP dynamically from AWS metadata
                    def ip = sh(script: "curl -s http://169.254.169.254/latest/meta-data/local-ipv4", returnStdout: true).trim()
                    env.K3S_NODE_IP = ip
                    echo "K3S_NODE_IP resolved to: ${env.K3S_NODE_IP}"
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            set -e
                            "${scannerHome}/bin/sonar-scanner"
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image ${APP_NAME}:${IMAGE_TAG} ..."
                    sh """
                        set -e
                        docker build -t ${APP_NAME}:${IMAGE_TAG} .
                    """
                }
            }
        }

        stage('K3s Connectivity Check') {
            steps {
                script {
                    echo "Verifying Kubernetes cluster connectivity..."
                    sh """
                        kubectl cluster-info
                        kubectl get nodes -o wide
                    """
                }
            }
        }

        stage('Deploy to k3s') {
            steps {
                script {
                    echo "Deploying ${APP_NAME} to K3s..."
                    sh """
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
                        kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG} || true
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    echo "Performing smoke test..."
                    sh """
                        echo "Waiting for rollout..."
                        kubectl rollout status deployment/${APP_NAME} --timeout=120s

                        echo "Checking pods..."
                        kubectl get pods -o wide

                        NODE_PORT=\$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
                        PRIVATE_IP=\$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
                        PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

                        echo "Testing with private IP: http://\$PRIVATE_IP:\$NODE_PORT/"
                        for i in {1..5}; do
                            curl -sf http://\$PRIVATE_IP:\$NODE_PORT/ && echo "✅ Private IP test OK" && break || sleep 5
                        done

                        echo "Testing with public IP: http://\$PUBLIC_IP:\$NODE_PORT/"
                        for i in {1..5}; do
                            curl -sf http://\$PUBLIC_IP:\$NODE_PORT/ && echo "✅ Public IP test OK" && break || sleep 5
                        done
                    """
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning up workspace"
            cleanWs()
        }
        failure {
            echo "❌ Build failed. Check logs above."
        }
        success {
            echo "✅ Build, Analysis, and Deployment succeeded!"
        }
    }
}
