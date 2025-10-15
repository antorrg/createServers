#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo de configuración dotenv
cat > "$PROJECT_DIR/src/Configs/envConfig.ts" <<EOL
import dotenv from 'dotenv'
// Configuración de archivos .env según ambiente
const configEnv: Record<string, string> = {
  development: '.env.development',
  test: '.env.test',
  production: '.env'
}
const envFile = configEnv[process.env.NODE_ENV || 'production']
// Determinamos el ambiente y archivo .env a usar
const env = process.env.NODE_ENV || 'production'

// Cargamos las variables de entorno del archivo correspondiente
dotenv.config({ path: envFile })

// Interface para las variables de entorno
interface EnvVariables {
  PORT: number
  NODE_ENV: string
  URI_DB: string
  JWT_EXPIRES_IN: number
  JWT_SECRET: string
  USER_IMG: string

  // Aquí puedes añadir más variables que necesites
}

// Función para obtener y validar las variables de entorno
function getEnvConfig (): EnvVariables {
  return {
    PORT: parseInt(process.env.PORT || '3000', 10),
    NODE_ENV: process.env.NODE_ENV || 'production',
    URI_DB: process.env.URI_DB || '',
    JWT_EXPIRES_IN: parseInt(process.env.JWT_EXPIRES_IN || '1', 10),
    JWT_SECRET: process.env.JWT_SECRET || '',
    USER_IMG: process.env.USER_IMG || ''
  }
}

// Obtenemos el estado del ambiente
const status: string = Object.keys(configEnv).find(
  (key) => configEnv[key] === envFile
) || 'production'

// Creamos la configuración final
const envConfig = {
  Port: getEnvConfig().PORT,
  Status: status,
  UriDb: getEnvConfig().URI_DB,
  ExpiresIn: getEnvConfig().JWT_EXPIRES_IN,
  Secret: getEnvConfig().JWT_SECRET,
  UserImg: getEnvConfig().USER_IMG

}

export default envConfig
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Crear archivo de configuracion de base de datos Mongodb
cat > "$PROJECT_DIR/src/Configs/database.ts" <<EOL
import { connect } from 'mongoose'
import envConfig from './envConfig.js'

// const DB_URI= \`mongodb://\${onlyOne}\`

const connectDB = async () => {
  try {
    await connect(envConfig.UriDb)
    console.log('DB conectada exitosamente ✅')
  } catch (error) {
    console.error(error + ' algo malo pasó 🔴')
  }
}

export default connectDB
EOL

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Crear archivo de test para entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.ts" <<EOL
import envConfig from './envConfig.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.ts" y existencia de tablas en DB.', () => {
  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${envConfig.Status}\n\` +
                   \`Base de datos de testing: \${envConfig.UriDb}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: mongodb://127.0.0.1:27017/herethenameofdb')
  })

  // it('Deberia responder a una consulta en la base de datos con un arreglo vacío', async()=>{
  //     const users = await DbUser.find()
  //     const cars = await DBCar.find()
  //     expect(users).toEqual([]);
  //     expect(cars).toEqual([])

  // });
})
EOL
