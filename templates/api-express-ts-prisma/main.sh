#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHAREDTS_DIR="$SCRIPT_DIR/../sharedTs2"

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Configs,@types,Shared}
mkdir -p $PROJECT_DIR/test/testHelpers

source "$SHAREDTS_DIR/auth.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/configs.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/errors.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/controller.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/environment.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/express.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/index.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/feature.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/vitest.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/commonTest.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/models.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/repository.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/service.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/testService.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/swagger/swaggerOptions.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/swagger/schemaJson.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/swagger/schema.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/swagger/generateSchema.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/swagger/generateComponent.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/packages.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/readme.sh" "$PROYECTO_VALIDO"

# Mensaje de confirmación
echo "Estructura de la aplicación Express creada en '$PROJECT_DIR'."

# Ir a la carpeta del PROJECT_DIR
cd $PROJECT_DIR

# Instalar dependencias
echo "Instalando dependencias:..."
npm install bcrypt cors cross-env dotenv express jsonwebtoken prisma @prisma/client pg morgan req-valid-express
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install -D typescript tsx @types/bcrypt @types/cors @types/dotenv @types/express @types/inquirer @types/jsonwebtoken @types/mongoose @types/morgan @types/supertest @types/swagger-jsdoc @types/swagger-ui-express inquirer vitest supertest swagger-jsdoc swagger-ui-express @typescript-eslint/eslint-plugin @typescript-eslint/parser eslint eslint-config-standard-with-typescript
echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."



