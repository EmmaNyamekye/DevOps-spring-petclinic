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
        
        // UPDATED AWS SETTINGS
        AWS_IP          = '51.21.255.209'
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
                // This ID must match the ID you gave your credentials in Jenkins
                sshagent([env.AWS_SSH_ID]) {
                    script {
                        // We define the command exactly like the lecturer's example
                        def remoteCmd = "docker pull ${IMAGE_NAME}:${IMAGE_TAG} && docker stop petclinic-app || true && docker rm petclinic-app || true && docker run -d --name petclinic-app -p 9090:9090 ${IMAGE_NAME}:${IMAGE_TAG}"
                        
                        // We use the -o StrictHostKeyChecking=no to prevent the "yes/no" prompt
                        // We use double quotes for the whole string so Windows 'bat' handles it correctly
                        bat "ssh -o StrictHostKeyChecking=no ubuntu@${AWS_IP} \"${remoteCmd}\""
                    }
                }
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    try {
                        echo '=== Verifying AWS Cloud Deployment ==='
                        // Give the app 60s to start up on EC2
                        sleep(time: 60, unit: 'SECONDS')
                        retry(5) {
                            sleep(time: 20, unit: 'SECONDS')
                            bat "curl --fail http://${AWS_IP}:9090"
                        }
                    } catch (Exception e) {
                        echo "MONITORING NOTE: App is taking a while to respond. Check http://${AWS_IP}:9090 manually."
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