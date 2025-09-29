pipeline {
    agent any
    triggers { githubPush() }
    options { timestamps(); disableConcurrentBuilds() }

    environment {
        APP_NAME         = 'myapp'
        IMAGE_TAG        = "${env.BUILD_NUMBER ?: 'latest'}"
        MINIKUBE_PROFILE = 'minikube'
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
                    sh """
                        set -e
                        sudo docker --version
                        echo "Building ${APP_NAME}:${IMAGE_TAG}"
                        docker build -t ${APP_NAME}:${IMAGE_TAG} .
                        docker tag ${APP_NAME}:${IMAGE_TAG} ${APP_NAME}:latest
                    """
                }
            }
        }

        stage('Load Image into Minikube') {
            steps {
                sh "minikube image load ${APP_NAME}:${IMAGE_TAG} --profile=${MINIKUBE_PROFILE}"
            }
        }

        stage('Deploy to Minikube') {
            steps {
                sh """
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG} || true
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
                          echo "Attempt \$i: checking app..."
                          if curl -fs \$URL; then
                            echo "App is reachable ✅"
                            break
                          else
                            echo "App not ready, retrying in 5s..."
                            sleep 5
                          fi
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
