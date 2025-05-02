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
        timeout(time: 5, unit: 'MINUTES') {
            withSonarQubeEnv('sonar-server') {
                sh '''
                  export JAVA_OPTS="-Dorg.jenkinsci.plugins.durabletask.BourneShellScript.HEARTBEAT_CHECK_INTERVAL=86400"
                  mvn -f physicstutors/pom.xml sonar:sonar -Dsonar.verbose=true
                '''
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
