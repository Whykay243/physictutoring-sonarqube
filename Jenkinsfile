pipeline {
    agent any
    
    environment {
        MAVEN_OPTS = "--add-opens java.base/java.lang=ALL-UNNAMED"
    }

    stages {
        stage('Test') {
            steps {
                sh 'cd physicstutors && mvn test'
            }
        }

        stage('Build & Compile') {
            steps {
                sh 'cd physicstutors && mvn clean package'
            }
        }

        stage('Quality Code Scan Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh 'mvn -f physicstutors/pom.xml sonar:sonar'
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

        stage('Deploy to Tomcat Web Server') {
            steps {
                deploy adapters: [
                    tomcat9(
                        credentialsId: 'physicstutor', 
                        path: '', 
                        url: 'http://13.220.46.52:8080/'
                    )
                ], contextPath: 'webapp', war: '**/*.war'
            }
        }
    }
}
