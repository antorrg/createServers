#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHAREDTS_DIR="$SCRIPT_DIR/../sharedTs"
echo "$SCRIPT_DIR"
# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Configs,@types,Shared,Shared/Middlewares,Shared/Middlewares/testHelpers,Shared/Controllers,Shared/Auth,Shared/Auth/testHelpers,Shared/Services,Shared/Repositories,Shared/Repositories/testHelpers,Shared/Models,Shared/Swagger,Shared/Swagger/schemas,Shared/Swagger/schemas/tools,Shared/Swagger/schemas/components,Features,Features/user,Features/product,Features/user/testHelpers,Features/userSeed}
mkdir -p $PROJECT_DIR/test/testHelpers

source "$SHAREDTS_DIR/auth.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/configs.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/errors.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/controller.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/environment.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/express.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/feature.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/jest.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/commonJest.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/middleware.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/models.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/repository.sh" "$PROYECTO_VALIDO"
source "$SHAREDTS_DIR/service.sh" "$PROYECTO_VALIDO"
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
npm install bcrypt cors cross-env dotenv express jsonwebtoken mongoose morgan uuid
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install -D typescript@5.8.3 @jest/globals @types/bcrypt @types/cors @types/dotenv @types/express @types/inquirer @types/jest @types/jsonwebtoken @types/mongoose @types/morgan @types/supertest @types/swagger-jsdoc @types/swagger-ui-express inquirer jest supertest swagger-jsdoc swagger-ui-express ts-jest ts-node ts-standard tsx
echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."



