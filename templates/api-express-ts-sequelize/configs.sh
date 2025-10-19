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
  DatabaseUrl: getStringEnv('DATABASE_URL', ''),
  Secret: getStringEnv('JWT_SECRET',''),
  ExpiresIn: getStringEnv('JWT_EXPIRES_IN', '1')
}
export default envConfig
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Crear archivo de configuracion de base de datos Mongodb
cat > "$PROJECT_DIR/src/Configs/database.ts" <<EOL
import { Sequelize } from 'sequelize'
import envConfig from './envConfig.js'
import models from '../../Models/index.js'

const sequelize = new Sequelize(envConfig.DatabaseUrl, {
  logging: false,
  native: false
})

Object.values(models).forEach((modelDef) => {
  modelDef(sequelize)
})

const { User } = sequelize.models
// Relations here below:

// ------------------------
//    Initilization database:
// -------------------------
async function startUp (syncDb: boolean = false, rewrite: boolean = false) {
  try {
    await sequelize.authenticate()
    if (envConfig.Status !== 'production' && syncDb) {
      try {
        await sequelize.sync({ force: rewrite })
        console.log(\`🧪 Synced database: "force \${rewrite}"\`)
      } catch (error) {
        console.error('❗Error syncing database', error)
      }
    }
    console.log('🟢​ Database postgreSQL initialized successfully!!')
  } catch (error) {
    console.error('❌ Error conecting database!', error)
  }
}
const closeDatabase = async () => {
  await sequelize.close()
  console.log('🛑 Database disconnect')
}

export { startUp, closeDatabase, sequelize, User }
EOL

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Crear archivo de test para entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.ts" <<EOL
import {describe, it, expect, beforeAll, afterAll } from 'vitest'
import envConfig from './envConfig.js'
import {User, startUp, closeDatabase} from './database.js'

describe('Environment variables', () => {
  it('should return the correct environment status and database variable', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${envConfig.Status}\n\` +
                   \`Base de datos de testing: \${envConfig.DatabaseUrl}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: postgres://postgres:password@localhost:5432/testing')
  })
})
describe('Database existence', () => {
  beforeAll(async()=>{
    await startUp(true, true)
  })
  afterAll(async()=>{
    await closeDatabase()
  })
   it('should query tables and return an empty array', async() => { 
      const models = [User];
   for (const model of models) {
     const records = await model.findAll();
     expect(Array.isArray(records)).toBe(true);
     expect(records.length).toBe(0);
   }
   })
 })
EOL
