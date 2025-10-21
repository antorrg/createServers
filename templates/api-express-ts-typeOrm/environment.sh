#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo .env
cat > "$PROJECT_DIR/.env.production" <<EOL
PORT=3001
DATABASE_PASSWORD=password
DATABASE_NAME=testing
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://picsum.photos/200?random=16"
EOL
# Crear el archivo .env.example
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=
DATABASE_PASSWORD=password
DATABASE_NAME=testing
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG=
EOL
# Crear el archivo .env.development
cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DATABASE_PASSWORD=password
DATABASE_NAME=testing
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://picsum.photos/200?random=16"
EOL
# Crear el archivo .env.test
cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DATABASE_PASSWORD=password
DATABASE_NAME=testing
JWT_EXPIRES_IN=1
JWT_SECRET=33efe89c6429651a86f9e38e20e7a24400bbef0ba77b559491158de691a7b7f8
USER_IMG="https://urlimageprueba.net"
EOL