pipeline {
    agent any

    stages {
        stage('Test') {
            steps {
                dir('physicstutors') {
                    sh 'mvn test'
                }
            }
        }

        stage('Build') {
            steps {
                dir('physicstutors') {
                    sh 'mvn clean package'
                }
            }
        }

        stage('SonarQube Analysis') {
    steps {
        dir('physicstutors') {
            withSonarQubeEnv('sonar-server') {
                // Pass the SonarQube token directly in the Maven command
                sh 'mvn sonar:sonar -Dsonar.login=tomcatuser'
            }
        }
    }
}

        stage('Deploy to Tomcat') {
            steps {
                deploy adapters: [
                    tomcat9(
                        credentialsId: 'tomcatcredentials', 
                        path: '', 
                        url: 'http://http://44.211.244.192:8080/'
                    )
                ], 
                contextPath: 'webapp', 
                war: 'physicstutors/target/physicstutors.war'
            }
        }
    }
}
