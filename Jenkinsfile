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
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'cp $PRIVATE_KEY_FILE kong.private.gpg-key.asc'
                        sh 'make RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2022 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=centos      RESTY_IMAGE_TAG=7    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=7.9  package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=8.6  package-kong test cleanup'
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
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} git@github.com:Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=src    RESTY_IMAGE_TAG=src  PACKAGE_TYPE=src package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 PACKAGE_TYPE=apk DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` package-kong test cleanup'
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
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} git@github.com:Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=10    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=11    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=18.04 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=20.04 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=22.04 package-kong test cleanup'
                    }
                }
                stage('Kong Enterprise BoringSSL') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                        DOCKER_REPOSITORY = "kong/kong-build-tools-private"
                        KONG_PACKAGE_NAME = "kong-enterprise-edition-fips"
                    }
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --recursive --single-branch --branch ${KONG_SOURCE} git@github.com:Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'make PACKAGE_TYPE=deb RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=20.04 SSL_PROVIDER=boringssl package-kong test cleanup'
                        sh 'make PACKAGE_TYPE=deb RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=22.04 SSL_PROVIDER=boringssl package-kong test cleanup'
                    }
                }
                stage('Kong EE 3.0.0.0'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        KONG_SOURCE = "3.0.0.0"
                    }
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong-ee.git ${KONG_SOURCE_LOCATION}'
                        sh 'make PACKAGE_TYPE=deb RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=10 package-kong test cleanup'
                        sh 'make PACKAGE_TYPE=apk RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 package-kong test cleanup'
                        sh 'make PACKAGE_TYPE=rpm RESTY_IMAGE_BASE=rhel RESTY_IMAGE_TAG=8.6 package-kong test cleanup'

                    }
                }
            }
        }
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
                stage('Kong OSS 2.8.0'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        KONG_SOURCE = "2.8.0"
                    }
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'make PACKAGE_TYPE=deb RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=10 package-kong test cleanup'
                        sh 'make PACKAGE_TYPE=apk RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 package-kong test cleanup'
                        sh 'make PACKAGE_TYPE=rpm RESTY_IMAGE_BASE=rhel RESTY_IMAGE_TAG=8.6 package-kong test cleanup'

                    }
                }
                stage('Kong OSS RPM'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        PACKAGE_TYPE = "rpm"
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                        PRIVATE_KEY_FILE = credentials('kong.private.gpg-key.asc')
                        PRIVATE_KEY_PASSPHRASE = credentials('kong.private.gpg-key.asc.password')
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
                        sh 'cp $PRIVATE_KEY_FILE kong.private.gpg-key.asc'
                        sh 'make RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2   package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2022 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=centos      RESTY_IMAGE_TAG=7   package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=rhel        RESTY_IMAGE_TAG=7.9 package-kong test cleanup'
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
                        GITHUB_SSH_KEY = credentials('github_bot_ssh_key')
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    options {
                        retry(2)
                        timeout(time: 2, unit: 'HOURS')
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        sh 'while /bin/bash -c "ps aux | grep [a]pt-get"; do sleep 5; done'
                        sh 'curl https://raw.githubusercontent.com/Kong/kong/master/scripts/setup-ci.sh | bash'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=10    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=debian RESTY_IMAGE_TAG=11    package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=18.04 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=20.04 package-kong test cleanup'
                        sh 'make RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=22.04 package-kong test cleanup'
                    }
                }
            }
        }
    }
}
