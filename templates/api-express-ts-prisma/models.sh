#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la base de modelos
mkdir -p "$PROJECT_DIR/prisma"
cat > "$PROJECT_DIR/prisma/schema.prisma" <<EOL
// This is your Prisma schema file,
// learn more about it in the docs: https://pris.ly/d/prisma-schema

// Looking for ways to speed up your queries, or scale easily with your serverless or edge functions?
// Try Prisma Accelerate: https://pris.ly/cli/accelerate-init

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  password  String
  nickname  String
  name      String?
  picture   String
  enabled   Boolean  @default(true)
  createdAt DateTime @default(now())
}
EOL
