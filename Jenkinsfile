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
        
        // AWS SETTINGS
        AWS_IP          = '51.20.79.252'
        AWS_SSH_ID      = 'aws-ssh-key' 
        
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
    stages {
        stage('Checkout') {
            steps {
                echo '=== Checking out source code ==='
                checkout scm
            }
        }

        stage('Build & Compile') {
            steps {
                echo '=== Compiling application ==='
                bat 'mvn clean compile -DskipTests -DskipITs'
            }
        }

        stage('Code Quality (SonarCloud)') {
            steps {
                echo '=== Running SonarCloud analysis ==='
                withCredentials([string(credentialsId: 'sonarcloud-token-creds', variable: 'SONAR_TOKEN')]) {
                    bat """
                        mvn sonar:sonar ^
                            -Dsonar.projectKey=%SONAR_PROJECT% ^
                            -Dsonar.organization=%SONAR_ORG% ^
                            -Dsonar.host.url=https://sonarcloud.io ^
                            -Dsonar.login=%SONAR_TOKEN% ^
                            -DskipTests -DskipITs
                    """
                }
            }
        }

        stage('Package') {
            steps {
                echo '=== Packaging JAR ==='
                bat 'mvn package -DskipTests -DskipITs'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Build Docker Image') {
            steps {
                echo '=== Building Docker image ==='
                bat "docker build -t %IMAGE_NAME%:%IMAGE_TAG% -t %IMAGE_NAME%:latest ."
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
        }

        stage('Deploy to AWS') {
            steps {
                echo "=== Deploying to AWS Production Server (${AWS_IP}) ==="
                sshagent([env.AWS_SSH_ID]) {
                    // Using Windows-specific SSH path and single-line command for reliability
                    bat """
                        C:\\Windows\\System32\\OpenSSH\\ssh.exe -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@%AWS_IP% "docker pull %IMAGE_NAME%:%IMAGE_TAG% && docker stop petclinic-app || true && docker rm petclinic-app || true && docker run -d --name petclinic-app -p 9090:9090 %IMAGE_NAME%:%IMAGE_TAG%"
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    try {
                        echo '=== Verifying AWS Cloud Deployment ==='
                        // Give Spring Boot enough time to start before checking
                        sleep(time: 60, unit: 'SECONDS')
                        retry(5) {
                            sleep(time: 20, unit: 'SECONDS')
                            bat "curl --fail http://${AWS_IP}:9090"
                        }
                    } catch (Exception e) {
                        echo "MONITORING WARNING: Application might still be starting. Check http://${AWS_IP}:9090 manually."
                        currentBuild.result = 'UNSTABLE'
                    }
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
                      message: "✅ *PetClinic* Build #${BUILD_NUMBER} deployed to AWS!\nURL: http://${AWS_IP}:9090"
        }
        always {
            bat 'docker image prune -f || echo Pruning skipped'
            cleanWs()
        }
    }
}