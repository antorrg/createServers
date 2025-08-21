#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo de configuración dotenv
cat > "$PROJECT_DIR/src/Configs/envConfig.js" <<EOL
import dotenv from 'dotenv'
import fs from 'fs'

const configEnv = {
  development: '.env.development',
  production: '.env.production',
  test: '.env.test'
}
const envFile = configEnv[process.env.NODE_ENV] || '.env.development'
dotenv.config({ path: envFile })

const Status = Object.keys(configEnv).find(key => configEnv[key] === envFile) || 'production'
const { PORT, DATABASE_URL, LOG_ERRORS, JWT_EXPIRES_IN, JWT_SECRET, USER_IMG } = process.env
// Generar el archivo .env dinámico para Prisma
if (process.env.NODE_ENV !== 'production') {
  fs.writeFileSync(
    '.env',
    \`PORT=\${PORT}\nDATABASE_URL=\${DATABASE_URL}\`
  )
}

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
import { PrismaClient } from '@prisma/client'
import env from './envConfig.js'

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: env.DatabaseUrl // Url base de datos segun entorno.
    }
  }
})

const startApp = async () => {
  try {
    await prisma.\$connect()
    console.log('🧪 Conexión a Postgres establecida con Prisma.')
  } catch (error) {
    console.error('❌ Error al conectar con Prisma:', error.message)
  }
}

export {
  prisma,
  startApp,
}
EOL

# Crear archivo de test de entorno y db
cat > "$PROJECT_DIR/test/Configs/EnvDb.test.js" <<EOL
import env from '../../src/Configs/envConfig.js'
import { prisma } from '../../src/Configs/database.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.js" y existencia de tablas en DB.', () => {
  afterAll(() => {
    console.log('Finalizando todas las pruebas...')
  })

  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${env.Status}\n\` +
                   \`Base de datos de testing: \${env.DatabaseUrl}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: postgresql://postgres:antonio@localhost:5432/prismatest')
  })
  it('deberia hacer un get a las tablas y obtener un arreglo vacio', async () => {
    const models = [
      prisma.user
    ]
    for (const model of models) {
      const records = await model.findMany()
      expect(Array.isArray(records)).toBe(true)
      expect(records.length).toBe(0)
    }
  })
})
EOL
#Crear archivo jest.setup.js
cat > "$PROJECT_DIR/test/jest.setup.js" <<EOL
import {prisma } from '../src/Configs/database.js'
import { execSync } from 'child_process'


const initializeDatabase = async () => { // Solo tests (borra la db)
  try {
    await prisma.\$connect()
    execSync('npx prisma db push --force-reset', { stdio: 'inherit' })
    console.log('🧪 Conectando prisma')
  } catch (error) {
    console.error('❌ Error al iniciar la base de datos:', error)
  }
}

const closeDatabase = async () => {
  try {
    await prisma.\$disconnect()
    console.log('🛑 Cerrando conexión con la base de datos.')
  } catch (error) {
    console.error('❌ Error al cerrar la base de datos:', error)
  }
}

export {
  prisma,  
  initializeDatabase,
  closeDatabase
}
EOL