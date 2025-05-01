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
               deploy adapters: [tomcat9(credentialsId: 'physictutors', path: '', url: 'http://13.220.6.192:8080/')], contextPath: 'webapp', war: '**/*.war'
            }
        }
    }

}
