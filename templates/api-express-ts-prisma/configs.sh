#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo de configuración dotenv
cat > "$PROJECT_DIR/src/Configs/envConfig.ts" <<EOL
import dotenv from 'dotenv'

const ENV_FILE = {
  production: '.env.production',
  development: '.env.development',
  test: '.env.test'
} as const
type Environment = keyof typeof ENV_FILE
const NODE_ENV = (process.env.NODE_ENV as Environment) ?? 'production'

dotenv.config({ path: ENV_FILE[NODE_ENV] })

const getNumberEnv = (key: string, defaultValue: number): number => {
  const parsed = Number(process.env[key])
  return isNaN(parsed) ? defaultValue : parsed
}
const getStringEnv = (key: string, defaultValue: string): string => {
  return process.env[key] ?? defaultValue
}
const envConfig = {
  Port: getNumberEnv('PORT', 3000),
  Status: NODE_ENV,
  UserImg: getStringEnv('USER_IMG', ''),
  DatabaseUrl : getStringEnv('DATABASE_URL',''),
  ExpiresIn: getStringEnv('JWT_EXPIRES_IN', '1')
  Secret: getStringEnv('JWT_SECRET','')

}
export default envConfig
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Crear archivo de configuracion de base de datos Mongodb
cat > "$PROJECT_DIR/src/Configs/database.ts" <<EOL
import {PrismaClient}from '@prisma/client'
import { execSync } from 'child_process'
import envConfig from './envConfig.js'

const prisma = new PrismaClient({
    datasources: {
        db:{
            url: envConfig.DatabaseUrl
        }
        
    }
})
const nameOfDb = (): string => {
  const url = envConfig.DatabaseUrl
  if (!url) return 'unknown'
  const parts = url.split('/')
  return parts[parts.length - 1] || 'unknown'
}

async function startUp (reset:boolean = false){
  try {
    if(reset=== true && envConfig.Status==='test'){
    console.log(\`🔄 Restarting database "\${nameOfDb()}" for testing...\`)
    await prisma.\$disconnect() // Cierra cualquier conexión activa
    execSync('npx prisma migrate reset --force', { stdio: 'inherit' })
    console.log('🧪  Database restored successfully')
    }
    await prisma.\$connect()
    console.log(\`🟢​  Database "\${nameOfDb()}" initialized successfully!!\`)
  } catch (error) {
    console.error('❌ Error starting database: ', error)
  }
}

async function closeDatabase() {
  try {
    await prisma.\$disconnect()
    console.log(\`🛑 Database "\${nameOfDb()}" disconnect successfully.\`)
  } catch (error) {
    console.error('❌ Error closing database:', error)
  }
}
export {
    prisma,
    startUp,
    closeDatabase
}
EOL

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Crear archivo de test para entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.ts" <<EOL
import {describe, it, expect, beforeAll, afterAll } from 'vitest'
import envConfig from './envConfig.ts'
import {prisma, startUp, closeDatabase} from './database.ts'

const User = prisma.user

describe('EnvDb test', () => { 
 beforeAll(async()=>{
    await startUp(true)
  })
  afterAll(async()=>{
    await closeDatabase()
  })
  describe('Environment variables', () => {
    it('should return the correct environment status and database variable', () => { 
         const formatEnvInfo =
      \`Server running in: \${envConfig.Status}\n\` +
      \`Testing prisma database: \${envConfig.DatabaseUrl}\`;
    expect(formatEnvInfo).toBe(
      "Server running in: test\n" + "Testing prisma database: postgresql://postgres:password@localhost:5432/prismatest"
    );
    })
  })
  describe('Sequelize database', () => {
    it('should query tables and return an empty array', async() => { 
       const models = [User];
    for (const model of models) {
      const records = await model.findMany();
      expect(Array.isArray(records)).toBe(true);
      expect(records.length).toBe(0);
    }
    })
  })
})
EOL
