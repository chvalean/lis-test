pipeline {
  agent any
  stages {
    stage('Init') {
      steps {
        echo 'Hello from the blue ocean!'
        bat '''
          path
          set
        '''
      }
    }
    stage('Build') {
      steps {        
          bat 'mvn clean install'
          junit(allowEmptyResults: true, testResults: 'target/surefire-reports/**/*.xml')
      }
      post {
        success {
          junit '**/target/surefire-reports/**/*.xml'
          
        }
      }
    }
  }
}
