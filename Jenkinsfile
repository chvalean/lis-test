pipeline {
    agent any
    stages {
        stage('cleanup') {
            steps {
                sh 'mvn clean install'
            }
        }
        stage('Build') {
            steps {
                sh 'mvn test'
            }
        }
            post {
                success {
                    junit 'target/**/*.xml'
                }
            }
        }
    }
}
