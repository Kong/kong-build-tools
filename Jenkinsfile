pipeline {
    agent none
    triggers {
        cron(env.BRANCH_NAME == 'master' ? '@weekly' : '')
    }
    environment {
        KONG_SOURCE = "3.0.0"
        KONG_SOURCE_LOCATION = "/tmp/kong"
        DOCKER_USERNAME = "${env.DOCKERHUB_USR}"
        DOCKER_PASSWORD = "${env.DOCKERHUB_PSW}"
        DOCKERHUB = credentials('dockerhub')
        DOCKER_CLI_EXPERIMENTAL = "enabled"
        DEBUG = 0
    }
    stages {
        stage('OSS Test Builds') {
            when {
                beforeAgent true
                anyOf {
                    buildingTag()
                    branch 'master'
                    changeRequest target: 'master'
                }
            }
            parallel {
                stage('Kong OSS src & Alpine'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        AWS_ACCESS_KEY = "instance-profile"
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 PACKAGE_TYPE=apk DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` package-kong test cleanup'
                    }
                }
            }
        }
    }
}
