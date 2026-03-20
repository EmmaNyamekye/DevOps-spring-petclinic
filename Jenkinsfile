pipeline {
    agent any

    tools {
        maven 'maven 3.9.11'
        jdk   'JDK17'
    }

    // ENVIRONMENT VARIABLES
    // Sensitive values use Jenkins credentials so passwords never appear in plain text.
    environment {
        // Docker Hub
        DOCKER_HUB_USER = 'emmanyamekye'
        IMAGE_NAME = "${DOCKER_HUB_USER}/spring-petclinic"
        IMAGE_TAG = "${BUILD_NUMBER}"

        // Jenkins credential IDs
        DOCKER_CREDS = 'docker-hub-token-creds'

        // SonarCloud
        SONAR_ORG = 'emmanyamekye'
        SONAR_PROJECT = 'DevOps-spring-petclinic'
        SONAR_TOKEN = credentials('sonarcloud-token-creds')

        // Slack
        SLACK_CHANNEL = '#all-devops-spring-petclinic'
        SLACK_TEAM = 'devopsspringp-u4e1976'
        SLACK_CREDS = 'slack-token-creds'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // Poll GitHub every 5 minutes for new commits
    triggers {
        pollSCM('H/5 * * * *')
    }

    // ═════════════════════════════════════════════
    // STAGES
    // ═════════════════════════════════════════════
    stages {

        // ──────────────────────────────────────────
        // STAGE 1 · Checkout
        // Jenkins pulls the latest code from your
        // GitHub repo on every run.
        // ──────────────────────────────────────────
        stage('Checkout') {
            steps {
                echo '=== Checking out source code ==='
                checkout scm   // uses the repo configured in the Jenkins job
            }
        }

        // ──────────────────────────────────────────
        // STAGE 2 · Build
        // Compile-only pass (tests run separately
        // so failures are clearly separated).
        // ──────────────────────────────────────────
        stage('Build') {
            steps {
                echo '=== Compiling application ==='
                bat 'mvn clean compile -DskipTests'
            }
            post {
                failure {
                    slackSend channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Build* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        // ──────────────────────────────────────────
        // STAGE 3 · Unit Tests
        // Runs every JUnit test bundled with
        // PetClinic. Results are published so
        // Jenkins shows a test-trend graph.
        // ──────────────────────────────────────────
        stage('Unit Tests') {
            steps {
                echo '=== Running unit tests ==='
                bat 'mvn test -Dspring.docker.compose.skip.in-tests=true'
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

        // ──────────────────────────────────────────
        // STAGE 4 · Code Quality · SonarCloud
        // Static analysis + quality gate.
        // The pipeline fails if the gate is not met.
        // Requires: SonarQube Scanner plugin in Jenkins
        //           + sonarcloud-token credential
        // ──────────────────────────────────────────
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
                    slackSend channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *SonarCloud* quality gate.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        // ──────────────────────────────────────────
        // STAGE 5 · Package
        // Produce the final runnable JAR and save it
        // as a Jenkins artifact for traceability.
        // ──────────────────────────────────────────
        stage('Package') {
            steps {
                echo '=== Packaging JAR ==='
                bat 'mvn package -DskipTests'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        // ──────────────────────────────────────────
        // STAGE 6 · Build Docker Image
        // Uses your existing Dockerfile (the simple
        // 4-line one that already works for you).
        // Tags with build number AND :latest.
        // ──────────────────────────────────────────
        stage('Build Docker Image') {
            steps {
                echo '=== Building Docker image ==='
                bat "docker build -t %IMAGE_NAME%:%IMAGE_TAG% -t %IMAGE_NAME%:latest ."
            }
            post {
                failure {
                    slackSend channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Docker Build* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        // ──────────────────────────────────────────
        // STAGE 7 · Push to DockerHub
        // Logs in using your Jenkins credential,
        // pushes both tags, then logs out.
        // ──────────────────────────────────────────
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
                    slackSend channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *DockerHub Push* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        // ──────────────────────────────────────────
        // STAGE 8 · Deploy (Local Docker)
        // Stops any old container and starts a fresh
        // one from the newly pushed image.
        // This proves end-to-end CD on your machine.
        // ──────────────────────────────────────────
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
                    slackSend channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Deploy* stage.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

        // ──────────────────────────────────────────
        // STAGE 9 · Smoke Test
        // Waits for the app to start then checks
        // the Spring Actuator health endpoint.
        // Retries 5 times with 15-second gaps.
        // ──────────────────────────────────────────
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
                    slackSend channel: env.SLACK_CHANNEL,
                              color: 'danger',
                              message: "❌ *PetClinic* Build #${BUILD_NUMBER} FAILED at *Smoke Test* — app did not start.\n<${BUILD_URL}|View in Jenkins>"
                }
            }
        }

    } // end stages

    // ═════════════════════════════════════════════
    // POST ACTIONS — run after all stages
    // ═════════════════════════════════════════════
    post {

        success {
            echo 'Pipeline completed successfully!'
            slackSend channel: env.SLACK_CHANNEL,
                      color: 'good',
                      message: "✅ *PetClinic* Build #${BUILD_NUMBER} deployed successfully!\nApp: http://localhost:8080\n<${BUILD_URL}|View in Jenkins>"
        }

        always {
            // Remove dangling images to free disk space
            bat 'docker image prune -f || echo Pruning skipped'
            cleanWs()
        }
    }

} // end pipeline