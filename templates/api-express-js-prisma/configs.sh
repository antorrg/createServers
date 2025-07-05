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
const { PORT, DATABASE_URL } = process.env
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
  Status,
}
EOL
# Crear archivo de configuracion de base de datos Prisma
cat > "$PROJECT_DIR/src/Configs/database.js" <<EOL
import { PrismaClient } from '@prisma/client'
import env from './envConfig.js'

import fs from 'fs'

const prisma = new PrismaClient()

const startApp = async () => {
  try {
    await prisma.\$connect()
    console.log('Conexión a Postgres establecida con Prisma.')
  } catch (error) {
    console.error('Error al conectar con Prisma:', error.message)
    process.exit(1) // Salida con error
  }
}

// Función para cerrar conexión y eliminar archivo .env
const gracefulShutdown = async () => {
  try {
    await prisma.\$disconnect()
    console.log('Desconexión de Prisma completa.')

    // Limpiar el archivo .env generado
    if (fs.existsSync('.env')) {
      await env.cleanEnvFile()
      console.log('Archivo .env eliminado correctamente.')
    }
    setTimeout(() => {
      console.log('Cerrando proceso.')
      process.exit(0) // Salida limpia
    }, 3000)
    // process.exit(0); // Salida limpia
  } catch (error) {
    console.error('Error al desconectar Prisma:', error.message)
    process.exit(1) // Salida con error
  }
}

export {
  prisma,
  startApp,
  gracefulShutdown
}
EOL

# Crear archivo de test de entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.js" <<EOL
import env from './envConfig.js'
import { prisma } from './database.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.js" y existencia de tablas en DB.', () => {
  afterAll(() => {
    console.log('Finalizando todas las pruebas...')
  })

  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${env.Status}\n\` +
                   \`Base de datos de testing: \${env.DatabaseUrl}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: postgresql://postgres:antonio@localhost:5432/testing')
  })
  xit('deberia hacer un get a las tablas y obtener un arreglo vacio', async () => {
    const models = [
     //prisma.example
    ]
    for (const model of models) {
      const records = await model.findMany()
      expect(Array.isArray(records)).toBe(true)
      expect(records.length).toBe(0)
    }
  })
})
EOL