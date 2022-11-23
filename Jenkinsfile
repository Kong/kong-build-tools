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
        stage('OSS Test Builds') {
            when {
                beforeAgent true
                anyOf {
                    branch 'chore/tmate'
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
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
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
