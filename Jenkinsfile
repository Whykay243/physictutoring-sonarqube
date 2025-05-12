pipeline {
  agent any

  // Global tools: pick the Maven installation configured in Jenkins
  tools {
    maven 'Maven 3.8.6'      // match the name in Jenkins Global Tool Configuration
    jdk    'Java 17'         // match the JDK installation in Jenkins
  }

  environment {
    // SonarQube server (configured under Manage Jenkins → Configure System)
    SONARQUBE_SERVER = 'sonar-server'
    // Tomcat deploy: credential ID stored in Jenkins Credentials
    TOMCAT_CRED_ID   = 'physicstutor'
    // Path inside Tomcat: empty means ROOT
    TOMCAT_PATH      = ''
    // CVE scanning or other flags
    MAVEN_OPTS       = "--add-opens java.base/java.lang=ALL-UNNAMED"
  }

  options {
    // Abort the build if it runs longer than 60 minutes
    timeout(time: 60, unit: 'MINUTES')
    // Always show timestamps in the console
    timestamps()
    // Retry flaky stages up to 2 times
    retry(2)
    // Keep only the last 10 build logs/artifacts
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  stages {
    stage('Checkout') {
      steps {
        // Perform a shallow clone for speed
        checkout([
          $class: 'GitSCM',
          userRemoteConfigs: [[ url: 'https://github.com/your-org/physicstutors.git' ]],
          branches: [[ name: '*/main' ]],
          extensions: [[$class: 'CloneOption', depth: 1, noTags: true, reference: '', shallow: true]]
        ])
      }
    }

    stage('Unit Tests') {
      steps {
        dir('physicstutors') {
          sh 'mvn test'
        }
      }
      post {
        always {
          junit '**/target/surefire-reports/*.xml'
        }
      }
    }

    stage('Static Analysis') {
      parallel {
        stage('SonarQube Analysis') {
          environment {
            // tell Maven which server to use
            SONAR_HOST_URL = credentials('sonar-server-url') 
          }
          steps {
            dir('physicstutors') {
              withSonarQubeEnv("${SONARQUBE_SERVER}") {
                sh 'mvn clean verify sonar:sonar'
              }
            }
          }
        }
        stage('Code Coverage') {
          steps {
            dir('physicstutors') {
              sh 'mvn jacoco:report'
            }
          }
          post {
            always {
              // Publish coverage report
              jacoco execPattern: '**/target/jacoco.exec',
                     classPattern: '**/target/classes',
                     sourcePattern: 'physicstutors/src/main/java',
                     exclusionPattern: '**/test/**'
            }
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 2, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Build & Package') {
      steps {
        dir('physicstutors') {
          sh 'mvn clean package -DskipTests'
        }
      }
      post {
        success {
          archiveArtifacts artifacts: 'physicstutors/target/*.war', fingerprint: true
        }
      }
    }

    stage('Deploy to Tomcat') {
      when {
        expression { currentBuild.currentResult == 'SUCCESS' }
      }
      steps {
        deploy adapters: [
          tomcat9(
            credentialsId: "${TOMCAT_CRED_ID}",
            url: 'http://13.220.46.52:8080',
            path: "${TOMCAT_PATH}"
          )
        ], contextPath: "${TOMCAT_PATH}", war: 'physicstutors/target/*.war'
      }
    }
  }

  post {
    success {
      echo "🎉 Build and deployment succeeded!"
    }
    unstable {
      echo "⚠️ Build is unstable. Check test or quality reports."
    }
    failure {
      echo "❌ Build failed. Please investigate."
    }
    always {
      // Clean up workspace to save disk
      cleanWs()
    }
  }
}
