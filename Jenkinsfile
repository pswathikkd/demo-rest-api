pipeline {
    // Run pipeline on any available agent
    agent any
    
    // Configure tools that Jenkins should auto-install and use
    tools {
        maven 'Maven'  // Maven tool configured in Jenkins Global Tools
        jdk 'Java17'   // Java 17 tool configured in Jenkins Global Tools
    }
    
    // Environment variables used throughout the pipeline
    // 🔧 MODIFY THESE VALUES FOR YOUR SETUP:
    environment {
        // 📧 UPDATE: Change to your email address
        EMAIL_RECIPIENT = 'pswathi.kkd@gmail.com'
        
        // 🖥️ UPDATE: Replace with your actual EC2 instance details
        EC2_HOST = '3.89.153.73'  // Updated with your EC2 public IP
        EC2_USER = 'ec2-user'  // Default for Amazon Linux, change if different
        
        // 🚀 Application Configuration
        APPLICATION_PORT = '8282'
        APP_NAME = 'demo-rest-api'
        JAR_NAME = 'demo-rest-api-1.0.0.jar'
        
        // 📁 Deployment paths on EC2
        DEPLOY_DIR = '/home/ec2-user/app'
        LOG_DIR = '/home/ec2-user/logs'
    }
    
    stages {
        // Stage 1: Checkout source code from GitHub
        stage('Checkout') {
            steps {
                echo '📥 Checking out source code from GitHub...'
                // Jenkins automatically checks out the repository
                checkout scm
                echo '✅ Source code checkout completed'
            }
        }
        
        // Stage 2: Build the Spring Boot application (No Tests)
        stage('Build') {
            steps {
                echo '🔨 Building Spring Boot application...'
                // Clean and compile source code, skip tests
                sh 'mvn clean compile -DskipTests'
                echo '✅ Build compilation completed successfully'
            }
        }
        
        // Stage 3: Package application into executable JAR (No Tests)
        stage('Package') {
            steps {
                echo '📦 Packaging application into JAR...'
                // Create executable JAR file, skip tests
                sh 'mvn package -DskipTests'
                
                // Verify JAR file was created
                sh '''
                echo "📋 Verifying JAR file creation..."
                ls -la target/*.jar
                echo "✅ JAR file created successfully"
                '''
                echo '✅ Application packaged successfully'
            }
        }
        
        // Stage 4: Deploy JAR to EC2 using Simple SSH
        stage('Deploy to EC2') {
            steps {
                echo '🚀 Deploying JAR file to AWS EC2...'
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh '''
                        echo "🔗 Connecting to EC2 instance: ${EC2_HOST}"
                        
                        # Set proper permissions for SSH key
                        chmod 600 $SSH_KEY
                        
                        # Create directories on EC2
                        echo "📁 Creating directories on EC2..."
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} "mkdir -p ${DEPLOY_DIR} && mkdir -p ${LOG_DIR} && echo 'Directories created'"
                        
                        echo "📦 Copying JAR file to EC2..."
                        # Copy JAR file to EC2 (note: actual JAR name is different from expected)
                        scp -i $SSH_KEY -o StrictHostKeyChecking=no target/*.jar ${EC2_USER}@${EC2_HOST}:${DEPLOY_DIR}/app.jar
                        
                        echo "🔧 Deploying application on EC2..."
                        # Create deployment script on EC2
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} "cat > ${DEPLOY_DIR}/deploy.sh << 'EOF'
#!/bin/bash
echo '🛑 Stopping existing application...'
pkill -f 'java.*app.jar' || true
sleep 5

echo '☕ Checking Java installation...'
if ! java -version 2>&1 | grep -q '17'; then
    echo '📥 Installing Java 17...'
    sudo yum update -y
    sudo yum install java-17-amazon-corretto -y
else
    echo '✅ Java 17 already installed'
fi

echo '▶️ Starting Spring Boot application...'
cd ${DEPLOY_DIR}
nohup java -jar app.jar --server.port=${APPLICATION_PORT} --logging.file.name=${LOG_DIR}/application.log > ${LOG_DIR}/startup.log 2>&1 &

echo '⏳ Waiting for application to start...'
sleep 30

echo 'Checking if application started...'
if pgrep -f 'java.*app.jar' > /dev/null; then
    PID=\$(pgrep -f 'java.*app.jar')
    echo \"✅ Application started successfully with PID: \$PID\"
    echo \"📋 Recent startup logs:\"
    tail -10 ${LOG_DIR}/startup.log
else
    echo '❌ Application failed to start'
    echo '📋 Startup logs:'
    cat ${LOG_DIR}/startup.log 2>/dev/null || echo 'No startup log found'
    echo '📋 Application logs:'
    tail -20 ${LOG_DIR}/application.log 2>/dev/null || echo 'No application log found'
    exit 1
fi
EOF"
                        
                        echo "▶️ Executing deployment script..."
                        # Execute the deployment script
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} "chmod +x ${DEPLOY_DIR}/deploy.sh && ${DEPLOY_DIR}/deploy.sh"
                        
                        echo "✅ Deployment completed successfully"
                        '''
                    }
                }
            }
        }
        
        // Stage 5: Verify deployment by testing endpoints
        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying application deployment...'
                script {
                    // Wait a bit more for application to be fully ready
                    echo '⏳ Waiting for application to be fully ready...'
                    sleep(20)
                    
                    // Test your actual controller endpoints
                    sh '''
                    echo "🔍 Testing application endpoints..."
                    
                    # Test your home endpoint (root path)
                    echo "Testing / (home) endpoint..."
                    if curl -f -s --max-time 10 http://${EC2_HOST}:${APPLICATION_PORT}/; then
                        echo "✅ Home endpoint working"
                        echo "Response: $(curl -s --max-time 10 http://${EC2_HOST}:${APPLICATION_PORT}/)"
                    else
                        echo "❌ Home endpoint failed"
                        echo "Checking if application is running..."
                        
                        # Debug: Check if application is running
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} "
                            echo 'Checking running Java processes:'
                            pgrep -f 'java' || echo 'No Java processes found'
                            
                            echo 'Checking application logs:'
                            tail -20 ${LOG_DIR}/startup.log 2>/dev/null || echo 'No startup log'
                            tail -20 ${LOG_DIR}/application.log 2>/dev/null || echo 'No application log'
                            
                            echo 'Checking port 8282:'
                            netstat -tulpn | grep 8282 || echo 'Port 8282 not in use'
                        " 2>/dev/null || echo "Could not connect to EC2 for debugging"
                        
                        exit 1
                    fi
                    
                    echo "🎉 Application verification completed successfully!"
                    echo "🌐 Your application is accessible at: http://${EC2_HOST}:${APPLICATION_PORT}/"
                    '''
                }
            }
        }
    }
    
    // Post-build actions
    post {
        // Always clean workspace after build
        always {
            echo '🧹 Cleaning up workspace...'
            cleanWs()
        }
        
        // Actions for successful builds
        success {
            echo '🎉 Pipeline succeeded! Application deployed successfully.'
            
            // Send success email notification
            script {
                try {
                    emailext (
                        // 📧 Email will be sent to the address specified in EMAIL_RECIPIENT
                        to: "${EMAIL_RECIPIENT}",
                        subject: '✅ Jenkins Build Success: ${JOB_NAME} - Build #${BUILD_NUMBER}',
                        mimeType: 'text/html',
                        body: """
                        <h2>🎉 Build Successful!</h2>
                        <p>Your Spring Boot application has been successfully deployed.</p>
                        
                        <h3>📋 Build Details:</h3>
                        <ul>
                            <li><strong>Project:</strong> ${JOB_NAME}</li>
                            <li><strong>Build Number:</strong> ${BUILD_NUMBER}</li>
                            <li><strong>Git Commit:</strong> ${GIT_COMMIT}</li>
                            <li><strong>Build URL:</strong> <a href="${BUILD_URL}">${BUILD_URL}</a></li>
                        </ul>
                        
                        <h3>🌐 Application Access:</h3>
                        <ul>
                            <li><strong>Home:</strong> <a href="http://${EC2_HOST}:${APPLICATION_PORT}/">http://${EC2_HOST}:${APPLICATION_PORT}/</a></li>
                        </ul>
                        
                        <p>✅ Your application endpoint has been verified and is working correctly.</p>
                        """
                    )
                    echo "📧 Success email sent to ${EMAIL_RECIPIENT}"
                } catch (Exception e) {
                    echo "⚠️ Email notification failed: ${e.message}"
                }
            }
        }
        
        // Actions for failed builds
        failure {
            echo '❌ Pipeline failed! Check the logs for details.'
            
            // Send failure email notification
            script {
                try {
                    emailext (
                        // 📧 Email will be sent to the address specified in EMAIL_RECIPIENT
                        to: "${EMAIL_RECIPIENT}",
                        subject: '❌ Jenkins Build Failed: ${JOB_NAME} - Build #${BUILD_NUMBER}',
                        mimeType: 'text/html',
                        body: """
                        <h2>❌ Build Failed!</h2>
                        <p>Your Spring Boot application deployment has failed.</p>
                        
                        <h3>📋 Build Details:</h3>
                        <ul>
                            <li><strong>Project:</strong> ${JOB_NAME}</li>
                            <li><strong>Build Number:</strong> ${BUILD_NUMBER}</li>
                            <li><strong>Git Commit:</strong> ${GIT_COMMIT}</li>
                            <li><strong>Build Logs:</strong> <a href="${BUILD_URL}console">${BUILD_URL}console</a></li>
                        </ul>
                        
                        <p>🔍 Please check the build logs for detailed error information.</p>
                        <p>Common issues to check:</p>
                        <ul>
                            <li>SSH connection to EC2 instance</li>
                            <li>Java installation on EC2</li>
                            <li>Port 8282 availability</li>
                            <li>Security group settings</li>
                        </ul>
                        """
                    )
                    echo "📧 Failure email sent to ${EMAIL_RECIPIENT}"
                } catch (Exception e) {
                    echo "⚠️ Email notification failed: ${e.message}"
                }
            }
        }
    }
}