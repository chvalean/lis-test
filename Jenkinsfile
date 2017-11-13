pipeline {
  agent any
  stages {
    stage('echo hello') {
      steps {
        echo 'hello. this is a test'
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