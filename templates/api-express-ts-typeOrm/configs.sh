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
  DbPass: getStringEnv('DATABASE_PASSWORD', ''),
  DbName: getStringEnv('DATABASE_NAME', ''),
  Secret: getStringEnv('JWT_SECRET', ''),
  ExpiresIn: getStringEnv('JWT_EXPIRES_IN', '1')

}
export default envConfig
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Crear archivo de configuracion de base de datos Mongodb
cat > "$PROJECT_DIR/src/Configs/database.ts" <<EOL
import { DataSource } from 'typeorm'
import envConfig from './envConfig.js'
import entIndex from '../../Models/index.entities.js'

const AppDataSource = new DataSource({
  type: 'postgres',
  host: 'localhost',
  port: 5432,
  username: 'postgres',
  password: envConfig.DbPass,
  database: envConfig.DbName,
  dropSchema: false,
  synchronize: false,
  logging: false,
  entities: entIndex,
  subscribers: [],
  migrations: []
})
async function startUp (sync: boolean = false, drop: boolean = false) {
  try {
    if (envConfig.Status !== 'production') {
      AppDataSource.setOptions({
        synchronize: sync,
        dropSchema: drop
      })

      if (sync || drop)console.log(\`🧪 Database \${AppDataSource.options.database} options: sync: \${AppDataSource.options.synchronize}, drop:\${AppDataSource.options.dropSchema})\`)
    }
    await AppDataSource.initialize()
    console.log(
        \`🟢​  Database \${AppDataSource.options.database} initialized successfully! \n\`)
  } catch (error) {
    console.error(\`❌ Error initializing \${AppDataSource.options.database}:\`, error)
  }
}
async function closeDatabase () {
  if (AppDataSource.isInitialized) {
    await AppDataSource.destroy()
    console.log('🛑 Database disconnect')
  }
}
export { startUp, closeDatabase, AppDataSource }
EOL

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Crear archivo de test para entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.ts" <<EOL
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import envConfig from './envConfig.js'
import { AppDataSource, startUp, closeDatabase } from './database.js'
import entIndex from '../../Models/index.entities.js'

describe('Environment variables', () => {
  it('should return the correct environment status and database variable', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${envConfig.Status}\n\` +
                   \`Base de datos de testing: \${envConfig.DbName}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: testing')
  })
})

describe('Database existence', () => {
  beforeAll(async () => {
    await startUp(true, true)
  })
  afterAll(async () => {
    await closeDatabase()
  })
  it('should query tables and return an empty array', async () => {
    const models = entIndex
    for (const model of models) {
      const records = await AppDataSource.getRepository(model).find()
      expect(Array.isArray(records)).toBe(true)
      expect(records.length).toBe(0)
    }
  })
})
EOL
