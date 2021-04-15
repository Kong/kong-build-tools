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
    }
    options {
        timeout(time: 120, unit: 'MINUTES')
        parallelsAlwaysFailFast()
        retry(2)
    }
    stages {
        stage('Build Kong') {
            when {
                beforeAgent true
                anyOf {
                    buildingTag()
                    branch 'master'
                    changeRequest target: 'master'
                }
            }
            agent {
                node {
                    label 'bionic'
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
        stage('Tests Kong') {
            when {
                beforeAgent true
                anyOf {
                    buildingTag()
                    branch 'master'
                    changeRequest target: 'master'
                }
            }
            parallel {
                stage('dbless') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        TEST_DATABASE = "off"
                        TEST_SUITE = "dbless"
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        retry(2) {
                            sh 'make cleanup'
                            sh 'git clone --single-branch --branch $KONG_SOURCE https://github.com/Kong/kong.git $KONG_SOURCE_LOCATION'
                            sh 'make test-kong'
                        }
                    }
                }
                stage('postgres') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        TEST_DATABASE = 'postgres'
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        retry(2) {
                            sh 'make cleanup'
                            sh 'git clone --single-branch --branch $KONG_SOURCE https://github.com/Kong/kong.git $KONG_SOURCE_LOCATION'
                            sh 'make test-kong'
                        }
                    }
                }
                stage('postgres plugins') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        TEST_DATABASE = 'postgres'
                        TEST_SUITE = 'plugins'
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        retry(2) {
                            sh 'make cleanup'
                            sh 'git clone --single-branch --branch $KONG_SOURCE https://github.com/Kong/kong.git $KONG_SOURCE_LOCATION'
                            sh 'make test-kong'
                        }
                    }
                }
                stage('cassandra') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        TEST_DATABASE = 'cassandra'
                    }
                    steps {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true'
                        retry(2) {
                            sh 'make cleanup'
                            sh 'git clone --single-branch --branch $KONG_SOURCE https://github.com/Kong/kong.git $KONG_SOURCE_LOCATION'
                            sh 'make test-kong'
                        }
                    }
                }
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
                stage('Other Builds'){
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
                        sh 'export RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=1 PACKAGE_TYPE=rpm && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2 PACKAGE_TYPE=rpm && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_BASE=src RESTY_IMAGE_TAG=src PACKAGE_TYPE=src && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 PACKAGE_TYPE=apk CACHE=false UPDATE_CACHE=true DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` && make package-kong && make test && make cleanup'
                    }
                }
                stage('RedHat Builds'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        DEBUG = 0
                        PACKAGE_TYPE = "rpm"
                        RESTY_IMAGE_BASE = "rhel"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=7 && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=8 && make package-kong && make test && make cleanup'
                    }
                }
                stage('Centos Builds'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        DEBUG = 0
                        PACKAGE_TYPE = "rpm"
                        RESTY_IMAGE_BASE = "centos"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=8 && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=7 && make package-kong && make test && make cleanup'
                    }
                }
                stage('Debian Builds'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        DEBUG = 0
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "debian"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=stretch && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=jessie && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=buster && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=bullseye && make package-kong && make test && make cleanup'
                    }
                }
                stage('Ubuntu Builds'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    options {
                        retry(2)
                    }
                    environment {
                        DEBUG = 0
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "ubuntu"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        USER = 'jenkins-kbt'
                        AWS_ACCESS_KEY = credentials('AWS_ACCESS_KEY')
                        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export BUILDX=false RESTY_IMAGE_TAG=bionic && make package-kong && make test && make cleanup'
                        sh 'export CACHE=false UPDATE_CACHE=true RESTY_IMAGE_TAG=xenial DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` && make package-kong && make test'
                        sh 'export BUILDX=false RESTY_IMAGE_TAG=focal && make package-kong && make test && make cleanup'
                    }
                    post {
                        always {
                            sh 'make cleanup-build'
                        }
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
                GITHUB_TOKEN = credentials('GITHUB_TOKEN')
            }
            steps {
                sh 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash'
                sh '. ~/.nvm/nvm.sh && nvm install lts/*'
                sh '. ~/.nvm/nvm.sh && npx semantic-release@beta'
            }
        }
    }
}
