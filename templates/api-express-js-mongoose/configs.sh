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
import { Sequelize } from 'sequelize'
import models from '../../models/index.js'
import env from './envConfig.js'

const sequelize = new Sequelize(env.DatabaseUrl,{
  dialect: "postgres",
  logging: false,
  native: false
})

Object.values(models).forEach((model) => model(sequelize))

const {
  User,
} = sequelize.models

//Relations here:




//-------------------------------------------------------------
const startApp = async (synced=false, forced=false) => {
  try {
    await sequelize.authenticate()
    if(synced === true){
      await sequelize.sync({force: forced})
      console.log(\`✔️  Database synced successfully!!\n Force: \${forced}\`)
    }
    console.log('🟢 Connection to Postgres established with Sequelize')
  } catch (error) {
    console.error('❌ Error connecting to Sequelize:', error.message)
    process.exit(1) // Salida con error
  }
}

const closeDatabase = async () => {
  try {
    await sequelize.close()
    console.log('🛑 Closing connection to database.')
  } catch (error) {
    console.error('❌ Error closing database:', error)
  }
}

export {
  User,
  sequelize,
  startApp,
  closeDatabase
}
EOL

# Crear archivo de test de entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.js" <<EOL
import env from './envConfig.js'
import { User, startApp, closeDatabase } from './database.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.js" y existencia de tablas en DB.', () => {
  beforeAll(async() => {
    await startApp(true, true)
  })
  afterAll(async()=>{
    await closeDatabase()
  })

  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${env.Status}\n\` +
                   \`Base de datos de testing: \${env.DatabaseUrl}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: postgres://postgres:password@localhost:5432/prismatest')
  })
  it('deberia hacer un get a las tablas y obtener un arreglo vacio', async () => {
    const models = [
      User
    ]
    for (const model of models) {
      const records = await model.findAll()
      expect(Array.isArray(records)).toBe(true)
      expect(records.length).toBe(0)
    }
  })
})
EOL