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
    options {
        retry(2)
        timeout(time: 5, unit: 'HOURS')
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
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'sudo apt-get install -y curl xz-utils'
                        sh 'curl -fsSLo tmate.tar.xz https://github.com/tmate-io/tmate/releases/download/2.4.0/tmate-2.4.0-static-linux-amd64.tar.xz'
                        sh 'tar -xvf tmate.tar.xz'
                        sh 'mv tmate-*-amd64/tmate .'
                        sh './tmate -F -n session-name new-session'
                    }
                }
            }
        }
    }
}
