pipeline {
    agent any

    environment {
        // Define environment variables if necessary
        MAVEN_HOME = '/usr/share/maven'
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        SONARQUBE_URL = 'http://<your-sonarqube-ip>:9000'
        TOMCAT_HOST = 'http://<your-tomcat-ip>:8080'
        TOMCAT_USER = 'admin'
        TOMCAT_PASS = 'admin' // Change to your actual Tomcat credentials
    }

    stages {
        stage('Build') {
            steps {
                echo 'Building with Maven...'
                sh "'${MAVEN_HOME}/bin/mvn' clean install"
            }
        }

        stage('SonarQube Scan') {
            steps {
                echo 'Running SonarQube scan...'
                script {
                    // Ensure SonarQube is configured as a global tool
                    def scannerHome = tool name: 'SonarQube Scanner', type: 'ToolType'
                    sh "'${scannerHome}/bin/sonar-scanner' -Dsonar.projectKey=my-project -Dsonar.sources=src"
                }
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                echo 'Deploying to Tomcat...'
                script {
                    // Here you might deploy a WAR file
                    sh "curl -u ${TOMCAT_USER}:${TOMCAT_PASS} -T target/my-webapp.war ${TOMCAT_HOST}/manager/text/deploy?path=/my-webapp&update=true"
                }
            }
        }
    }

    post {
        always {
            echo 'Cleaning up...'
            // Clean up any temporary files if necessary
        }
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}
