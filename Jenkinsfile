pipeline {
    agent any
    tools {
        maven 'maven 3.9.11'
        jdk   'JDK17'
    }
    environment {
        DOCKER_HUB_USER = 'emmanyamekye'
        IMAGE_NAME      = "${DOCKER_HUB_USER}/spring-petclinic"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        DOCKER_CREDS    = 'docker-hub-token-creds'
        SONAR_ORG       = 'emmanyamekye'
        SONAR_PROJECT   = 'DevOps-spring-petclinic'
        SONAR_TOKEN     = credentials('sonarcloud-token-creds')
        SLACK_CHANNEL   = '#all-devops-spring-petclinic'
        SLACK_TEAM      = 'devopsspringp-u4e1976'
        SLACK_CREDS     = 'slack-token-creds'
    }
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    triggers {
        pollSCM('H/5 * * * *')
    }
    stages {

        stage('Checkout') {
            steps {
                echo '=== Checking out source code ==='
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo '=== Compiling application ==='
                bat 'mvn clean compile -DskipTests'
            }
            post {
                failure {
                    slackSend teamDomain: env.SLACK_TEAM,
                              tokenCredentialId: env.SLACK_CREDS,
                              channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Build* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        stage('Unit Tests') {
            steps {
                echo '=== Running unit tests ==='
                bat 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
                failure {
                    slackSend teamDomain: env.SLACK_TEAM,
                              tokenCredentialId: env.SLACK_CREDS,
                              channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Unit Tests* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        stage('Code Quality (SonarCloud)') {
            steps {
                echo '=== Running SonarCloud analysis ==='
                bat """
                    mvn sonar:sonar ^
                        -Dsonar.projectKey=%SONAR_PROJECT% ^
                        -Dsonar.organization=%SONAR_ORG% ^
                        -Dsonar.host.url=https://sonarcloud.io ^
                        -Dsonar.login=%SONAR_TOKEN%
                """
            }
            post {
                failure {
                    slackSend teamDomain: env.SLACK_TEAM,
                              tokenCredentialId: env.SLACK_CREDS,
                              channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *SonarCloud* quality gate.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        stage('Package') {
            steps {
                echo '=== Packaging JAR ==='
                bat 'mvn package -DskipTests'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Build Docker Image') {
            steps {
                echo '=== Building Docker image ==='
                bat "docker build -t %IMAGE_NAME%:%IMAGE_TAG% -t %IMAGE_NAME%:latest ."
            }
            post {
                failure {
                    slackSend teamDomain: env.SLACK_TEAM,
                              tokenCredentialId: env.SLACK_CREDS,
                              channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Docker Build* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                echo '=== Pushing image to DockerHub ==='
                withCredentials([usernamePassword(
                        credentialsId: "${DOCKER_CREDS}",
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS')]) {
                    bat """
                        echo %DOCKER_PASS%| docker login -u %DOCKER_USER% --password-stdin
                        docker push %IMAGE_NAME%:%IMAGE_TAG%
                        docker push %IMAGE_NAME%:latest
                        docker logout
                    """
                }
            }
            post {
                failure {
                    slackSend teamDomain: env.SLACK_TEAM,
                              tokenCredentialId: env.SLACK_CREDS,
                              channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *DockerHub Push* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        stage('Deploy (Local Docker)') {
            steps {
                echo '=== Deploying container locally ==='
                bat """
                    docker stop petclinic-app 2>nul || echo No old container to stop
                    docker rm   petclinic-app 2>nul || echo No old container to remove
                    docker run -d ^
                        --name petclinic-app ^
                        -p 8080:8080 ^
                        --restart unless-stopped ^
                        %IMAGE_NAME%:%IMAGE_TAG%
                """
            }
            post {
                failure {
                    slackSend teamDomain: env.SLACK_TEAM,
                              tokenCredentialId: env.SLACK_CREDS,
                              channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Deploy* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        stage('Smoke Test') {
            steps {
                echo '=== Running smoke test ==='
                retry(5) {
                    sleep(time: 15, unit: 'SECONDS')
                    bat 'curl --fail http://localhost:8080/actuator/health'
                }
            }
            post {
                failure {
                    slackSend teamDomain: env.SLACK_TEAM,
                              tokenCredentialId: env.SLACK_CREDS,
                              channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Smoke Test* — app did not start.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

    }

    post {
        success {
            slackSend teamDomain: env.SLACK_TEAM,
                      tokenCredentialId: env.SLACK_CREDS,
                      channel: env.SLACK_CHANNEL,
                      color: 'good',
                      message: "✅ *PetClinic* Build #${BUILD_NUMBER} deployed successfully!\nApp: http://localhost:8080\n<${BUILD_URL}|View in Jenkins>"
        }
        always {
            bat 'docker image prune -f || echo Pruning skipped'
            cleanWs()
        }
    }

}