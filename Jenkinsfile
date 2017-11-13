pipeline {
  agent any
  stages {
    stage('echo hello') {
      parallel {
        stage('echo hello') {
          steps {
            echo 'hello. this is a test'
          }
        }
        stage('run script') {
          steps {
            sh 'bash \'./lis-test/WS2012R2/lisa/remote-scripts/ica/vcpu_verify_online.sh\''
          }
        }
      }
    }
    stage('print current dir') {
      steps {
        pwd(tmp: true)
      }
    }
    stage('build artifacts') {
      steps {
        archiveArtifacts(allowEmptyArchive: true, artifacts: 'test')
      }
    }
  }
}