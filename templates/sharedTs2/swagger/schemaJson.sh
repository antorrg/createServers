#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

mkdir -p $PROJECT_DIR/src/Shared/Swagger/schemas/components
# Crear archivo json para user
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/components/user.schema.json" <<EOL
{
  "User": {
    "type": "object",
    "properties": {
      "id": {
        "type": "string"
      },
      "email": {
        "type": "string",
        "example": "usuarioadmin@hotmail.com"
      },
      "password": {
        "type": "string",
        "example": "D12345678"
      },
      "nickname": {
        "type": "string",
        "example": "usuarioadmin"
      },
      "picture": {
        "type": "string",
        "example": "https:/image.com"
      },
      "name": {
        "type": "string",
        "example": "email"
      },
      "surname": {
        "type": "string",
        "example": "user"
      },
      "country": {
        "type": "string",
        "example": "argentina"
      },
      "role": {
        "type": "string",
        "example": "Admin"
      },
      "enabled": {
        "type": "boolean",
        "example": true
      },
      "isVerify": {
        "type": "boolean",
        "example": true
      }
    },
    "required": [
      "id",
      "email",
      "password",
      "role",
      "enabled",
      "isVerify"
    ]
  }
}
EOL