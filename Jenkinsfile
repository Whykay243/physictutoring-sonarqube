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
     
        
        stage('Deploy to Tomcat Web Server') {
            steps {
               deploy adapters: [tomcat9(credentialsId: 'physictutors', path: '', url: 'http://13.220.6.192:8080/')], contextPath: 'webapp', war: '**/*.war'
            }
        }
    }
}
