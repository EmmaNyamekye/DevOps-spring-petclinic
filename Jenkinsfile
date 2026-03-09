pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/your-username/spring-petclinic.git'
            }
        }
        stage('Build & Test') {
            steps {
                sh 'mvn clean package'
            }
        }
        stage('SonarQube Scan') {
            steps {
                // This triggers the Quality Gate
                sh 'mvn sonar:sonar'
            }
        }
        stage('Dockerize') {
            steps {
                // This builds your container automatically
                sh 'docker build -t petclinic-image .'
            }
        }
    }
}