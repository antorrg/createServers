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