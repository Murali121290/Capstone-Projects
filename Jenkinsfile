pipeline {
    agent any

    environment {
        APP_NAME   = 'myapp'
        IMAGE_TAG  = "${env.BUILD_NUMBER ?: 'latest'}"
        SONARQUBE  = 'SonarQube'   // Name configured in Jenkins -> Manage Jenkins -> Configure System -> SonarQube Servers
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/<your-username>/Capstone-Projects.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'sonar-scanner'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                  docker build -t ${APP_NAME}:${IMAGE_TAG} .
                """
            }
        }

        stage('Load Image into Minikube') {
            steps {
                sh """
                  minikube image load ${APP_NAME}:${IMAGE_TAG} --profile=minikube
                """
            }
        }

        stage('Deploy to Minikube') {
            steps {
                sh """
                  # Replace placeholder in k8s manifest with built image
                  sed -i 's#IMAGE_PLACEHOLDER#${APP_NAME}:${IMAGE_TAG}#g' k8s/deployment.yaml
                  kubectl apply -f k8s/deployment.yaml
                  kubectl apply -f k8s/service.yaml
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh """
                  kubectl rollout status deployment/${APP_NAME} --timeout=120s
                  NODE_IP=$(minikube ip)
                  NODE_PORT=$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
                  echo "Testing app at http://${NODE_IP}:${NODE_PORT}/"
                  sleep 5
                  curl -f http://${NODE_IP}:${NODE_PORT}/ || (echo "App not reachable" && exit 1)
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
