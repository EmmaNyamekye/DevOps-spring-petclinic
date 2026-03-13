pipeline {
    agent any 

    tools {
        maven 'maven 3.9.11' 
        // jdk 'JDK17'
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