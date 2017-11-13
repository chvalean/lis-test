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
            dir(path: 'WS2012R2/lisa/remote-scripts/ica/') {
              sh '''touch /var/lib/jenkins/constants.sh
echo HYPERV_MODULES=(hyperv_keyboard hv_netvsc hid_hyperv hv_util hv_storvsc) > /var/lib/jenkins/constants.sh'''
              sh 'bash -xe \'./CORE_LISmodules_version.sh\''
            }
            
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