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

        // ----------------------
        // Stage 1: Checkout
        // ----------------------
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // ----------------------
        // Stage 2: SonarQube Analysis
        // ----------------------
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

        // ----------------------
        // Stage 3: Quality Gate
        // ----------------------
        stage('Quality Gate') {
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ----------------------
        // Stage 4: Build Docker Image
        // ----------------------
        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker --version"
                    sh "docker build -t ${APP_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        // ----------------------
        // Stage 5: Load Image into Minikube
        // ----------------------
        stage('Load Image into Minikube') {
            steps {
                sh "minikube image load ${APP_NAME}:${IMAGE_TAG} --profile=${MINIKUBE_PROFILE}"
            }
        }

        // ----------------------
        // Stage 6: Deploy to Kubernetes
        // ----------------------
        stage('Deploy to Minikube') {
            steps {
                sh """
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG}
                """
            }
        }

        // ----------------------
        // Stage 7: Smoke Test
        // ----------------------
        stage('Smoke Test') {
            steps {
                script {
                    sh """
                        kubectl rollout status deployment/${APP_NAME} --timeout=120s
                        NODE_IP=\$(minikube ip --profile=${MINIKUBE_PROFILE})
                        NODE_PORT=\$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
                        URL="http://\$NODE_IP:\$NODE_PORT/"
                        echo "Testing app at \$URL"
                        # Retry curl up to 5 times
                        for i in {1..5}; do
                            curl -f \$URL && break || sleep 5
                        done
                    """
                }
            }
        }
    }

    // ----------------------
    // Post Actions
    // ----------------------
    post {
        always {
            echo "Cleaning up workspace"
            cleanWs()
        }
    }
}
