#!/bin/bash

# Obtener la ruta absoluta del script
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$BASE_DIR/templates"

# Definir la carpeta donde se creará el proyecto (un nivel arriba)
DEST_DIR="$(dirname "$BASE_DIR")"
echo $DEST_DIR
echo "Introduzca el nombre del proyecto:"
read name

PROYECTO="${1:-$name}"

# 1️⃣ Función para validar y limpiar el nombre del proyecto
validar_nombre_proyecto() {
  local nombre="$1"
  nombre=$(echo "$nombre" | tr -d ' ' | tr -cd 'a-zA-Z0-9-_')  # Quita espacios y caracteres inválidos

  if [[ -z "$nombre" ]]; then
    echo "Error: Nombre de proyecto inválido. Debe contener al menos una letra o número."
    exit 1
  fi

  echo "$nombre"
}

# 2️⃣ Función para formatear el nombre para package.json
formatear_nombre_package() {
  echo "$1" | tr '[:upper:]' '[:lower:]'  # Convierte a minúsculas
}

# 🔄 Aplicar funciones
PROYECTO_VALIDO=$(validar_nombre_proyecto "$PROYECTO")
PROYECTO_PACKAGE=$(formatear_nombre_package "$PROYECTO_VALIDO")

echo "¿Con que lenguaje quiere trabajar?"
echo "1) JavaScript"
echo "2) TypeScript"
read lenguaje

case $lenguaje in
  1)
    LENGUAJE="js"
    ;;
  2)
    LENGUAJE="ts"
    ;;
  *)
    echo "Opción no válida. Se usará JavaScript por defecto."
    LENGUAJE="js"
    ;;
esac
if [ "$LENGUAJE" = "js" ]; then

echo "Seleccione el tipo de API:"
echo "1) Express.js API Basica (solo CRUD)"
echo "2) Express.js con Prisma "
echo "3) Express.js con Sequelize (Postgres)"
echo "4) Express.js con Mongoose"
echo "5) Express.js con Sequelize (Postgres) Paradigma funcional"
echo "6) Fastify.js con Prisma"
echo "7) Otro (próximamente)"
read opcion

TEMPLATES_DIR="./templates"  # Ruta a los templates

case $opcion in
  1)
    source "$TEMPLATES_DIR/api-express-basic.sh" "$PROYECTO_VALIDO"
    ;;
  2)
    source "$TEMPLATES_DIR/api-express-js-prisma/main.sh" "$PROYECTO_VALIDO"
    ;;
  3)
    source "$TEMPLATES_DIR/api-express-js-sequelize/main.sh" "$PROYECTO_VALIDO"
    ;;
  4)
    source "$TEMPLATES_DIR/api-express-js-mongoose/main.sh" "$PROYECTO_VALIDO"
    ;;
  5)
    source "$TEMPLATES_DIR/api-express-seqFunction.sh" "$PROYECTO_VALIDO"
    ;;
  6)
    source "$TEMPLATES_DIR/api-fastify-prisma.sh" "$PROYECTO_VALIDO"
    ;;
  7)
    source "$TEMPLATES_DIR/api-express-js-prisma/main.sh" "$PROYECTO_VALIDO"
    ;;
  *)
    echo "Opción no válida."
    ;;
esac

else
echo "Seleccione el tipo de API:"
echo "1) Express.ts con Mongoose"
echo "2) Express.ts con TypeOrm (Postgres)"
echo "3) Otro (próximamente)"
read opcion

TEMPLATES_DIR="./templates"  # Ruta a los templates

case $opcion in
    1) source "$TEMPLATES_DIR/api-express-ts-mongoose/main.sh" "$PROYECTO_VALIDO" ;;
    2) source "$TEMPLATES_DIR/api-express-type-typeOrm/main.sh" "$PROYECTO_VALIDO" ;;
    3) source "$TEMPLATES_DIR/api-express-type-typeOrm/main.sh" "$PROYECTO_VALIDO" ;;
    4) echo "Opción aún no implementada." ;;
    *) echo "Opción no válida." ;;
  esac
fi
