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
        timeout(time: 120, unit: 'MINUTES')
        parallelsAlwaysFailFast()
        retry(2)
    }
    stages {
        stage('Build Kong Test Container') {
            when {
                beforeAgent true
                anyOf {
                    buildingTag()
                    branch 'master'
                    changeRequest target: 'master'
                }
            }
<<<<<<< HEAD
            agent {
                node {
                    label 'bionic'
=======
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
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=centos      RESTY_IMAGE_TAG=7 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rockylinux  RESTY_IMAGE_TAG=8 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=7 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=8 package-kong test cleanup'
                    }
                }
                stage('Kong Enterprise src & Alpine'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} git@github.com:Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=src    RESTY_IMAGE_TAG=src  PACKAGE_TYPE=src package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3.10 PACKAGE_TYPE=apk CACHE=false UPDATE_CACHE=true DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` package-kong test cleanup'
                    }
                }
                stage('Kong Enterprise DEB') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "deb"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} git@github.com:Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=9     package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=10    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=11    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=18.04 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=20.04 package-kong test cleanup'
                    }
>>>>>>> b201872 (chore(xenial) 👋)
                }
            }
            steps {
                sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                sh 'make cleanup'
                sh 'rm -rf $KONG_SOURCE_LOCATION || true'
                sh 'git clone --single-branch --branch $KONG_SOURCE https://github.com/Kong/kong.git $KONG_SOURCE_LOCATION'
                sh 'make kong-test-container'
            }
        }
        stage('Test Builds') {
            when {
                beforeAgent true
                anyOf {
                    buildingTag()
                    branch 'master'
                    changeRequest target: 'master'
                }
            }
            parallel {
                stage('Kong OSS RPM'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        PACKAGE_TYPE = "rpm"
                        PRIVATE_KEY_FILE = credentials('kong.private.gpg-key.asc')
                        PRIVATE_KEY_PASSPHRASE = credentials('kong.private.gpg-key.asc.password')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'cp $PRIVATE_KEY_FILE kong.private.gpg-key.asc'
                        sh 'make RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2   package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=8.6 package-kong test cleanup'
                    }
                }
                stage('Kong OSS src & Alpine'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        AWS_ACCESS_KEY = "instance-profile"
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=src    RESTY_IMAGE_TAG=src  PACKAGE_TYPE=src package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 PACKAGE_TYPE=apk DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` package-kong test cleanup'
                    }
                }
                stage('Kong OSS DEB') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "deb"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=10    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=11    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=18.04 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=20.04 package-kong test cleanup'
                    }
                }
            }
        }
        stage('Release') {
            agent {
                node {
                    label 'bionic'
                }
            }
            when {
                triggeredBy 'TimerTrigger'
            }
            environment {
                GITHUB_TOKEN = credentials('github_bot_access_token')
            }
            steps {
                sh 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash'
                sh '. ~/.nvm/nvm.sh && nvm install lts/*'
                sh '. ~/.nvm/nvm.sh && npx semantic-release@beta'
            }
        }
    }
}
