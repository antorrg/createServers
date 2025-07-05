#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHAREDJS_DIR="$SCRIPT_DIR/../sharedJs"

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Configs,Shared,Shared/Middlewares,Shared/Middlewares/testHelpers,Shared/Controllers,Shared/Auth,Shared/Auth/testHelpers,Shared/Services,Shared/Repositories,Shared/Repositories/testHelpers,Shared/Swagger,Shared/Swagger/schemas,Shared/Swagger/schemas/tools,Shared/Swagger/schemas/components,Features,Features/user,Features/product,Features/user/testHelpers,Features/userSeed}
mkdir -p $PROJECT_DIR/test/testHelpers

source "$SHAREDJS_DIR/auth.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/errors.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/express.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/commonJest.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/middleware.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/service.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/controller.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/swagger/swaggerOptions.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/swagger/schemaJson.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/swagger/schema.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/swagger/generateSchema.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/swagger/generateComponent.sh" "$PROYECTO_VALIDO"
source "$SHAREDJS_DIR/packages.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/configs.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/environment.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/index.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/feature.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/jest.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/repository.sh" "$PROYECTO_VALIDO"
source "$SCRIPT_DIR/readme.sh" "$PROYECTO_VALIDO"

# Mensaje de confirmación
echo "Estructura de la aplicación Express creada en '$PROJECT_DIR'."

# Ir a la carpeta del PROJECT_DIR
cd $PROJECT_DIR

# Instalar dependencias
spinner() {
  local pid=$!
  local spin='|/-\'
  local i=0
  tput civis  # Oculta el cursor
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\rInstalando dependencias... %s" "${spin:$i:1}"
    sleep 0.2
  done
  printf "\rInstalando dependencias... ✔️\n"
  tput cnorm  # Muestra el cursor
}
echo "Instalando dependencias:..."
npm install cross-env@latest cors@latest dotenv@latest express@latest helmet@latest morgan@latest @prisma/client@latest prisma@latest uuid@latest
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install @babel/core @babel/preset-env babel-jest nodemon@latest standard@latest supertest@latest jest@latest swagger-jsdoc swagger-ui-express inquirer -D
  
echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."



