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
        stage('get env info') {
          steps {
            sh 'pwd'
            sh 'ls'
          }
        }
        stage('run bash script') {
          steps {
            try {
            sh 'bash \'./WS2012R2/lisa/remote-scripts/ica/vcpu_verify_online.sh\''
            } catch (err) {
              echo "test failed to execute"
            }
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
