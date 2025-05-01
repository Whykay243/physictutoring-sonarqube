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
     
        
        stage('Deploy to Tomcat Web Server') {
            steps {
               deploy adapters: [tomcat9(credentialsId: 'physicstutors', path: '', url: 'http://44.193.80.160:8080/')], contextPath: 'webapp', war: '**/*.war'
            }
        }
    }

}
