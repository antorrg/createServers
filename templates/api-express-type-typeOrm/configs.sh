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
  DB_PASSWORD: string
  DB_NAME: string
  JWT_EXPIRES_IN: number
  JWT_SECRET: string
  USER_IMG: string
  USER_ROOT_EMAIL: string
  USER_ROOT_PASS: string

}

// Función para obtener y validar las variables de entorno
function getEnvConfig (): EnvVariables {
  return {
    PORT: parseInt(process.env.PORT || '3000', 10),
    NODE_ENV: process.env.NODE_ENV || 'production',
    DB_PASSWORD: process.env.DB_PASSWORD || '',
    DB_NAME: process.env.DB_NAME || '',
    JWT_EXPIRES_IN: parseInt(process.env.JWT_EXPIRES_IN || '1', 10),
    JWT_SECRET: process.env.JWT_SECRET || '',
    USER_IMG: process.env.USER_IMG || '',
    USER_ROOT_EMAIL: process.env.USER_ROOT_EMAIL ||'',
    USER_ROOT_PASS: process.env.USER_ROOT_PASS || '',
  }
}

// Obtener el estado del entorno
const status: string = Object.keys(configEnv).find(
  (key) => configEnv[key] === envFile
) || 'production'

// Creamos la configuración final
const envConfig = {
  Port: getEnvConfig().PORT,
  Status: status,
  DbPass: getEnvConfig().DB_PASSWORD,
  DbName: getEnvConfig().DB_NAME,
  ExpiresIn: getEnvConfig().JWT_EXPIRES_IN,
  Secret: getEnvConfig().JWT_SECRET,
  UserImg: getEnvConfig().USER_IMG,
  UserRootEmail: getEnvConfig().USER_ROOT_EMAIL,
  UserRootPass: getEnvConfig().USER_ROOT_PASS,

}

export default envConfig
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Crear archivo de configuracion de base de datos Mongodb
cat > "$PROJECT_DIR/src/Configs/dataSource.ts" <<EOL
import 'reflect-metadata'
import { DataSource } from 'typeorm'
import envConfig from './envConfig.js'
import { User } from '../Shared/Entities/user.entity.js'

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: 'localhost',
  port: 5432,
  username: 'postgres',
  password: envConfig.DbPass,
  database: envConfig.DbName,
  dropSchema: false,
  synchronize: false,
  logging: false,
  entities: [User],
  subscribers: [],
  migrations: []
})

export const Starter = async () => {
  try {
    await AppDataSource.initialize()
    console.log('🟢 Data Source has been initialized! ✔️')
  } catch (error) {
    console.error('🔴 Error during Data Source initialization:')
    throw error
  }
}
EOL

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Crear archivo de test para entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.ts" <<EOL
import envConfig from './envConfig.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.ts" y existencia de tablas en DB.', () => {
  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${envConfig.Status}\n\` +
                   \`Base de datos de testing: \${envConfig.DbName}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: testing')
  })

  // it('Deberia responder a una consulta en la base de datos con un arreglo vacío', async()=>{
  //     const users = await DbUser.find()
  //     const cars = await DBCar.find()
  //     expect(users).toEqual([]);
  //     expect(cars).toEqual([])

  // });
})
EOL
