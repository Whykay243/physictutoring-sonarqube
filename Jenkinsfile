pipeline {
    agent any
    tools {
        maven 'Maven3'    // Make sure a Maven installation named 'Maven3' is configured in Jenkins
    }
    stages {
        stage('Test') {
            steps {
                // Run tests in the project directory
                dir('physicstutors') {
                    sh 'mvn test'
                }
            }
        }
        stage('Build & Compile') {
            steps {
                // Package the WAR, skipping tests since they were already run
                dir('physicstutors') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }
        stage('SonarQube Analysis') {
            steps {
                // Perform SonarQube analysis; this must be before waiting for Quality Gate
                dir('physicstutors') {
                    withSonarQubeEnv('sonar-server') {
                        // Run the Sonar scanner via Maven
                        sh 'mvn sonar:sonar -DskipTests'
                    }
                }
            }
        }
        stage('Quality Gate') {
            steps {
                // Wait for SonarQube quality gate status, with timeout to avoid indefinite blocking
                script {
                    timeout(time: 15, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline aborted due to Quality Gate failure: ${qg.status}"
                        }
                    }
                }
            }
        }
        stage('Deploy to Tomcat') {
            steps {
                // Deploy the built WAR to Tomcat (adjust the path as needed)
                sh 'cp physicstutors/target/*.war /opt/tomcat/webapps/'
            }
        }
    }
    post {
        always {
            // Publish test results
            junit 'physicstutors/target/surefire-reports/*.xml'
        }
    }
}
