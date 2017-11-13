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
            sh 'pwd'
            sh 'ls'
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
