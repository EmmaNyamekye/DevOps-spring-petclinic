pipeline {
    agent any 

    tools {
        maven 'Maven 3.x' // This must match the name in Manage Jenkins > Tools
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/your-username/spring-petclinic.git'
            }
        }
        
        stage('Build & Test') {
            steps {
                bat 'mvn clean package -DskipTests'
            }
        }

        /*stage('SonarQube Scan') {
            steps {
                // IMPORTANT: Only enable this if you have the SonarQube plugin 
                // and server configured in Jenkins
                bat 'mvn sonar:sonar'
            }
        }*/

        stage('Dockerize') {
            steps {
                bat 'docker build -t petclinic-image .'
            }
        }
    }
}