#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo package.json
cat > "$PROJECT_DIR/package.json" <<EOL
{
  "name": "$PROYECTO_PACKAGE",
  "version": "1.0.0",
  "description": "Una aplicación Express generada con Bash",
  "main": "index.js",
  "type": "module",
  "scripts": {
    "start": "cross-env NODE_ENV=production node index.js",
    "dev": "cross-env NODE_ENV=development nodemon index.js",
    "unit:test": "cross-env NODE_ENV=test jest --selectProjects unit --detectOpenHandles",
    "integration:test": "cross-env NODE_ENV=test jest --selectProjects integration --detectOpenHandles",
    "lint": "standard --fix",
    "gen:schema": "node src/Shared/Swagger/schemas/tools/generateSchema.js",
    "validate:schema": "validate-schema"
  },
  "dependencies": {
  },
  "devDependencies": {
  },
   "babel": {
    "env": {
      "test": {
        "presets": [
          "@babel/preset-env"
        ]
      }
    }
  },
  "eslintConfig": {
    "extends": "./node_modules/standard/eslintrc.json"
  }
}
EOL
