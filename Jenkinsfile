pipeline {
    agent any
    triggers { githubPush() }
    options { timestamps(); disableConcurrentBuilds() }

    environment {
        APP_NAME         = 'myapp'
        IMAGE_TAG        = "${env.BUILD_NUMBER ?: 'latest'}"
        MINIKUBE_PROFILE = 'minikube'
        REGISTRY         = 'docker.io'                  // Docker Hub
        DOCKER_CREDENTIALS = 'docker-hub-creds'         // Jenkins credentials ID
    }

    stages {
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
                    sh "docker build -t ${APP_NAME}:${IMAGE_TAG} ."
                }
            }
        }

       stage('Deploy to Minikube') {
            steps {
                sh """
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG}
                """
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    sh """
                        kubectl rollout status deployment/${APP_NAME} --timeout=120s
                        NODE_IP=\$(minikube ip --profile=${MINIKUBE_PROFILE})
                        NODE_PORT=\$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
                        URL="http://\$NODE_IP:\$NODE_PORT/"
                        echo "Testing app at \$URL"
                        for i in {1..5}; do
                            curl -f \$URL && break || sleep 5
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
    }
}
