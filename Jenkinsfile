pipeline {
    // Run pipeline on any available agent
    agent any
    
    // Configure tools that Jenkins should auto-install and use
    tools {
        maven 'Maven'  // Maven tool configured in Jenkins Global Tools
        jdk 'Java17'   // Java 17 tool configured in Jenkins Global Tools
    }
    
    // Environment variables used throughout the pipeline
    environment {
        // AWS Configuration
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '594715259894' // Replace with your AWS Account ID
        
        // ECR Repository Configuration
        ECR_REPOSITORY = 'demo-rest-api'
        IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKER_IMAGE = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPOSITORY}"
        
        // EC2 Deployment Configuration
        EC2_HOST = 'ec2-18-206-97-176.compute-1.amazonaws.com' // Replace with your EC2 host
        APPLICATION_PORT = '8080'
        CONTAINER_NAME = 'demo-rest-api'
    }
    
    stages {
        // Stage 1: Checkout source code from GitHub
        stage('Checkout') {
            steps {
                echo '📥 Checking out source code from GitHub...'
                // Jenkins automatically checks out the repository based on pipeline configuration
                checkout scm
                echo '✅ Source code checkout completed'
            }
        }
        
        // Stage 2: Compile the Spring Boot application
        stage('Build') {
            steps {
                echo '🔨 Building Spring Boot application...'
                // Compile source code without running tests (tests run in separate stage)
                sh 'mvn clean compile -DskipTests'
                echo '✅ Build compilation completed successfully'
            }
        }
        
        // Stage 3: Run unit tests
	    stage('Test') {
		    steps {
		        echo '🧪 Running unit tests...'
		        // Execute Maven test phase
		        sh 'mvn test'
		        echo '✅ Unit tests completed'
		    }
		    post {
		        always {
		            echo '📊 Test stage completed'
		        }
		    }
		}
        
        // Stage 4: Package application into executable JAR
        stage('Package') {
            steps {
                echo '📦 Packaging application into JAR...'
                // Create executable JAR file, skip tests as they already ran
                sh 'mvn package -DskipTests'
                echo '✅ Application packaged successfully'
            }
        }
        
        // Stage 5: Build Docker image
        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Build Docker image with build number tag
                    dockerImage = docker.build("${DOCKER_IMAGE}:${IMAGE_TAG}")
                    // Also tag as 'latest' for easy reference
                    docker.build("${DOCKER_IMAGE}:latest")
                    echo '✅ Docker image built successfully'
                }
            }
        }
        
        // Stage 6: Push Docker image to AWS ECR
        stage('Push to ECR') {
            steps {
                echo '☁️ Pushing Docker image to AWS ECR...'
                script {
                    // Use AWS credentials configured in Jenkins
                    withAWS(credentials: 'aws-credentials', region: "${AWS_DEFAULT_REGION}") {
                        sh '''
                        echo "🔐 Authenticating with AWS ECR..."
                        # Login to ECR registry
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
                        
                        echo "📤 Pushing Docker images to ECR..."
                        # Push both tagged and latest images
                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        
                        echo "✅ Docker images pushed to ECR successfully"
                        '''
                    }
                }
            }
        }
        // Otherwise for Stage 6: we may do this below to skip Docker
        // stage('Push to ECR') {
        //    when {
        //        expression { return false } // Temporarily disable ECR push
        //    }
        //    steps {
        //        echo '☁️ ECR push disabled for testing...'
        //    }
        // }
        
        // Stage 7: Deploy application to AWS EC2
        stage('Deploy to EC2') {
		    steps {
		        echo 'Deploying application to AWS EC2...'
		        script {
		            withAWS(credentials: 'aws-credentials', region: "${AWS_DEFAULT_REGION}") {
		                withCredentials([file(credentialsId: 'ec2-ssh-key-file', variable: 'SSH_KEY_FILE')]) {
		                    sh '''
		                    # Set proper permissions for SSH key
		                    chmod 600 $SSH_KEY_FILE
		                    
		                    # Deploy using direct SSH
		                    ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} "
		                        echo 'Deploying application...'
		                        # ... deployment commands ...
		                    "
		                    '''
		                }
		            }
		        }
		    }
		}
        
        /* Alternative - because I am using SSH with Key file 
        stage('Deploy to EC2') {
            steps {
                echo '🚀 Deploying application to AWS EC2...'
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_DEFAULT_REGION}") {
                        // Use SSH agent for secure connection to EC2
                        sshagent(['ec2-ssh-key']) {
                            sh '''
                            echo "🔗 Connecting to EC2 instance: ${EC2_HOST}"
                            
                            # Connect to EC2 and execute deployment commands
                            ssh -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} "
                                echo '📋 Setting up Docker environment...'
                                
                                # Update system packages
                                sudo yum update -y
                                
                                # Install Docker if not already installed
                                sudo yum install docker -y
                                
                                # Start Docker service
                                sudo systemctl start docker
                                sudo systemctl enable docker
                                
                                # Add ec2-user to docker group for non-sudo access
                                sudo usermod -a -G docker ec2-user
                                
                                echo '🔐 Authenticating with AWS ECR...'
                                # Login to ECR from EC2 instance
                                aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
                                
                                echo '🛑 Stopping existing container...'
                                # Stop and remove existing container (ignore errors if not exists)
                                sudo docker stop ${CONTAINER_NAME} || true
                                sudo docker rm ${CONTAINER_NAME} || true
                                
                                echo '📥 Pulling latest Docker image...'
                                # Pull the newly built image
                                sudo docker pull ${DOCKER_IMAGE}:${IMAGE_TAG}
                                
                                echo '▶️ Starting new container...'
                                # Run new container with proper configuration
                                sudo docker run -d \\
                                    --name ${CONTAINER_NAME} \\
                                    -p ${APPLICATION_PORT}:8080 \\
                                    --restart unless-stopped \\
                                    ${DOCKER_IMAGE}:${IMAGE_TAG}
                                
                                echo '🧹 Cleaning up old Docker images...'
                                # Remove unused images to save space
                                sudo docker image prune -f
                                
                                echo '✅ Deployment completed successfully'
                            "
                            '''
                        }
                    }
                }
            }
        }
        Remove upto here because I am using SSH with key file */
        
        // Stage 7: Deploy JAR directly to EC2 (alternative deployment)
        /* From here ... This is applicable for JAR instead of Docker 
        stage('Deploy JAR to EC2') {
            steps {
                echo '🚀 Deploying JAR file directly to AWS EC2...'
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_DEFAULT_REGION}") {
                        sshagent(['ec2-ssh-key']) {
                            sh '''
                            echo "📦 Copying JAR file to EC2..."
                            
                            # Copy JAR file to EC2
                            scp -o StrictHostKeyChecking=no target/*.jar ec2-user@${EC2_HOST}:/home/ec2-user/app.jar
                            
                            echo "🔗 Connecting to EC2 and deploying application..."
                            ssh -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} "
                                # Stop existing application
                                pkill -f 'java -jar' || true
                                
                                # Install Java if not present
                                sudo yum install java-17-amazon-corretto -y
                                
                                # Start application in background
                                nohup java -jar /home/ec2-user/app.jar --server.port=${APPLICATION_PORT} > /home/ec2-user/app.log 2>&1 &
                                
                                # Wait for application to start
                                sleep 30
                                
                                echo '✅ Application deployed successfully'
                            "
                            '''
                        }
                    }
                }
            }
        }
        Upto here ... This is applicable for JAR instead of Docker */ 
        
        // Stage 8: Verify deployment
        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying application deployment...'
                script {
                    // Wait for application to fully start
                    echo '⏳ Waiting for application to start (30 seconds)...'
                    sleep(30)
                    
                    // Test application endpoints
                    sh '''
                    echo "🔍 Testing application endpoints..."
                    
                    # Test welcome endpoint
                    echo "Testing /api/v1/welcome endpoint..."
                    curl -f -s http://${EC2_HOST}:${APPLICATION_PORT}/api/v1/welcome || (echo "❌ Welcome endpoint failed" && exit 1)
                    echo "✅ Welcome endpoint working"
                    
                    # Test info endpoint
                    echo "Testing /api/v1/info endpoint..."
                    curl -f -s http://${EC2_HOST}:${APPLICATION_PORT}/api/v1/info || (echo "❌ Info endpoint failed" && exit 1)
                    echo "✅ Info endpoint working"
                    
                    # Test users endpoint
                    echo "Testing /api/v1/users endpoint..."
                    curl -f -s http://${EC2_HOST}:${APPLICATION_PORT}/api/v1/users || (echo "❌ Users endpoint failed" && exit 1)
                    echo "✅ Users endpoint working"
                    
                    # Test version endpoint
                    echo "Testing /api/v1/version endpoint..."
                    curl -f -s http://${EC2_HOST}:${APPLICATION_PORT}/api/v1/version || (echo "❌ Version endpoint failed" && exit 1)
                    echo "✅ Version endpoint working"
                    
                    echo "🎉 All endpoints are working correctly!"
                    '''
                }
            }
        }
    }
    
    // Post-build actions that run regardless of build result
    post {
        // Always clean workspace after build
        always {
            echo '🧹 Cleaning up workspace...'
            cleanWs()
        }
        
        // Actions for successful builds
        success {
            echo '🎉 Pipeline succeeded! Application deployed successfully to AWS.'
            
            // Send success notification email (optional)
            emailext (
                to: 'pswathi.kkd@gmail.com',
                subject: '✅ Jenkins Build Success: ${JOB_NAME} - Build #${BUILD_NUMBER}',
                body: '''
                🎉 Great news! Your Spring Boot application has been successfully deployed to AWS.
                
                📋 Build Details:
                • Project: ${JOB_NAME}
                • Build Number: ${BUILD_NUMBER}
                • Git Commit: ${GIT_COMMIT}
                • Build URL: ${BUILD_URL}
                
                🌐 Application Access:
                • Application URL: http://your-ec2-host:8080/api/v1/welcome
                • Version Info: http://your-ec2-host:8080/api/v1/version
                
                ✅ All endpoints are verified and working correctly.
                '''.stripIndent()
            )
        }
        
        // Actions for failed builds
        failure {
            echo '❌ Pipeline failed! Check the logs for details.'
            
            // Send failure notification email (optional)
            emailext (
                to: 'developer@example.com',
                subject: '❌ Jenkins Build Failed: ${JOB_NAME} - Build #${BUILD_NUMBER}',
                body: '''
                ❌ Build failed for your Spring Boot application deployment.
                
                📋 Build Details:
                • Project: ${JOB_NAME}
                • Build Number: ${BUILD_NUMBER}
                • Git Commit: ${GIT_COMMIT}
                • Build Logs: ${BUILD_URL}console
                
                🔍 Please check the build logs for detailed error information.
                '''.stripIndent()
            )
        }
    }
}
