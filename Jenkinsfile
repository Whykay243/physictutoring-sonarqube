pipeline {
    agent any

    stages {
        stage('Test stage 1') {
            steps {
                sh 'cd physicstutors mvn test'
            }
        }
        stage('Complie the Java Code stage 2') {
            steps {
                sh 'cd physicstutors && mvn clean package'
            }
        }

        stage('SonarQube Code Quality Scan') {
            steps {
                dir('physicstutors') {
                    withSonarQubeEnv('sonarserver') {
                         sh 'mvn -f physicstutors/pom.xml sonar:sonar'
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
        
        stage('Deploy to Tomcat Web Server') {
            steps {
               deploy adapters: [tomcat9(credentialsId: 'physicstutors', path: '', url: 'http://44.193.80.160:8080/')], contextPath: 'webapp', war: '**/*.war'
            }
        }
    }

}
