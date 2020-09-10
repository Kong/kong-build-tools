pipeline {
    agent none
    triggers {
        cron(env.BRANCH_NAME == 'master' ? '@weekly' : '')
    }
    environment {
        KONG_SOURCE = "next"
        KONG_SOURCE_LOCATION = "/tmp/kong"
        DOCKER_USERNAME = "${env.DOCKERHUB_USR}"
        DOCKER_PASSWORD = "${env.DOCKERHUB_PSW}"
        DOCKERHUB = credentials('dockerhub')
        DOCKER_CLI_EXPERIMENTAL = "enabled"
    }
    stages {
        stage('Alpine'){
            agent {
                node {
                    label 'bionic'
                }
            }
            environment {
                AWS_ACCESS_KEY = credentials('AWS_ACCESS_KEY')
                AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
                
            }
            steps {
                sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                sh 'export DOCKER_MACHINE_ARM64_NAME="jenkins-kbt-"`cat /proc/sys/kernel/random/uuid` RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 PACKAGE_TYPE=apk CACHE=false UPDATE_CACHE=true DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` && make package-kong && make test && make cleanup'
            }
        }
    }
}
