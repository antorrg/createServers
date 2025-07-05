#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivos de entorno
cat > "$PROJECT_DIR/.env.production" <<EOL
PORT=3000
DATABASE_URL=
EOL

cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DATABASE_URL=
EOL

cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DATABASE_URL=
EOL