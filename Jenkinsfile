pipeline {
  agent any
  triggers { githubPush() }
  options { timestamps(); disableConcurrentBuilds() }

  environment {
    APP_NAME  = 'myapp'
    IMAGE_TAG = "${env.BUILD_NUMBER ?: 'latest'}"
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
        script {
          catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
            timeout(time: 30, unit: 'MINUTES') {
              echo "Waiting for SonarQube Quality Gate..."
              def qg = null
              while (qg == null || qg.status == 'IN_PROGRESS') {
                sleep 15
                qg = waitForQualityGate abortPipeline: false
                if (qg == null) {
                  echo "SonarQube analysis not ready yet..."
                } else if (qg.status == 'OK') {
                  echo "Quality Gate passed!"
                } else if (qg.status == 'ERROR') {
                  error "Quality Gate failed!"
                } else {
                  echo "SonarQube status: ${qg.status} (still in progress...)"
                }
              }
            }
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          sh "docker --version"  // sanity check
          sh "docker build -t ${APP_NAME}:${IMAGE_TAG} ."
        }
      }
    }

    stage('Load Image into Minikube') {
      steps {
        sh "minikube image load ${APP_NAME}:${IMAGE_TAG} --profile=minikube"
      }
    }

    stage('Deploy to Minikube') {
      steps {
        sh """
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
          NODE_IP=\$(minikube ip)
          NODE_PORT=\$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
          URL="http://\$NODE_IP:\$NODE_PORT/"
          echo "Testing app at \$URL"
          curl -f \$URL
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
