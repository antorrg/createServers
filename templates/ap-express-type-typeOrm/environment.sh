#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo .env
cat > "$PROJECT_DIR/.env" <<EOL
PORT=3000
DB_PASSWORD=password 
DB_NAME=typeormbase
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://firebasestorage.googleapis.com/v0/b/proyectopreact.appspot.com/o/images%2F1729212207478-silueta.webp?alt=media&token=f0534af7-2df4-4efc-af99-f3f44bf72926"
USER_ROOT_EMAIL=usuarioadmin@hotmail.com
USER_ROOT_PASS=D12345678
EOL
# Crear el archivo .env.example
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=
DB_PASSWORD=
DB_NAME=
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG=
USER_ROOT_EMAIL=
USER_ROOT_PASS=
EOL
# Crear el archivo .env.development
cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DB_PASSWORD=password
DB_NAME=typeormbase
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://firebasestorage.googleapis.com/v0/b/proyectopreact.appspot.com/o/images%2F1729212207478-silueta.webp?alt=media&token=f0534af7-2df4-4efc-af99-f3f44bf72926"
USER_ROOT_EMAIL=usuarioadmin@hotmail.com
USER_ROOT_PASS=D12345678
EOL
# Crear el archivo .env.test
cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DB_PASSWORD=password
DB_NAME=testing
JWT_EXPIRES_IN=1
JWT_SECRET=33efe89c6429651a86f9e38e20e7a24400bbef0ba77b559491158de691a7b7f8
USER_IMG="https://urlimageprueba.net"
USER_ROOT_EMAIL=usuarioadmin@hotmail.com
USER_ROOT_PASS=D12345678
EOL