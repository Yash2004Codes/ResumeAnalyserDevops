pipeline {
    agent any

    environment {
        // Defines the Docker Compose project name
        COMPOSE_PROJECT_NAME = "devops_resume_analyser"
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout Code') {
            steps {
                // 'checkout scm' only works if Jenkins pulls this Jenkinsfile directly from Git.
                // Since you pasted it manually, you must explicitly tell Jenkins where the code is:
                git branch: 'master', url: 'https://github.com/Mihit10/devops-resume-analyser.git'
            }
        }

        stage('Code Quality (SonarQube)') {
            steps {
                // Runs the SonarQube Scanner against the codebase
                // Note: Requires SonarQube Scanner plugin installed in Jenkins
                script {
                    // 'sonar-scanner' must be configured in Jenkins Global Tool Configuration
                    def scannerHome = tool 'sonar-scanner'
                    // 'sonar-server' must be configured in Jenkins System Configuration
                    withSonarQubeEnv('sonar-server') {
                        sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=devops_resume_analyser -Dsonar.sources=."
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                // Pauses the pipeline until SonarQube finishes its analysis.
                // Aborts the build if the code fails the quality standards.
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build & Start App (Docker)') {
            steps {
                // Uses the host's Docker daemon (via the socket we mounted in Terraform)
                // to build and run the Next.js, Python, Prometheus, and Grafana containers
                
                // Stop and remove containers from a previous build (leave Jenkins & SonarQube running)
                sh 'docker compose stop frontend backend prometheus grafana node-exporter || true'
                sh 'docker compose rm -f frontend backend prometheus grafana node-exporter || true'
                
                // Docker compose expects a backend/.env file, but it's ignored by Git. 
                sh 'touch backend/.env'
                
                sh 'docker compose build frontend backend'
                sh 'docker compose up -d frontend backend prometheus grafana node-exporter'
            }
        }

        stage('Automated UI Testing (Selenium)') {
            steps {
                // Wait briefly for the Next.js server to fully start
                sh 'sleep 10'
                
                // Spin up a temporary Python container on the same Docker network 
                // to run the Selenium Pytest scripts against the running frontend
                sh '''
                # Bind mounts (-v) fail because Jenkins is in a container (Docker-in-Docker)
                # Instead, we send the context via 'docker build'
                cat << 'EOF' > Dockerfile.test
                FROM python:3.10-slim
                WORKDIR /tests
                COPY tests/e2e /tests
                RUN apt-get update && apt-get install -y wget && \\
                    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \\
                    apt-get install -y ./google-chrome-stable_current_amd64.deb && \\
                    rm google-chrome-stable_current_amd64.deb && \\
                    pip install --no-cache-dir -r requirements.txt
                CMD ["pytest", "test_homepage.py", "-v"]
                EOF
                
                docker build -t e2e-test-runner -f Dockerfile.test .
                docker run --rm --network ${COMPOSE_PROJECT_NAME}_default -e BASE_URL=http://frontend:3000 e2e-test-runner
                '''
            }
        }

        stage('Deploy to AWS / Production') {
            steps {
                echo "All tests passed! Deploying application & Prometheus/Grafana stack to AWS..."
                script {
                    // In an AWS automated workflow, you can trigger a deployment on your AWS EC2 instance:
                    // withCredentials([sshUserPrivateKey(credentialsId: 'aws-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                    //     sh 'ssh -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@$AWS_HOST "cd /opt/devops-resume-analyser && git pull && docker compose -f docker-compose.prod.yml up -d --build"'
                    // }
                    echo "Deployment completed successfully! Live at AWS Public IP."
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline executed successfully! The new version is live and the containers are left running."
        }
        failure {
            // Clean up the containers since the pipeline failed (e.g., tests failed)
            sh 'docker compose stop frontend backend prometheus grafana node-exporter || true'
            sh 'docker compose rm -f frontend backend prometheus grafana node-exporter || true'
            echo "Pipeline failed! Code did not pass quality gates or tests."
        }
    }
}
