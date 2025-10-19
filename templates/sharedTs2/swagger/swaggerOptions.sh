#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"
#,Shared/Swagger,Shared/Swagger/schemas,Shared/Swagger/schemas/tools,Shared/Swagger/schemas/components,
mkdir -p $PROJECT_DIR/src/Shared/Swagger

cat > "$PROJECT_DIR/src/Shared/Swagger/swaggerOptions.ts" <<EOL
import envConfig from '../../Configs/envConfig.js'
import {loadComponentSchemas} from './loadComponents.js'
import fs from 'fs';
import path from 'path';

function getJsdocFiles(dir: string): string[] {
  const absDir = path.resolve(process.cwd(), dir);
  return fs.readdirSync(absDir)
    .filter(file => file.endsWith('.jsdoc.ts') || file.endsWith('.jsdoc.js'))
    .map(file => path.join(dir, file).replace(/\\\/g, '/'));
}
const apis = getJsdocFiles('./src/Shared/Swagger/schemas');

const swaggerOptions = {
  swaggerDefinition: {
    openapi: '3.0.0',
    info: {
      title: "$PROYECTO_VALIDO",
      version: '1.0.0',
      description: 'Documentación de la API $PROYECTO_VALIDO con Swagger. Este modelo es ilustrativo'
    },

    servers: [
      {
        url: \`http://localhost:\${envConfig.Port}\`
      }
    ],
     components: {
      schemas: loadComponentSchemas(),
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    },
    // security: [
    //   {
    //     bearerAuth: []
       //}
    //]
  },
  apis,
  swaggerOptions: {
    docExpansion: 'none' // 👈 Oculta todas las rutas al cargar
  }
}

export default swaggerOptions
EOL
#Crear archivo loadComponentsSchemas
cat > "$PROJECT_DIR/src/Shared/Swagger/loadComponents.ts" <<EOL
import fs from 'fs';
import path from 'path';

export function loadComponentSchemas(): Record<string, any> {
  const schemasDir = path.resolve(process.cwd(), 'src/Shared/Swagger/schemas/components');
  const schemaFiles = fs.readdirSync(schemasDir).filter(file => file.endsWith('.json'));

  let components: Record<string, any> = {};

  for (const file of schemaFiles) {
    const schemaPath = path.join(schemasDir, file);
    const schemaContent = JSON.parse(fs.readFileSync(schemaPath, 'utf-8'));
    Object.assign(components, schemaContent);
  }
  return components;
}
EOL