pipeline {
    agent any

    tools {
        maven "M2_HOME"
    }

    triggers {
        githubPush()
    }

    environment {
        DOCKER_APP_NAME   = "student-management-app"
        DOCKER_IMAGE_NAME = "student-management-student-app"
        DOCKERHUB_REPO    = "zainebmessaoudi/student-management-student-app"

        MYSQL_CONTAINER = "mysql-db"
        MYSQL_ROOT_PASSWORD = "rootpassword"
        MYSQL_DB = "studentdb"
        MYSQL_USER = "studentuser"
        MYSQL_PASSWORD = "password"

        APP_PORT = "8089"
        MYSQL_PORT = "3307"
        DOCKER_NETWORK = "student-network"
        K8S_NAMESPACE = "student-management" 
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Zaineb-Messaoudi/atelier-jenkins.git'
            }
        }

        stage('Build Maven') {
            steps {
                sh 'mvn clean package -Dmaven.test.failure.ignore=true'
            }
            post {
                always {
                    junit allowEmptyResults: true,
                          testResults: '**/target/surefire-reports/TEST-*.xml'
                    archiveArtifacts artifacts: 'target/*.jar'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    withCredentials([
                        string(credentialsId: 'SONAR_TOKEN', variable: 'SONAR_TOKEN')
                    ]) {
                        sh '''
                          mvn sonar:sonar \
                            -Dsonar.projectKey=student-management-app \
                            -Dsonar.token=$SONAR_TOKEN
                        '''
                    }
                }
            }
        }

        stage('Ensure Docker Network') {
            steps {
                script {
                    def net = sh(
                        script: "docker network ls -q -f name=$DOCKER_NETWORK",
                        returnStdout: true
                    ).trim()
                    if (!net) {
                        sh "docker network create $DOCKER_NETWORK"
                    }
                }
            }
        }

        stage('Ensure MySQL Container') {
            steps {
                script {
                    def running = sh(
                        script: "docker inspect -f '{{.State.Running}}' $MYSQL_CONTAINER || echo false",
                        returnStdout: true
                    ).trim()

                    if (running == "true") {
                        echo "MySQL already running"
                    } else {
                        sh '''
                        docker run -d --name mysql-db \
                          --network student-network \
                          -e MYSQL_ROOT_PASSWORD=rootpassword \
                          -e MYSQL_DATABASE=studentdb \
                          -e MYSQL_USER=studentuser \
                          -e MYSQL_PASSWORD=password \
                          -p 3307:3306 \
                          mysql:8
                        '''
                    }
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'DOCKER_HUB_CREDENTIALS',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh '''
                        docker build -t $DOCKER_IMAGE_NAME .
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker tag $DOCKER_IMAGE_NAME $DOCKERHUB_REPO:latest
                        docker push $DOCKERHUB_REPO:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withEnv(["KUBECONFIG=/var/lib/jenkins/.kube/config"]) {
                    sh '''
                        kubectl apply -f k8s/mysql-pv.yaml -n $K8S_NAMESPACE
                        kubectl apply -f k8s/mysql-deployment.yaml -n $K8S_NAMESPACE
                        kubectl apply -f k8s/springboot-deployment.yaml -n $K8S_NAMESPACE
                        kubectl apply -f k8s/springboot-service.yaml -n $K8S_NAMESPACE
        
                        kubectl rollout status deployment/mysql -n $K8S_NAMESPACE
                        kubectl rollout status deployment/student-app -n $K8S_NAMESPACE
                    '''
                }
            }
        }

        stage('Redeploy Application Locally (Docker)') {
            steps {
                sh '''
                    docker stop student-management-app || true
                    docker rm student-management-app || true

                    docker run -d --name student-management-app \
                      --network student-network \
                      -p 8089:8089 \
                      -e SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/studentdb \
                      -e SPRING_DATASOURCE_USERNAME=studentuser \
                      -e SPRING_DATASOURCE_PASSWORD=password \
                      $DOCKERHUB_REPO:latest
                '''
            }
        }
    }

    post {
        success {
            echo "✅ App is running locally at http://localhost:8089/student and deployed to Kubernetes at namespace '$K8S_NAMESPACE'"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}
