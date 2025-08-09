#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivos de entorno
cat > "$PROJECT_DIR/.env.production" <<EOL
PORT=3000
DATABASE_URL=mongodb://127.0.0.1:27017/herethenameofdb
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL

cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DATABASE_URL=mongodb://127.0.0.1:27017/herethenameofdb
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL

cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DATABASE_URL=mongodb://127.0.0.1:27017/herethenameofdb
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=
DATABASE_URL=mongodb://127.0.0.1:27017/herethenameofdb
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL
