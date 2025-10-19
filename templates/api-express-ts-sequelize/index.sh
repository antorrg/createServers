#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo index.ts en src
cat > "$PROJECT_DIR/index.ts" <<EOL
import app from './src/app.js'
import { startUp } from './src/Configs/database.js'
import envConfig from './src/Configs/envConfig.js'

app.listen(envConfig.Port, async () => {
  try {
    await startUp ()
    console.log(\`Server is listening on port \${envConfig.Port}\nServer in \${envConfig.Status}\n 🚀​ Everything is allright!!\`)
    if(envConfig.Status === 'development'){
      console.log(\`Swagger: View and test the endpoints at http://localhost:\${envConfig.Port}/api-docs\`)
    }
  } catch (error) {
    console.error('Error conecting database: ',error)
  }
})
EOL