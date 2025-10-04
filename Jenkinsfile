pipeline {
    agent any
    triggers { githubPush() }
    options { timestamps(); disableConcurrentBuilds() }

    environment {
        APP_NAME           = 'myapp'
        IMAGE_TAG          = "${env.BUILD_NUMBER ?: 'latest'}"
        K3S_NODE_IP        = ''   // will be set dynamically
    }

    stages {
        stage('Init Vars') {
            steps {
                script {
                    // Use AWS metadata service to get EC2 private IP
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
                sh "docker build -t ${APP_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('K3s Connectivity Check') {
            steps {
                sh """
                  echo "Checking cluster connectivity..."
                  kubectl cluster-info
                  kubectl get nodes -o wide
                """
            }
        }

        stage('Deploy to k3s') {
            steps {
                sh """
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    # Override placeholder with the freshly built local image
                    kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG}
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh """
                    echo "Waiting for rollout..."
                    kubectl rollout status deployment/${APP_NAME} --timeout=120s

                    echo "Checking pods..."
                    kubectl get pods -o wide

                    NODE_PORT=\$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
                    URL="http://${K3S_NODE_IP}:\$NODE_PORT/"
                    echo "Testing app at \$URL"

                    for i in {1..5}; do
                        curl -f \$URL && echo "✅ App is up!" && break || sleep 5
                    done
                """
            }
        }
    }

    post {
        always {
            echo "Cleaning up workspace"
            cleanWs()
        }
    }
}
