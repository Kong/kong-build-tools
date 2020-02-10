pipeline {
    agent none
    environment {
        KONG_SOURCE = "next"
        KONG_SOURCE_LOCATION = "/tmp/kong"
        DOCKER_USERNAME = "${env.DOCKERHUB_USR}"
        DOCKER_PASSWORD = "${env.DOCKERHUB_PSW}"
        DOCKERHUB = credentials('dockerhub')
    }
    stages {
        stage('Test Builds') {
            parallel {
                stage('RedHat Builds'){
                    agent {
                        node {
                            label 'docker-compose'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "rpm"
                        RESTY_IMAGE_BASE = "rhel"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'make setup-ci'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=7 && make package-kong && make test'
                        sh 'export RESTY_IMAGE_TAG=8 && make package-kong && make test'
                    }
                }
                stage('Centos Builds'){
                    agent {
                        node {
                            label 'docker-compose'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "rpm"
                        RESTY_IMAGE_BASE = "centos"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'make setup-ci'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=8 && make package-kong && make test'
                        sh 'export RESTY_IMAGE_TAG=7 && make package-kong && make test'
                        sh 'export RESTY_IMAGE_TAG=6 && make package-kong && make test'
                    }
                }
                stage('Debian Builds'){
                    agent {
                        node {
                            label 'docker-compose'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "debian"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'make setup-ci'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=stretch && make package-kong && make test'
                        sh 'export RESTY_IMAGE_TAG=jessie && make package-kong && make test'
                        sh 'export RESTY_IMAGE_TAG=buster && make package-kong && make test'
                        sh 'export RESTY_IMAGE_TAG=bullseye && make package-kong && make test'
                    }
                }
                stage('Ubuntu Builds'){
                    agent {
                        node {
                            label 'docker-compose'
                        }
                    }
                    options {
                        retry(2)
                    }
                    environment {
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "ubuntu"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                        USER = 'travis'
                        AWS_ACCESS_KEY = credentials('AWS_ACCESS_KEY')
                        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'make setup-ci'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export BUILDX=false RESTY_IMAGE_TAG=bionic && make package-kong && make test'
                        sh 'export CACHE=false UPDATE_CACHE=true RESTY_IMAGE_TAG=xenial DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` && make setup-build && make package-kong && make test'
                    }
                    post {
                        always {
                            sh 'make cleanup-build'
                        }
                    }
                }
            }
        }
    }
}
