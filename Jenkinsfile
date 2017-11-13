pipeline {
  agent any
  stages {
    stage('test run') {
      parallel {
        stage('get env info') {
          steps {
            sh 'pwd'
            sh 'ls'
          }
        }
        stage('run bash script') {
          steps {
            dir(path: 'WS2012R2/lisa/remote-scripts/ica/') {
              sh '''touch /var/lib/jenkins/constants.sh
        echo "vCPU=1" > /var/lib/jenkins/constants.sh'''
              sh 'bash -xe \'./vcpu_verify_online.sh\''
            }
            
          }
        }
      }
    }
    stage('report') {
      parallel {
        stage('report') {
          steps {
            junit(allowEmptyResults: true, testResults: '/var/lib/jenkins/summary.xml')
          }
        }
        stage('artifacts archive') {
          steps {
            archiveArtifacts(artifacts: '/var/lib/jenkins/summary.log', allowEmptyArchive: true)
          }
        }
      }
    }
  }
}