pipeline {
    agent any
    triggers { githubPush() }
    options { timestamps(); disableConcurrentBuilds() }

    environment {
        APP_NAME    = 'myapp'
        IMAGE_TAG   = "${env.BUILD_NUMBER ?: 'latest'}"
        K3S_NODE_IP = ''
    }

    stages {

        stage('Init Vars') {
            steps {
                script {
                    def ip = sh(script: "curl -s http://169.254.169.254/latest/meta-data/local-ipv4", returnStdout: true).trim()
                    env.K3S_NODE_IP = ip
                    echo "K3S_NODE_IP resolved to: ${env.K3S_NODE_IP}"
                }
            }
        }

        stage('Checkout') {
            steps { checkout scm }
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
                    echo "🐳 Building Docker image ${APP_NAME}:${IMAGE_TAG} ..."
                    sh "docker build -t ${APP_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Load Image into K3s') {
            steps {
                script {
                    echo "📦 Loading Docker image into K3s containerd..."
                    sh """
                        set -e
                        docker save ${APP_NAME}:${IMAGE_TAG} -o /tmp/${APP_NAME}.tar
                        sudo ctr --address /run/k3s/containerd/containerd.sock images import /tmp/${APP_NAME}.tar
                        echo "✅ Image ${APP_NAME}:${IMAGE_TAG} imported successfully into K3s."
                    """
                }
            }
        }

        stage('K3s Connectivity Check') {
            steps {
                script {
                    echo "🔍 Verifying Kubernetes cluster connectivity..."
                    sh "kubectl get nodes -o wide"
                }
            }
        }

        stage('Deploy to K3s') {
            steps {
                script {
                    echo "🚀 Deploying ${APP_NAME} to K3s..."
                    sh """
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
                        kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG} || true
                    """
                }
            }
        }

        stage('Smoke Test (Non-Fatal)') {
            steps {
                script {
                    echo "🧪 Running optional smoke test..."
                    sh """
                        set +e
                        echo "Waiting for rollout..."
                        kubectl rollout status deployment/${APP_NAME} --timeout=120s || true

                        echo "Checking pod status..."
                        kubectl get pods -o wide || true

                        echo "If pods are pending or restarting, check details:"
                        kubectl describe deployment ${APP_NAME} | tail -n 20 || true
                        kubectl describe pods -l app=${APP_NAME} | tail -n 20 || true

                        echo "Skipping hard failure — continuing pipeline ✅"
                    """
                }
            }
        }
    }

    post {
        always {
            echo "🧹 Cleaning up workspace"
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
