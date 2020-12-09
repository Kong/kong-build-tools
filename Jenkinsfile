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
        stage('Test Builds - ARM64') {
            when {
                beforeAgent true
                anyOf {
                    buildingTag()
                    branch 'master'
                    changeRequest target: 'master'
                }
            }
            parallel {
                stage('Alpine'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        ARCHITECTURE = "aarch64"
                    }
                    steps {
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'docker run --rm --privileged multiarch/qemu-user-static --reset -p yes'
                        sh 'docker run --rm -t arm64v8/ubuntu uname -m'
                        sh 'export PACKAGE_TYPE=apk RESTY_IMAGE_TAG=3.12 && make package-kong && make test && make cleanup'
                    }
                }
                stage('Debian Builds'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        ARCHITECTURE = "aarch64"
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "debian"
                    }
                    steps {
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'docker run --rm --privileged multiarch/qemu-user-static --reset -p yes'
                        sh 'docker run --rm -t arm64v8/ubuntu uname -m'
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
                        ARCHITECTURE = "aarch64"
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "ubuntu"
                    }
                    steps {
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'docker run --rm --privileged multiarch/qemu-user-static --reset -p yes'
                        sh 'docker run --rm -t arm64v8/ubuntu uname -m'
                        sh 'RESTY_IMAGE_TAG=bionic && make package-kong && make test && make cleanup'
                        sh 'RESTY_IMAGE_TAG=xenial && make package-kong && make test && make cleanup'
                        sh 'RESTY_IMAGE_TAG=focal && make package-kong && make test && make cleanup'
                    }
                }
            }
        }
        stage('Test Builds - AMD64') {
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
                    steps {
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=1 PACKAGE_TYPE=rpm && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2 PACKAGE_TYPE=rpm && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_BASE=src RESTY_IMAGE_TAG=src PACKAGE_TYPE=src && make package-kong && make test && make cleanup'
                        sh 'export PACKAGE_TYPE=apk RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 && make package-kong && make test && make cleanup'
                    }
                }
                stage('RedHat Builds'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "rpm"
                        RESTY_IMAGE_BASE = "rhel"
                    }
                    steps {
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
                        PACKAGE_TYPE = "rpm"
                        RESTY_IMAGE_BASE = "centos"
                    }
                    steps {
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
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "debian"
                    }
                    steps {
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
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "ubuntu"
                    }
                    steps {
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'RESTY_IMAGE_TAG=bionic && make package-kong && make test && make cleanup'
                        sh 'RESTY_IMAGE_TAG=xenial && make package-kong && make test && make cleanup'
                        sh 'RESTY_IMAGE_TAG=focal && make package-kong && make test && make cleanup'
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
