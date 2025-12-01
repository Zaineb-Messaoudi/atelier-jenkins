pipeline {
    agent any

    tools {
        maven "M2_HOME"
    }

    triggers {
        githubPush()
    }

    environment {
        DOCKER_APP_NAME = "student-management-app"
        DOCKER_IMAGE_NAME = "student-management-student-app"
        MYSQL_CONTAINER = "mysql-db"
        MYSQL_ROOT_PASSWORD = "rootpassword"
        MYSQL_DB = "studentdb"
        MYSQL_USER = "studentuser"
        MYSQL_PASSWORD = "password"
        APP_PORT = "8089"
        MYSQL_PORT = "3307"
        DOCKER_NETWORK = "student-network"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Zaineb-Messaoudi/atelier-jenkins.git'
            }
        }

        stage('Build Maven') {
            steps {
                sh "mvn clean package -Dmaven.test.failure.ignore=true"
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/TEST-*.xml'
                    archiveArtifacts 'target/*.jar'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {  // Name must match Jenkins SonarQube server config
                    sh "mvn sonar:sonar -Dsonar.projectKey=student-management-app"
                }
            }
        }

        stage('Ensure Docker Network') {
            steps {
                script {
                    def networkExists = sh(script: "docker network ls -q -f name=$DOCKER_NETWORK", returnStdout: true).trim()
                    if (!networkExists) {
                        sh "docker network create $DOCKER_NETWORK"
                    } else {
                        echo "Docker network '$DOCKER_NETWORK' already exists."
                    }
                }
            }
        }

        stage('Ensure MySQL Container') {
            steps {
                script {
                    def status = sh(script: "docker inspect -f '{{.State.Running}}' $MYSQL_CONTAINER || echo false", returnStdout: true).trim()
                    if (status == "true") {
                        echo "MySQL container is already running."
                    } else if (status == "false") {
                        echo "Starting existing MySQL container..."
                        sh "docker start $MYSQL_CONTAINER"
                    } else {
                        echo "Creating MySQL container..."
                        sh """
                        docker run -d --name $MYSQL_CONTAINER --network $DOCKER_NETWORK \
                            -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
                            -e MYSQL_DATABASE=$MYSQL_DB \
                            -e MYSQL_USER=$MYSQL_USER \
                            -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
                            -p $MYSQL_PORT:3306 \
                            mysql:8
                        """
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t $DOCKER_IMAGE_NAME ."
                }
            }
        }

        stage('Redeploy Application') {
            steps {
                script {
                    echo "Stopping and removing old application container if exists..."
                    sh "docker stop $DOCKER_APP_NAME || true"
                    sh "docker rm $DOCKER_APP_NAME || true"

                    echo "Starting new application container..."
                    sh """
                    docker run -d --name $DOCKER_APP_NAME --network $DOCKER_NETWORK \
                        -p $APP_PORT:8089 \
                        -e SPRING_DATASOURCE_URL=jdbc:mysql://$MYSQL_CONTAINER:3306/$MYSQL_DB?createDatabaseIfNotExist=true \
                        -e SPRING_DATASOURCE_USERNAME=$MYSQL_USER \
                        -e SPRING_DATASOURCE_PASSWORD=$MYSQL_PASSWORD \
                        $DOCKER_IMAGE_NAME
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! Application is running on http://localhost:${APP_PORT}/student"
        }
        failure {
            echo "Build or deployment failed."
        }
    }
}
