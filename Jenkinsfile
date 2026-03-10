pipeline {
    agent any 

    tools {
        maven 'Maven 3.x' 
    }

    stages {
        stage('Build & Test') {
            steps {
                bat 'mvn clean package -DskipTests'
            }
        }

        stage('Dockerize') {
            steps {
                bat 'docker build -t petclinic-image .'
            }
        }
    }
}