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
                        sh 'mvn sonar:sonar'
                    }
                }
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                deploy adapters: [
                    tomcat9(
                        credentialsId: 'tomcat', 
                        path: '', 
                        url: 'http://18.206.46.217:8080/'
                    )
                ], 
                contextPath: 'webapp', 
                war: 'physicstutors/target/physicstutors.war'
            }
        }
    }
}
