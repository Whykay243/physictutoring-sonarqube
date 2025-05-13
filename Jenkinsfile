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
                        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                            sh 'mvn sonar:sonar -Dsonar.login=$SONAR_TOKEN'
                        }
                    }
                }
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                deploy adapters: [
                    tomcat9(
                        credentialsId: 'tomcatmanager', 
                        path: '', 
                        url: 'http://52.55.108.24:8080'
                    )
                ], 
                contextPath: 'webapp', 
                war: 'physicstutors/target/physicstutors.war'
            }
        }
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> 6b9d12d (working and updated files)
