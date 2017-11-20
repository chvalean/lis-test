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
  environment {
    test_env_var = 'hello'
  }
  post {
    always {
      junit(allowEmptyResults: true, testResults: '**/target/surefire-reports/TEST-*.xml, **/target/failsafe-reports/*.xml')
      
    }
    
  }
}