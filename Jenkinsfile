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
                    script {
                        def scannerHome = tool name: 'SonarQubeScanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
                        withSonarQubeEnv('sonar-server') {
                            sh "${scannerHome}/bin/sonar-scanner"
                        }
                    }
                }
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                deploy adapters: [tomcat9(credentialsId: 'sonarserver1', path: '', url: 'http://18.234.200.5:8080/')], 
                       contextPath: 'webapp', 
                       war: 'physicstutors/target/physicstutors.war'
            }
        }
    }
}
