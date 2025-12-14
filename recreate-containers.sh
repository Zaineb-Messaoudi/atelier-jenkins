#!/bin/bash
set -e

# Variables (matching Jenkinsfile)
DOCKER_NETWORK="student-network"
MYSQL_CONTAINER="mysql-db"
MYSQL_ROOT_PASSWORD="rootpassword"
MYSQL_DB="studentdb"
MYSQL_USER="studentuser"
MYSQL_PASSWORD="password"
APP_CONTAINER="student-management-app"
APP_IMAGE="student-management-student-app"
APP_PORT=8089
MYSQL_PORT=3307

echo "=== Step 1: Ensure Docker network ==="
if ! docker network ls -q -f name="$DOCKER_NETWORK" >/dev/null; then
    docker network create "$DOCKER_NETWORK"
    echo "Docker network '$DOCKER_NETWORK' created."
else
    echo "Docker network '$DOCKER_NETWORK' already exists."
fi

echo "=== Step 2: Ensure MySQL container ==="
if [ "$(docker ps -aq -f name=$MYSQL_CONTAINER)" ]; then
    echo "MySQL container exists, starting it..."
    docker start $MYSQL_CONTAINER
else
    echo "Creating MySQL container..."
    docker run -d --name $MYSQL_CONTAINER --network $DOCKER_NETWORK \
        -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
        -e MYSQL_DATABASE=$MYSQL_DB \
        -e MYSQL_USER=$MYSQL_USER \
        -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
        -p $MYSQL_PORT:3306 \
        -v mysql-data:/var/lib/mysql \
        mysql:8
fi

echo "=== Step 3: Build student-management app image ==="
cd ~/Téléchargements/Projet-DevOps/Projet-5ème/student-management
mvn clean package -Dmaven.test.failure.ignore=true
docker build -t $APP_IMAGE .

echo "=== Step 4: Ensure student-management app container ==="
if [ "$(docker ps -aq -f name=$APP_CONTAINER)" ]; then
    echo "Stopping and removing old app container..."
    docker stop $APP_CONTAINER || true
    docker rm $APP_CONTAINER || true
fi

echo "Starting new student-management app container..."
docker run -d --name $APP_CONTAINER --network $DOCKER_NETWORK \
    -p $APP_PORT:8089 \
    -e SPRING_DATASOURCE_URL=jdbc:mysql://$MYSQL_CONTAINER:3306/$MYSQL_DB?createDatabaseIfNotExist=true \
    -e SPRING_DATASOURCE_USERNAME=$MYSQL_USER \
    -e SPRING_DATASOURCE_PASSWORD=$MYSQL_PASSWORD \
    $APP_IMAGE

echo "=== Step 5: Status check ==="
docker ps
echo "All done! App is running on http://localhost:$APP_PORT/student"
