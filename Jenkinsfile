pipeline {
    agent any
    triggers { 
        pollSCM('H/2 * * * *')  // Poll every 2 minutes instead of githubPush for testing
    }
    options { 
        timestamps()
        disableConcurrentBuilds() 
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        APP_NAME         = 'myapp'
        IMAGE_TAG        = "${env.BUILD_NUMBER ?: 'latest'}"
        MINIKUBE_PROFILE = 'minikube'
    }

    stages {
        stage('Verify Environment') {
            steps {
                sh '''
                    echo "=== Environment Verification ==="
                    echo "Jenkins workspace: ${WORKSPACE}"
                    echo "Current directory: $(pwd)"
                    echo "User: $(whoami)"
                    echo "Groups: $(id)"
                    
                    echo "=== Tool Versions ==="
                    docker --version
                    minikube version
                    kubectl version --client
                    java -version
                    
                    echo "=== Docker Access Test ==="
                    docker images | head -5
                    
                    echo "=== Minikube Status ==="
                    minikube status --profile=${MINIKUBE_PROFILE}
                    
                    echo "=== Kubernetes Access ==="
                    kubectl cluster-info
                    kubectl get nodes
                    kubectl get pods -A
                '''
            }
        }

        stage('Checkout Code') {
            steps {
                checkout scm
                sh '''
                    echo "=== Repository Contents ==="
                    ls -la
                    echo "=== K8s Manifests ==="
                    ls -la k8s/ || echo "No k8s directory"
                '''
            }
        }

        stage('Setup Minikube Docker Environment') {
            steps {
                sh '''
                    echo "=== Setting up Minikube Docker Environment ==="
                    eval $(minikube docker-env --profile=${MINIKUBE_PROFILE})
                    echo "DOCKER_HOST: $DOCKER_HOST"
                    echo "Now using Minikube's Docker daemon for builds"
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    // Install SonarScanner if not already configured
                    def scannerHome = tool name: 'SonarScanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=myapp \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000 \
                            -Dsonar.login=admin \
                            -Dsonar.password=admin
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image in Minikube') {
            steps {
                sh """
                    echo "=== Building Docker Image ==="
                    eval $(minikube docker-env --profile=${MINIKUBE_PROFILE})
                    docker build -t ${APP_NAME}:${IMAGE_TAG} .
                    echo "=== Verifying Image ==="
                    docker images | grep ${APP_NAME}
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    echo "=== Deploying to Minikube ==="
                    # Update deployment with new image
                    kubectl set image deployment/${APP_NAME} ${APP_NAME}=${APP_NAME}:${IMAGE_TAG} --record || true
                    
                    # Apply manifests if they exist
                    if [ -f k8s/deployment.yaml ]; then
                        kubectl apply -f k8s/deployment.yaml
                    fi
                    if [ -f k8s/service.yaml ]; then
                        kubectl apply -f k8s/service.yaml
                    fi
                    
                    # Wait for rollout
                    kubectl rollout status deployment/${APP_NAME} --timeout=300s
                    
                    echo "=== Current Deployment Status ==="
                    kubectl get deployments,svc,pods
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh """
                    echo "=== Running Smoke Tests ==="
                    NODE_IP=$(minikube ip --profile=${MINIKUBE_PROFILE})
                    NODE_PORT=$(kubectl get svc ${APP_NAME} -o jsonpath='{.spec.ports[0].nodePort}')
                    
                    if [ -z "$NODE_PORT" ]; then
                        echo "Service not found, checking for alternative service names..."
                        kubectl get svc
                        # Try to get any service with NodePort
                        NODE_PORT=$(kubectl get svc -o jsonpath='{.items[?(@.spec.ports[0].nodePort)].spec.ports[0].nodePort}' | cut -d' ' -f1)
                    fi
                    
                    if [ ! -z "$NODE_PORT" ] && [ "$NODE_PORT" != "null" ]; then
                        URL="http://$NODE_IP:$NODE_PORT"
                        echo "Testing application at: $URL"
                        
                        for i in {1..10}; do
                            echo "Attempt $i/10: Testing $URL"
                            if curl -f -s -o /dev/null -w "HTTP Code: %{http_code}\n" "$URL"; then
                                echo "✅ Smoke test PASSED - Application is responding"
                                break
                            else
                                echo "⏳ Application not ready, retrying in 5 seconds..."
                                sleep 5
                            fi
                            
                            if [ $i -eq 10 ]; then
                                echo "❌ Smoke test FAILED - Application did not become ready"
                                exit 1
                            fi
                        done
                    else
                        echo "⚠️  No NodePort service found for smoke testing"
                        echo "Current services:"
                        kubectl get svc
                    fi
                """
            }
        }
    }

    post {
        always {
            echo "=== Pipeline Execution Complete ==="
            sh """
                echo "Final status:"
                kubectl get pods,svc,deploy
            """
            cleanWs()
        }
        success {
            echo "✅ Pipeline executed successfully!"
            emailext (
                subject: "SUCCESS: Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: "The pipeline executed successfully. Check details at: ${env.BUILD_URL}",
                to: "admin@example.com"
            )
        }
        failure {
            echo "❌ Pipeline failed!"
            sh """
                echo "=== Debugging Info ==="
                kubectl describe pods -l app=${APP_NAME} || true
                kubectl logs -l app=${APP_NAME} --tail=50 || true
            """
            emailext (
                subject: "FAILED: Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: "The pipeline failed. Check details at: ${env.BUILD_URL}",
                to: "admin@example.com"
            )
        }
    }
}
