#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivos de entorno
cat > "$PROJECT_DIR/.env.production" <<EOL
PORT=3000
DATABASE_URL=postgres://postgres:password@localhost:5432/dbproduction
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL

cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DATABASE_URL=postgres://postgres:password@localhost:5432/dbDevelopment
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL

cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DATABASE_URL=postgres://postgres:password@localhost:5432/dbtest
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=
DATABASE_URL=
LOG_ERRORS=true
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG="https://urlimageprueba.net"
EOL
