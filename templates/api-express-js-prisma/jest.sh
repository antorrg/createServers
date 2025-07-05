#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo jest.setup en test
cat > "$PROJECT_DIR/test/jest.setup.js" <<EOL
/*import { PrismaClient } from '@prisma/client'
import { execSync } from 'child_process'

// global.__db_initialized = false; // Variable global para controlar la inicialización
const prisma = new PrismaClient()

export async function resetDatabase () {
  try {
    console.log('🔄 Reiniciando la base de datos para pruebas...')

    await prisma.\$disconnect() // Cierra cualquier conexión activa
    execSync('npx prisma migrate reset --force', { stdio: 'inherit' })
    console.log('✔️ Base de datos restablecida con éxito')
  } catch (error) {
    console.error('❌ Error al reiniciar la base de datos:', error)
  }
}
export async function initializeDatabase () {
  try {
    await prisma.\$connect()
    console.log('🧪 Conectando prisma')
  } catch (error) {
    console.error('❌ Error al iniciar la base de datos:', error)
  }
}
beforeAll(async () => {
  await initializeDatabase()
})

afterAll(async () => {
  await resetDatabase()
  await prisma.\$disconnect()
  console.log('🛑 Cerrando conexión con la base de datos.')
})*/
EOL