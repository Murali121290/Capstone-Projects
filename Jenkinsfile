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
          def scannerHome = tool 'SonarScanner'    // must match Global Tool Config
          withSonarQubeEnv('SonarQube') {        // must match Configure System → SonarQube server name
            sh """
              set -e
              "${scannerHome}/bin/sonar-scanner"
            """
          }
        }
      }
    }

    stage('Quality Gate') {
      catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
        timeout(time: 10, unit: 'MINUTES') {
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
          # Export environment variables for envsubst
          export APP_NAME=${APP_NAME}
          export IMAGE_TAG=${APP_NAME}:${IMAGE_TAG}

          # Generate final manifests from templates
          envsubst < k8s/deployment-template.yaml > k8s/deployment.yaml
          envsubst < k8s/service-template.yaml > k8s/service.yaml

          # Apply manifests
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        """
      }
    }

    stage('Smoke Test') {
      steps {
        sh """
          # Wait for deployment rollout
          kubectl rollout status deployment/${APP_NAME} --timeout=120s

          NODE_IP=\$(minikube ip)
          NODE_PORT=\$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
          URL="http://\$NODE_IP:\$NODE_PORT/"

          echo "Testing app at \$URL"

          MAX_RETRIES=5
          RETRY_COUNT=0
          until curl -f \$URL; do
            RETRY_COUNT=\$((RETRY_COUNT+1))
            if [ \$RETRY_COUNT -ge \$MAX_RETRIES ]; then
              echo "App not reachable after \$MAX_RETRIES attempts"
              exit 1
            fi
            echo "Retry \$RETRY_COUNT of \$MAX_RETRIES..."
            sleep 5
          done

          echo "App is reachable!"
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
