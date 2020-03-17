pipeline {
    agent none
    environment {
        KONG_SOURCE = "master"
        KONG_SOURCE_LOCATION = "/tmp/kong"
        DOCKER_USERNAME = "${env.DOCKERHUB_USR}"
        DOCKER_PASSWORD = "${env.DOCKERHUB_PSW}"
        DOCKERHUB = credentials('dockerhub')
    }
    stages {
        stage('Release') {
            agent {
                node {
                    label 'docker-compose'
                }
            }
            environment {
                GITHUB_TOKEN = credentials('GITHUB_TOKEN')
            }
            steps {
                sh 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash'
                sh '. ~/.nvm/nvm.sh && nvm install lts/*'
                sh '. ~/.nvm/nvm.sh && npx semantic-release@beta --dry-run'
            }
        }
    }
}
