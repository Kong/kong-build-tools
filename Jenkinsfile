pipeline {
    agent none
    triggers {
        cron(env.BRANCH_NAME == 'master' ? '@weekly' : '')
    }
    environment {
        KONG_SOURCE = "master"
        KONG_SOURCE_LOCATION = "/tmp/kong"
        DOCKER_USERNAME = "${env.DOCKERHUB_USR}"
        DOCKER_PASSWORD = "${env.DOCKERHUB_PSW}"
        DOCKERHUB = credentials('dockerhub')
        DOCKER_CLI_EXPERIMENTAL = "enabled"
        DEBUG = 0
    }
    stages {
        stage('Enteprise Test Builds') {
            environment {
                DOCKER_REPOSITORY = "kong/kong-build-tools-private"
                GITHUB_TOKEN = credentials('github_bot_access_token')
                KONG_SOURCE = "master"
                PULP = credentials('PULP')
                PULP_PASSWORD = "${env.PULP_PSW}"
                PULP_USERNAME = "${env.PULP_USR}"
            }
            when {
                beforeAgent true
                anyOf {
                    buildingTag()
                    branch 'master'
                    changeRequest target: 'master'
                }
            }
            parallel {
                stage('Kong Enterprise RPM'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        PACKAGE_TYPE = "rpm"
                        PRIVATE_KEY_FILE = credentials('kong.private.gpg-key.asc')
                        PRIVATE_KEY_PASSPHRASE = credentials('kong.private.gpg-key.asc.password')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'cp $PRIVATE_KEY_FILE kong.private.gpg-key.asc'
                        sh 'make RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2   package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=centos      RESTY_IMAGE_TAG=7   package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=7.9 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=8.6 package-kong test cleanup'
                    }
                }
            }
        }
    }
}
