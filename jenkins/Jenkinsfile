pipeline {
  agent any

  environment {
    APP_NAME = 'myapp'
    IMAGE_TAG = "${env.BUILD_ID ?: 'local'}"
    SONARQUBE_SERVER = 'SonarQube'   // name configured in Jenkins -> Configure System -> SonarQube servers
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Code Quality (SonarQube)') {
      steps {
        // Use SonarScanner CLI docker image to run scan or use installed scanner
        // This block assumes you have 'withSonarQubeEnv' available (Sonar plugin installed)
        withSonarQubeEnv(SONARQUBE_SERVER) {
          sh """
            # run sonar scanner; adjust for your project (maven/gradle/sonar-scanner)
            # If using a simple python app, use sonar-scanner CLI with properties:
            docker run --rm \
              -v \$(pwd):/usr/src/app \
              -v /tmp:/tmp \
              sonarsource/sonar-scanner-cli \
              -Dsonar.projectKey=${APP_NAME} \
              -Dsonar.sources=. \
              -Dsonar.host.url=${env.SONAR_HOST_URL} \
              -Dsonar.login=${env.SONAR_AUTH_TOKEN}
          """
        }
      }
    }

    stage("Wait for SonarQube Quality Gate") {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          // This step requires SonarQube plugin and the previous stage published analysis
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Build Docker image') {
      steps {
        sh """
          # Build on host docker (jenkins container has access to /var/run/docker.sock)
          docker build -t ${APP_NAME}:${IMAGE_TAG} .
        """
      }
    }

    stage('Load image into Minikube') {
      steps {
        sh """
          # Use minikube's image load so the cluster can use the built image
          # Jenkins container has /usr/local/bin/minikube mounted; minikube config is inherited
          minikube image load ${APP_NAME}:${IMAGE_TAG} --profile=minikube
        """
      }
    }

    stage('Deploy to Minikube') {
      steps {
        sh """
          # Update k8s manifest with tag and apply
          sed -i 's#IMAGE_PLACEHOLDER#${APP_NAME}:${IMAGE_TAG}#g' k8s/deployment.yaml
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        """
      }
    }

    stage('Smoke Test') {
      steps {
        sh """
          # Wait for pod to be ready then curl the service via nodeport
          kubectl rollout status deployment/${APP_NAME} --timeout=120s
          NODE_PORT=$(kubectl get svc ${APP_NAME} -o=jsonpath='{.spec.ports[0].nodePort}')
          NODE_IP=$(minikube ip)
          echo "Waiting for app at http://${NODE_IP}:${NODE_PORT}/"
          sleep 5
          curl -f http://${NODE_IP}:${NODE_PORT}/ || (kubectl get pods -o wide; kubectl describe svc ${APP_NAME}; exit 1)
        """
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true
      junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
    }
  }
}
