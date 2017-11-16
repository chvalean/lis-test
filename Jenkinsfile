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
        nunit(testResultsPattern: 'test*.nunit')
      }
    }
  }
  post {
    always {
      junit(allowEmptyResults: true, testResults: '**/target/surefire-reports/TEST-*.xml, **/target/failsafe-reports/*.xml')
      
    }
    
  }
}