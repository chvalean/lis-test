pipeline {
  agent any
  stages {
    stage('echo hello') {
      parallel {
        stage('get env info') {
          steps {
            sh 'pwd'
            sh 'ls'
          }
        }
        stage('run bash script') {
          steps {
            sh 'bash -xe \'./WS2012R2/lisa/remote-scripts/ica/CORE_LISmodules_version.sh\''
          }
        }
      }
    }
  }
  post {
    always {
      junit 'summary.log'
      
    }
    
  }
}