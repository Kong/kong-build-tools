pipeline {
    agent none
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
                stage('AmazonLinux'){
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
                        sh 'export RESTY_IMAGE_BASE=amazonlinux RESTY_IMAGE_TAG=2 PACKAGE_TYPE=rpm && make package-kong && make test && make cleanup'
                    }
                }
                stage('src & Alpine'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    steps {
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_BASE=src RESTY_IMAGE_TAG=src PACKAGE_TYPE=src && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_BASE=alpine RESTY_IMAGE_TAG=3 PACKAGE_TYPE=apk CACHE=false UPDATE_CACHE=true DOCKER_MACHINE_ARM64_NAME="jenkins-kong-"`cat /proc/sys/kernel/random/uuid` && make package-kong && make test && make cleanup'
                    }
                }
                stage('RedHat'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
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
                stage('CentOS'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "rpm"
                        RESTY_IMAGE_BASE = "centos"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=7 && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=8 && make package-kong && make test && make cleanup'
                    }
                }
                stage('Debian OldStable'){
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "debian"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=stretch && make package-kong && make test && make cleanup'
                    }
                }
                stage('Debian Stable & Testing') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
                        PACKAGE_TYPE = "deb"
                        RESTY_IMAGE_BASE = "debian"
                        PATH = "/home/ubuntu/bin/:${env.PATH}"
                    }
                    steps {
                        sh 'mkdir -p /home/ubuntu/bin/'
                        sh 'git clone --single-branch --branch ${KONG_SOURCE} https://github.com/Kong/kong.git ${KONG_SOURCE_LOCATION}'
                        sh 'export RESTY_IMAGE_TAG=buster && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=bullseye && make package-kong && make test && make cleanup'
                    }
                }
                stage('Ubuntu') {
                    agent {
                        node {
                            label 'bionic'
                        }
                    }
                    environment {
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
                        sh 'export RESTY_IMAGE_TAG=bionic && make package-kong && make test && make cleanup'
                        sh 'export RESTY_IMAGE_TAG=focal && make package-kong && make test && make cleanup'
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
                allOf {
                    branch 'master'
                    anyOf {
                        changeset pattern: "openresty-build-tools/kong-ngx-build"
                        changeset pattern: "openresty-patchs/patches/*/*.patch"
                    }
                }
            }
            environment {
                GITHUB_TOKEN = credentials('github_bot_access_token')
                LUAROCKS_PREFIX = "/usr/local"
                LUAROCKS_DESTDIR = "/tmp/build"
                OPENRESTY_PREFIX = "/usr/local/openresty"
                OPENRESTY_DESTDIR = "/tmp/build"
                OPENSSL_PREFIX = "/usr/local/kong"
                OPENSSL_DESTDIR = "/tmp/build"
                OPENRESTY_RPATH = "/usr/local/kong/lib"
            }
            steps {
                sh './openresty-build-tools/kong-ngx-build \
                    -p /tmp/build/usr/local \
                    --semver cache'
            }
            post {
                success {
                    sh 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash'
                    sh '. ~/.nvm/nvm.sh && nvm install lts/*'
                    sh '. ~/.nvm/nvm.sh && npx semantic-release@beta'
                }
            }
        }
    }
}
