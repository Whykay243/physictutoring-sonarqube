pipeline {
    agent any

    environment {
        // Set the SonarQube server name configured in Jenkins
        SONARQUBE_SERVER = 'sonar-server'  // Name of your SonarQube server in Jenkins global config
    }

    stages {
        stage('Test stage 1') {
            steps {
                sh 'cd physicstutors mvn test'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    // Run SonarQube analysis with Maven
                    withSonarQubeEnv(SONARQUBE_SERVER) {
                        sh 'cd physicstutors && mvn clean verify sonar:sonar'
                    }
                }
            }
        }

        stage('Quality Gate Check') {
            steps {
                script {
                    // Wait for SonarQube quality gate to pass
                    def qualityGate = waitForQualityGate()
                    if (qualityGate.status != 'OK') {
                        error "Quality Gate failed: ${qualityGate.status}"  // Fail the build if the quality gate is not OK
                    }
                }
            }
        }

        stage('Compile the Java Code stage 2') {
            steps {
                sh 'cd physicstutors && mvn clean package'
            }
        }

        stage('Deploy to Tomcat Web Server') {
            steps {
                deploy adapters: [tomcat9(credentialsId: 'sonarserver1', path: '', url: 'http://18.234.200.5:8080/')], contextPath: 'webapp', war: '**/*.war'
            }
        }
    }
}
