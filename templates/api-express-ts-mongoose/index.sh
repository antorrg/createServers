#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo index.ts en src
cat > "$PROJECT_DIR/index.ts" <<EOL
import app from './src/app.js'
import connectDB from './src/Configs/database.js'
import envConfig from './src/Configs/envConfig.js'
import { userSeed } from './src/Features/userSeed/userSeed.js'

app.listen(envConfig.Port, async () => {
  try {
    await connectDB()
    await userSeed()
    console.log(\`Server is listening on port \${envConfig.Port}\nServer in \${envConfig.Status}\`)
    if(envConfig.Status === 'development'){
      console.log(\`Swagger: Vea y pruebe los endpoints en http://localhost:\${envConfig.Port}/api-docs\`)
    }
  } catch (error) {
    console.error('Error conecting database: ',error)
  }
})
EOL