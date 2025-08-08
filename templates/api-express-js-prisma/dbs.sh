#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

mkdir -p $PROJECT_DIR/prisma

cat > "$PROJECT_DIR/prisma/schema.prisma" <<EOL
// This is your Prisma schema file,
// learn more about it in the docs: https://pris.ly/d/prisma-schema

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
  username  String?
  password  String
  role      Int      @default(1)
  picture   String
  enabled   Boolean  @default(true)
  createdAt DateTime @default(now())
}
EOL