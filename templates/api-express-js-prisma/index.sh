#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo index.js en src
cat > "$PROJECT_DIR/index.js" <<EOL
import app from './src/app.js'
import env from './src/Configs/envConfig.js'
// import { startApp } from './src/Configs/database.js'

app.listen(env.Port, async () => {
  try {
  // startApp()
    console.log(\`Servidor corriendo en http://localhost:\${env.Port}\nServer in \${env.Status}\`)
    if (env.Status === 'development') {
      console.log(\`Swagger: Vea y pruebe los endpoints en http://localhost:\${env.Port}/api-docs\`)
    }
  } catch (error) {
    console.error('Error conectando la DB: ', error)
  }
})
EOL

mkdir -p $PROJECT_DIR/prisma

cat > "$PROJECT_DIR/prisma/schema.prisma" <<EOL
// This is your Prisma schema file,
// learn more about it in the docs: https://pris.ly/d/prisma-schema

generator client {
  provider = "prisma-client-js"
  output   = "../src/generated/prisma"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  username  String?
  password  String
  role      Int      @default(1)
  picture   String
  enabled   Boolean  @default(true)
  createdAt DateTime @default(now())
}
EOL