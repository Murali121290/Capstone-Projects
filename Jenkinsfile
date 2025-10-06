pipeline {
    agent any
    triggers { githubPush() }
    options { timestamps(); disableConcurrentBuilds() }

    environment {
        APP_NAME  = 'myapp'
        IMAGE_TAG = "${env.BUILD_NUMBER ?: 'latest'}"
    }

    stages {

        stage('Init Vars') {
            steps {
                script {
                    def ip = sh(script: "curl -s http://169.254.169.254/latest/meta-data/local-ipv4", returnStdout: true).trim()
                    env.K3S_NODE_IP = ip
                    echo "✅ K3S_NODE_IP resolved: ${env.K3S_NODE_IP}"
                }
            }
        }

        stage('Checkout') {
            steps {
                // Works for both Pipeline from SCM and inline script modes
                script {
                    try {
                        checkout scm
                    } catch (err) {
                        echo "⚠️ SCM checkout failed — manually cloning..."
                        sh "git clone https://github.com/Murali121290/Capstone-Projects.git ."
                    }
                }
                sh "ls -la && git rev-parse --show-toplevel"
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
                echo "🐳 Building Docker image ${APP_NAME}:${IMAGE_TAG} ..."
                sh "docker build -t ${APP_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Load Image into K3s') {
            steps {
                echo "📦 Loading image into K3s containerd..."
                sh """
                    docker save ${APP_NAME}:${IMAGE_TAG} -o /tmp/${APP_NAME}.tar
                    ctr --address /run/k3s/containerd/containerd.sock images import /tmp/${APP_NAME}.tar
                    echo "✅ Image ${APP_NAME}:${IMAGE_TAG} imported successfully!"
                """
            }
        }

        stage('Deploy to K3s') {
            steps {
                echo "🚀 Deploying ${APP_NAME} to K3s..."
                sh """
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG} || true
                """
            }
        }

        stage('Smoke Test (Non-Fatal)') {
            steps {
                echo "🧪 Performing smoke test..."
                sh """
                    set +e
                    kubectl rollout status deployment/${APP_NAME} --timeout=90s || true
                    kubectl get pods -o wide || true
                    echo "✅ Pipeline complete (non-fatal test)."
                """
            }
        }
    }

    post {
        always {
            echo "🧹 Cleaning workspace..."
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
