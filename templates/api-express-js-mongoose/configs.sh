#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo de configuración dotenv
cat > "$PROJECT_DIR/src/Configs/envConfig.js" <<EOL
import dotenv from 'dotenv'

const configEnv = {
  development: '.env.development',
  production: '.env.production',
  test: '.env.test'
}
const envFile = configEnv[process.env.NODE_ENV] || '.env.development'
dotenv.config({ path: envFile })

const Status = Object.keys(configEnv).find(key => configEnv[key] === envFile) || 'production'
const { PORT, DATABASE_URL, LOG_ERRORS, JWT_EXPIRES_IN, JWT_SECRET, USER_IMG } = process.env

export default {
  Port: PORT,
  DatabaseUrl: DATABASE_URL,
  LogErrors: LOG_ERRORS,
  Status,
  ExpiresIn: JWT_EXPIRES_IN,
  Secret: JWT_SECRET,
  UserImg: USER_IMG
}
EOL
# Crear archivo de configuracion de base de datos Prisma
cat > "$PROJECT_DIR/src/Configs/database.js" <<EOL
import mongoose from 'mongoose'
import env from './envConfig.js'

const connectDB = async () => {
  try {
    await mongoose.connect(env.DatabaseUrl)
    console.log(\`Connecting database "\${nameOfDb(env.DatabaseUrl)}"\`)
  } catch (error) {
   throw error
  }
}
function nameOfDb(name){
 return name.split('/')[3]
}

const startApp = async (reset=false) => {
  try {
    await connectDB();
    if(reset === true){
      await mongoose.connection.dropDatabase();
      console.log('✔️  Database reseted successfully!!')
    }
    console.log('🟢 Connection to MongoDb established with Mongoose')
  } catch (error) {
    console.error('❌ Error connecting to Mongoose:', error.message)
  }
}

const closeDatabase = async () => {
  try {
    await mongoose.disconnect()
    console.log('🛑 Closing connection to database.')
  } catch (error) {
    console.error('❌ Error closing database:', error)
  }
}


export {
  startApp,
  closeDatabase
}
EOL

# Crear archivo de test de entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.js" <<EOL
import env from './envConfig.js'
import {startApp, closeDatabase} from './database.js'
import User from '../../models/user.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.js" y existencia de tablas en DB.', () => {
  beforeAll(async() => {
    await startApp(true)
  })
  afterAll(async()=>{
    await closeDatabase()
  })

  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${env.Status}\n\` +
                   \`Base de datos de testing: \${env.DatabaseUrl}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: mongodb://127.0.0.1:27017/herethenameofdb')
  })
  it('deberia hacer un get a las tablas y obtener un arreglo vacio', async () => {
    const models = [
      User
    ]
    for (const model of models) {
      const records = await model.find()
      expect(Array.isArray(records)).toBe(true)
      expect(records.length).toBe(0)
    }
  })
})
EOL