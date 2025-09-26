pipeline {
  agent any
  triggers { githubPush() }
  options { timestamps(); disableConcurrentBuilds() }

  environment {
    APP_NAME   = 'myapp'
    IMAGE_TAG  = "${env.BUILD_NUMBER ?: 'latest'}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('SonarQube') {   // must match Jenkins SonarQube config name
          script {
            def scannerHome = tool 'SonarScanner'  // must match Jenkins Global Tool Config
            sh """
              set -e
              "${scannerHome}/bin/sonar-scanner" \
                -Dsonar.projectKey=${APP_NAME} \
                -Dsonar.sources=. \
                -Dsonar.sourceEncoding=UTF-8
            """
          }
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
          # Replace placeholder image in deployment manifest
          sed -i 's#IMAGE_PLACEHOLDER#${APP_NAME}:${IMAGE_TAG}#g' k8s/deployment.yaml

          # Apply manifests
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        """
      }
    }

    stage('Smoke Test') {
      steps {
        sh '''
          kubectl rollout status deployment/myweb --timeout=120s
          NODE_IP=$(minikube ip)
          NODE_PORT=$(kubectl get svc myweb -o=jsonpath='{.spec.ports[0].nodePort}')
          echo "Testing app at http://$NODE_IP:$NODE_PORT/"
          sleep 5
          curl -f http://$NODE_IP:$NODE_PORT/ || (echo "App not reachable" && exit 1)
        '''
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
