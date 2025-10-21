#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo .env
cat > "$PROJECT_DIR/.env.production" <<EOL
PORT=3001
DATABASE_URL="postgresql://postgres:password@localhost:5432/prismatest"
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://picsum.photos/200?random=16"
EOL
# Crear el archivo .env.example
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=
DATABASE_URL="postgresql://postgres:password@localhost:5432/prismatest"
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG=
EOL
# Crear el archivo .env.development
cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DATABASE_URL="postgresql://postgres:password@localhost:5432/prismatest"
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://picsum.photos/200?random=16"
EOL
# Crear el archivo .env.test
cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DATABASE_URL="postgresql://postgres:password@localhost:5432/prismatest"
JWT_EXPIRES_IN=1
JWT_SECRET=33efe89c6429651a86f9e38e20e7a24400bbef0ba77b559491158de691a7b7f8
USER_IMG="https://urlimageprueba.net"
EOL

cat > "$PROJECT_DIR/.env" <<EOL
# Environment variables declared in this file are automatically made available to Prisma.
# See the documentation for more detail: https://pris.ly/d/prisma-schema#accessing-environment-variables-from-the-schema

# Prisma supports the native connection string format for PostgreSQL, MySQL, SQLite, SQL Server, MongoDB and CockroachDB.
# See the documentation for all the connection string options: https://pris.ly/d/connection-strings

# The following \`prisma+postgres\` URL is similar to the URL produced by running a local Prisma Postgres 
# server with the \`prisma dev\` CLI command, when not choosing any non-default ports or settings. The API key, unlike the 
# one found in a remote Prisma Postgres URL, does not contain any sensitive information.

DATABASE_URL="postgresql://postgres:password@localhost:5432/prismatest"
EOL