#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Configs,@types,Shared,Shared/Middlewares,Shared/Middlewares/testHelpers,Shared/Controllers,Shared/Auth,Shared/Auth/testHelpers,Shared/Services,Shared/Services/testHelpers,Shared/Models,Shared/Swagger,Shared/Swagger/schemas,Shared/Swagger/schemas/tools,Shared/Swagger/schemas/components,Features,Features/user,Features/product,Features/user/testHelpers}
mkdir -p $PROJECT_DIR/test/testHelpers

# Crear el archivo index.ts en src
cat > "$PROJECT_DIR/index.ts" <<EOL
import app from './src/app.js'
import connectDB from './src/Configs/database.js'
import envConfig from './src/Configs/envConfig.js'

app.listen(envConfig.Port, async() => {
  try {
    await connectDB()
    console.log(\`Server is listening on port \${envConfig.Port}\nServer in \${envConfig.Status}\`)
    if(envConfig.Status === 'development'){
      console.log(\`Swagger: Vea y pruebe los endpoints en http://localhost:\${envConfig.Port}/api-docs\`)
    }
  } catch (error) {
    console.error('Error conecting database: ',error)
  }
})
EOL
# Crear el archivo app.ts en src
cat > "$PROJECT_DIR/src/app.ts" <<EOL
import express from 'express'
import morgan from 'morgan'
import cors from 'cors'
import eh from './Configs/errorHandlers.js'
import mainRouter from './routes.js'
import swaggerUi from 'swagger-ui-express'
import swaggerJsDoc from 'swagger-jsdoc'
import swaggerOptions from './Shared/Swagger/swaggerOptions.js'
import envConfig from './Configs/envConfig.js'


const swaggerDocs = swaggerJsDoc(swaggerOptions)
const swaggerUiOptions = {
  swaggerOptions: {
    docExpansion: 'none' // 👈 Oculta todas las rutas al cargar
  }
}
const app = express()
app.use(morgan('dev'))
app.use(cors())
app.use(express.json())
app.use(eh.jsonFormat)
if (envConfig.Status === 'development') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocs, swaggerUiOptions))
}
app.use(mainRouter)
app.use(eh.notFoundRoute)
app.use(eh.errorEndWare)

export default app
EOL
# Crear el archivo @types en src
cat > "$PROJECT_DIR/src/@types/index.d.ts" <<EOL
import { JwtPayload } from '../Shared/Auth/auth.ts'

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload
      userInfo?: { userId?: string, userRole?: number }
    }
  }
}
EOL
# Crear el archivo routes.ts en src
cat > "$PROJECT_DIR/src/routes.ts" <<EOL
import { Router } from 'express'
import userRouter from './Features/user/user.route.js'

const mainRouter = Router()

mainRouter.use('/api/v1/user', userRouter)

export default mainRouter
EOL
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
# Crear archivo de manejo de errores de Express
cat > "$PROJECT_DIR/src/Configs/errorHandlers.ts" <<EOL
import { Request, Response, NextFunction } from 'express'
import envConfig from './envConfig.js'

type Controller = (req: Request, res: Response, next: NextFunction) => Promise<any>

class CustomError extends Error {
  public log: boolean
  constructor (log: boolean = false) {
    super()
    this.log = log
    Object.setPrototypeOf(this, CustomError.prototype)
  }

  throwError (message: string, status: number, err: Error | null = null): never {
    const error = new Error(message) as Error & { status?: number }
    error.status = Number(status) || 500
    if (this.log && (err != null)) {
      console.error('Error: ', err)
    }
    throw error
  }

  processError (err: Error & { status?: number, [key: string]: any }, contextMessage: string): never {
    const defaultStatus = 500
    const status = err.status || defaultStatus

    const message = err.message
      ? \`\${contextMessage}: \${err.message}\`
      : contextMessage

    // Creamos un nuevo error con la información combinada
    const error = new Error(message) as Error & { status?: number, originalError?: Error }
    error.status = status
    error.originalError = err // Guardamos el error original para referencia

    // Log en desarrollo si es necesario
    if (this.log) {
      console.error('Error procesado:', {
        context: contextMessage,
        originalMessage: err.message,
        status,
        originalError: err
      })
    }

    throw error
  }
}
const environment = envConfig.Status
const errorHandler = new CustomError(environment === 'development' || environment === 'test')

export const catchController = (controller: Controller) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    controller(req, res, next).catch(next)
  }
}

export const middError = (message: string, status: number): Error & { statusCode?: number } => {
  const error = new Error(message) as Error & { status?: number }
  error.status = status
  return error
}
export const throwError = errorHandler.throwError.bind(errorHandler)

export const processError = errorHandler.processError.bind(errorHandler)

export const errorEndWare = (err: Error & { status?: number }, req: Request, res: Response, next: NextFunction) => {
  const status = err.status || 500
  const message = err.message || 'Internal server error'
  res.status(status).json({
    success: false,
    message,
    data: null
  })
}

export const jsonFormat = (err: Error & { status?: number }, req: Request, res: Response, next: NextFunction): void => {
  if (err instanceof SyntaxError && 'status' in err && err.status === 400 && 'body' in err) {
    res.status(400).json({ error: 'Invalid JSON format' })
  } else {
    next()
  }
}

export const notFoundRoute = (req: Request, res: Response, next: NextFunction): void => {
  return next(middError('Not Found', 404))
}

export default {
  errorEndWare,
  catchController,
  throwError,
  processError,
  middError,
  jsonFormat,
  notFoundRoute
}
EOL
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
# Crear la base de modelos
cat > "$PROJECT_DIR/src/Shared/Models/baseSchemaMixin.ts" <<EOL
import { Schema, SchemaDefinition, SchemaDefinitionType } from 'mongoose'

const baseSchemaFields: SchemaDefinition<SchemaDefinitionType<any>> = {
  enabled: { type: Boolean, default: true },
  deleted: { type: Boolean, default: false }
}

export function applyBaseSchema (schema: Schema): Schema {
  schema.add(baseSchemaFields)

  schema.pre('save', function (next) {
    if (this.enabled === undefined) this.enabled = true
    if (this.deleted === undefined) this.deleted = false
    next()
  })

  schema.methods.softDelete = function () {
    this.deleted = true
    this.enabled = false
    return this.save()
  }

  schema.statics.findEnabled = function (filter = {}) {
    return this.find({ ...filter, enabled: true, deleted: false })
  }

  return schema
}
EOL
# Crear el modelo de Test
cat > "$PROJECT_DIR/test/testHelpers/modelTest.ts" <<EOL
import mongoose, { Schema, Document, Model } from 'mongoose'
import { applyBaseSchema } from '../../src/Shared/Models/baseSchemaMixin.js'

// 1. Define la interfaz para el documento
export interface ITest extends Document {
  title: string
  count: number
  picture: string
  enabled: boolean
  deleted: boolean
  softDelete: () => Promise<this>
}

// 2. Define el schema con tipos
const testSchema = new Schema<ITest>(
  {
    title: {
      type: String,
      required: true,
      unique: true
    },
    count: {
      type: Number,
      required: true
    },
    picture: {
      type: String,
      required: true
    }
  },
  {
    timestamps: true
  }
)

// 3. Aplica los campos y métodos comunes
applyBaseSchema(testSchema)

// 4. Crea el modelo
const Test: Model<ITest> = mongoose.model<ITest>('Test', testSchema)

export default Test
EOL
#Crear el modelo de user
cat > "$PROJECT_DIR/src/Shared/Models/userModel.ts" <<EOL
import mongoose from 'mongoose'
import { applyBaseSchema } from './baseSchemaMixin.js'

export interface IUser extends mongoose.Document {
  _id: mongoose.Types.ObjectId
  email: string
  password: string
  nickname: string
  picture: string
  name?: string
  surname?: string
  country?: string
  isVerify: boolean
  role: number
  isRoot: boolean
  deleted: boolean
  enabled: boolean
  // ...otros campos heredados de baseSchemaMixin
}

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true
    },
    password: {
      type: String,
      required: true
    },
    nickname: {
      type: String,
      required: true
    },
    picture: {
      type: String,
      required: true
    },
    name: {
      type: String,
      required: false
    },
    surname: {
      type: String,
      required: false
    },
    country: {
      type: String,
      required: false
    },
    isVerify: {
      type: Boolean,
      default: false,
      required: true
    },
    role: {
      type: Number,
      enum: [1, 2, 3, 9],
      default: 1,
      required: true
    },
    isRoot: {
      type: Boolean,
      default: false,
      required: true
    }

  },
  {
    timestamps: true
  }
)

applyBaseSchema(userSchema)

export const User = mongoose.model<IUser>('User', userSchema)
EOL
# Crear el archivo de validacion
cat > "$PROJECT_DIR/src/Shared/Auth/auth.ts" <<EOL
import { Request, Response, NextFunction } from 'express'
import pkg, {Secret} from 'jsonwebtoken'
import crypto from 'crypto'
import eh from '../../Configs/errorHandlers.js'
import envConfig from '../../Configs/envConfig.js'

export interface JwtPayload {
  userId: string
  email: string
  internalData: string
  iat?: number
  exp?: number
}

export class Auth {
  static generateToken (user: { id: string, email: string, role: number,}, expiresIn?:string| number ): string {
    const intData = disguiseRole(user.role, 5)
    const jwtExpiresIn: string | number = expiresIn ?? Math.ceil(envConfig.ExpiresIn * 60 * 60)
    const secret: Secret = envConfig.Secret;
    return pkg.sign(
      { userId: user.id, email: user.email, internalData: intData },
      secret,
      { expiresIn: jwtExpiresIn as any}
    )
  }
    static generateEmailVerificationToken (user: {id: string}, expiresIn?:string| number ) {
        const userId = user.id
        const secret: Secret = envConfig.Secret;
        const jwtExpiresIn: string | number = expiresIn ?? '8h'
      return pkg.sign(
        { userId, type: 'emailVerification' },
        secret,
        { expiresIn: jwtExpiresIn as any }
      )
    }

  static async verifyToken (req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      let token: string | undefined = (req.headers['x-access-token'] as string) || req.headers.authorization
      if (!token) {
        return next(eh.middError('Unauthorized access. Token not provided', 401))
      }
      if (token.startsWith('Bearer')) {
        token = token.slice(6).trim()
      }
      if (token === '' || token === 'null' || token === 'undefined') {
        return next(eh.middError('Missing token!', 401));
      }

      const decoded = pkg.verify(token, envConfig.Secret) as JwtPayload

      //req.user = decoded
      const userId = decoded.userId
      const userRole = recoveryRole(decoded.internalData, 5)
      req.userInfo = { userId, userRole }

      next()
    } catch (err: any) {
      if (err.name === 'TokenExpiredError') {
        return next(eh.middError('Expired token', 401))
      }
      return next(eh.middError('Invalid token', 401))
    }
  }

    static async verifyEmailToken (req: Request, res: Response, next: NextFunction): Promise<void>  {
        let token = req.query.token as string;
        token= token.trim()
         if (token === '' || token === 'null' || token === 'undefined') {
        return next(eh.middError('Verification token missing!', 400));
        }
      try {
        const decoded = pkg.verify(token, envConfig.Secret) as any;
        if (decoded.type !== 'emailVerification') {
          return next(eh.middError('Invalid token type', 400));
        }
        // Adjunta el userId al request para el siguiente handler/service
        req.userInfo = { userId: decoded.userId }
        next();
      } catch (error) {
        return next(eh.middError('Invalid or expired token', 400));
      }
  }
  static checkRole (allowedRoles: number[]) {
    return (req: Request, res: Response, next: NextFunction) => {
      const { userRole } = req.userInfo || {}
      if (typeof userRole === 'number' && allowedRoles.includes(userRole)) {
        next()
      } else {
        return next(eh.middError('Access forbidden!', 403))
      }
    }
  }

}

// Funciones auxiliares (pueden ir fuera de la clase)
function disguiseRole (role: number, position: number): string {
  const generateSecret = (): string => crypto.randomBytes(10).toString('hex')
  const str = generateSecret()
  if (position < 0 || position >= str.length) throw new Error('Posición fuera de los límites de la cadena')
  const replacementStr = role.toString()
  return str.slice(0, position) + replacementStr + str.slice(position + 1)
}

function recoveryRole (str: string, position: number): number {
  if (position < 0 || position >= str.length) throw new Error('Posición fuera de los límites de la cadena')
  const recover = str.charAt(position)
  return parseInt(recover)
}

// En recoveryRole str es el dato entrante (string)
// Este es un modelo de como recibe el parámetro checkRole:
// todo   app.get('/ruta-protegida', checkRole([3]),
EOL
# Crear el archivo de test
cat > "$PROJECT_DIR/src/Shared/Auth/Auth.test.ts" <<EOL
import session from 'supertest'
import serverTest from './testHelpers/serverTest.help.js'
const agent = session(serverTest)
import { Auth } from './auth.js'
import {setUserToken, getUserToken, setAdminToken, getAdminToken } from '../../../test/testHelpers/testStore.help.js'

describe('"Auth" class. Jsonwebtoken middlewares. Unit tests.', () => {
    describe('Auth.generateToken, Auth.verifyToken. ', () => {
    it('should generate a JWT and allow access through the verifyToken middleware and set the userInfo object (req.useInfo)', async() => {
        const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
        const token = Auth.generateToken(user)
        setUserToken(token)
        const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer \{token}\`)
                .expect(200);
                expect(test.body.success).toBe(true)
                expect(test.body.message).toBe('Passed middleware')
                expect(test.body.data).toEqual({user})
                expect(test.body.userInfo).toEqual({userId: "123", userRole: 1})// through decoded
    })
    it('should return 401 if no token is provided', async() =>{
         const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
         const token = getUserToken()
         const test = await agent
                .post('/')
                .send({user})
                //.set('Authorization', \`Bearer \${token}\`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Unauthorized access. Token not provided')
                expect(test.body.data).toBe(null)
    })
        it('should return 401 if token is missing after Bearer', async() =>{
         const user = { id: "123"}
         const token = getUserToken()
         const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer \`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Missing token!')
                expect(test.body.data).toBe(null)
    })
         it('should return 401 if token is invalid', async() =>{
         const user = { id: "123"}
         const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer ñasdijfasdfjoasdiieieiehoifdoiidoioslsleoiudoisosdfhoi\`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid token')
                expect(test.body.data).toBe(null)
    })
          it('should return 401 if token is expired', async() =>{
         const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
         const expiredToken = Auth.generateToken(user, 1);
            // Esperamos 2 segundos para asegurarnos de que expire
        await new Promise(resolve => setTimeout(resolve, 3000));
         const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer \${expiredToken}\`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Expired token')
                expect(test.body.data).toBe(null)
    })
  })
  describe('Auth.checkRole', () => {
    it('should allow access if user has an allowed role', async() => {
        const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
        const token = Auth.generateToken(user)
        setUserToken(token)
        const test = await agent
                .post('/roleUser')
                .send({user})
                .set('Authorization', \`Bearer \${token}\`)
                .expect(200);
                expect(test.body.success).toBe(true)
                expect(test.body.message).toBe('Passed middleware')
                expect(test.body.data).toEqual({user})
                expect(test.body.userInfo).toEqual({userId: "123", userRole: 1})
    })
     it('should return 403 and deny access if user does not have an allowed role', async() => {
        const user = { id: "123", email: "userexample@test.com", role:3, otherField: 'other'}
        const token = Auth.generateToken(user)
        setUserToken(token)
        const test = await agent
                .post('/roleUser')
                .send({user})
                .set('Authorization', \`Bearer \${token}\`)
                .expect(403);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Access forbidden!')
                expect(test.body.data).toBe(null)
                expect(test.body.userInfo).toBe(undefined)
    })
  })
  describe('Auth.generateEmailVerificationToken and Auth.verifyEmailToken methods. Email verification.', () => {
    it('should verify email token and return userId in userInfo', async() => {
       const user = { id: "123", email: "userexample@test.com", }
        const token = Auth.generateEmailVerificationToken(user)
        setAdminToken(token)
        const test = await agent
                .get(\`/emailVerify?token=\${token}\`)
                .expect(200);
                expect(test.body.success).toBe(true)
                expect(test.body.message).toBe('Passed middleware')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual({userId: "123"})// through decoded
    })
    it('should return 400 if token is missing', async() => {
        const test = await agent
                .get(\`/emailVerify?token=''\`)
                .expect(400);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid or expired token')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual(undefined)
    })
    it('should return 400 if token type is invalid', async() => {
       const user = { id: "123", email: "userexample@test.com", }
        const token = getUserToken()
        const test = await agent
                .get(\`/emailVerify?token=\${token}\`)
                .expect(400);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid token type')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual(undefined)
    })
     it('should return 400 if verification token is expired', async() => {
       const user = { id: "123", email: "userexample@test.com", }
        const expiredToken = Auth.generateEmailVerificationToken(user, 1);
            // Esperamos 2 segundos para asegurarnos de que expire
        await new Promise(resolve => setTimeout(resolve, 3000));
        const test = await agent
                .get(\`/emailVerify?token=\${expiredToken }\`)
                .expect(400);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid or expired token')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual(undefined)
    })
  })
})
EOL
# Crear archivo de server para test
cat > "$PROJECT_DIR/src/Shared/Auth/testHelpers/serverTest.help.ts" <<EOL
import express, {Request, Response, NextFunction} from 'express'
import eh from '../../../Configs/errorHandlers.js'
import {Auth} from '../auth.js'



const serverTest = express()
serverTest.use(express.json())

serverTest.post('/', Auth.verifyToken, eh.catchController(async(req: Request, res: Response,):Promise<void> => {
    const data = req.body
    const decoResponse =  (req as any).userInfo
    res.status(200).json({ success: true, message: 'Passed middleware', data:data, userInfo: decoResponse })
}))

serverTest.post('/roleUser', Auth.verifyToken, Auth.checkRole([1]), eh.catchController(async(req: Request, res: Response,):Promise<void> => {
    const data = req.body
    const decoResponse =  (req as any).userInfo
    res.status(200).json({ success: true, message: 'Passed middleware', data:data, userInfo: decoResponse  })
}))

serverTest.get('/emailVerify', Auth.verifyEmailToken, eh.catchController(async(req: Request, res: Response,):Promise<void> => {
    const decoResponse =  (req as any).userInfo
    res.status(200).json({ success: true, message: 'Passed middleware', data:null, userInfo: decoResponse })
}))

serverTest.use((err: Error & { status?: number }, req: Request, res: Response, next: NextFunction) => {
  const status = err.status || 500
  const message = err.message || 'Internal server error'
  res.status(status).json({
    success: false,
    message,
    data: null
  })})
export default serverTest
EOL
# Crear el controlador
cat > "$PROJECT_DIR/src/Shared/Controllers/BaseController.ts" <<EOL
import { Request, Response } from 'express'
import { Document } from 'mongoose'
import { catchController } from '../../Configs/errorHandlers.js'
import { BaseService } from '../Services/BaseService.js'

export class BaseController<T extends Document> {
  protected service: BaseService<T>

  constructor (service: BaseService<T>) {
    this.service = service
  }

  static responder (
    res: Response,
    status: number,
    success: boolean,
    message: string,
    results: any
  ) {
    return res.status(status).json({ success, message, results })
  }

  getAll = catchController(async (req: Request, res: Response) => {
    const response = await this.service.getAll()
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  findWithPagination = catchController(async (req: Request, res: Response) => {
    const { page, limit, sort, ...filters } = req.query
    // Parse sort: admite ?sort=title,-1 o ?sort=title:desc
    const sortObj: Record<string, 1 | -1> = {}
    if (typeof sort === 'string') {
    // Ejemplo: sort=title,-1  o  sort=title:desc
      const [field, order] = sort.includes(':') ? sort.split(':') : sort.split(',')
      if (field && order) {
        const ord = order === '-1' || order === 'desc' ? -1 : 1
        sortObj[field] = ord
      }
    }
    const response = await this.service.findWithPagination({
      page: Number(page),
      limit: Number(limit),
      sort: sortObj,
      filters
    })
    return BaseController.responder(res, 200, true, response.message, {
      info: response.info,
      results: response.results
    })
  })

  getOne = catchController(async (req: Request, res: Response) => {
    const { id } = req.params
    const response = await this.service.getOne(id)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  create = catchController(async (req: Request, res: Response) => {
    const data = req.body
    const response = await this.service.create(data)
    return BaseController.responder(res, 201, true, response.message, response.results)
  })

  update = catchController(async (req: Request, res: Response) => {
    const { id } = req.params
    const data = req.body
    const response = await this.service.update(id, data)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  delete = catchController(async (req: Request, res: Response) => {
    const { id } = req.params
    const response = await this.service.delete(id)
    return BaseController.responder(res, 200, true, response.message, null)
  })
}
EOL
# Crear el servicio
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.ts" <<EOL
import { Model, Document, FilterQuery } from 'mongoose'
import eh from '../../Configs/errorHandlers.js'
import { deletFunctionTrue } from '../../../test/generalFunctions.js'
import { infoClean } from './testHelpers/testHelp.help.js'

interface Pagination {
  page?: number
  limit?: number
  filters?: Record<string, any>
}

interface ResponseWithPagination<T> {
  message: string
  results: T[]
  info: {
    totalPages: number
    total: number
    page: number
    limit: number
    count: number
  }
}

type ParserFunction<T> = (doc: T) => any

export class BaseService<T extends Document> {
  protected readonly model: Model<T>
  protected readonly useImages: boolean
  protected readonly deleteImages?: typeof deletFunctionTrue | undefined
  protected readonly parserFunction?: ParserFunction<T>
  protected readonly modelName?: string
  protected readonly whereField?: keyof T

  constructor (
    model: Model<T>,
    useImages = false,
    deleteImages?: typeof deletFunctionTrue,
    parserFunction?: ParserFunction<T>,
    modelName?: string,
    whereField?: keyof T
  ) {
    this.model = model
    this.useImages = useImages
    this.deleteImages = deleteImages
    this.parserFunction = parserFunction
    this.modelName = modelName
    this.whereField = whereField
  }

  async getAll (): Promise<{ message: string, results: any[] }> {
    const docs = await this.model.find()
    if (docs == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: (this.parserFunction != null) ? docs.map(doc => this.parserFunction!(doc)) : docs
    }
  }

  async findWithPagination (query: Pagination & { sort?: Record<string, 1 | -1> }): Promise<ResponseWithPagination<T>> {
    const page = query.page ?? 1
    const limit = query.limit ?? 10
    const skip = (page - 1) * limit

    // const filters = (query.filters != null) || {}
    const filters = (query.filters != null) && typeof query.filters === 'object' ? query.filters : {}
    const sort = (query.sort != null) && typeof query.sort === 'object' ? query.sort : {}
    const total = await this.model.countDocuments(filters)
    const docs = await this.model.find(filters).sort(sort).skip(skip).limit(limit)
    const totalPages = Math.ceil(total / limit)

    const parsed = (this.parserFunction != null)
      ? docs.map(doc => this.parserFunction!(doc))
      : docs

    return {
      message: \`\${this.modelName} list retrieved\`,
      results: parsed,
      info: {
        total,
        page,
        totalPages,
        limit,
        count: parsed.length
      }
    }
  }

  async getOne (id: string): Promise<{ message: string, results: any }> {
    const doc = await this.model.findById(id)
    if (doc == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: (this.parserFunction != null) ? this.parserFunction(doc!) : doc
    }
  }

  async create (data: Partial<T>): Promise<{ message: string, results: any }> {
    const field = this.whereField as string
    if (field && !(data as Record<string, any>)[field]) {
      eh.throwError(\`Missing field '\${field}' for uniqueness check\`, 400)
    }

    if (field) {
      const exists = await this.model.findOne({ [field]: (data as Record<string, any>)[field] } as FilterQuery<T>)
      if (exists != null) {
        eh.throwError(\`This \${field} already exists\`, 400)
      }
    }

    const newDoc = await this.model.create(data)
    const identifier = field && (data as Record<string, any>)[field] ? \`\${(data as Record<string, any>)[field]} \` : ''
    return {
      message: \`$\{this.modelName} \${identifier}created successfully\`,
      results: (this.parserFunction != null) ? this.parserFunction(newDoc) : newDoc
    }
  }

  async update (id: string, data: Partial<T>): Promise<{ message: string, results: any }> {
    const doc = await this.model.findById(id)
    if (doc == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }

    const updated = await this.model.findByIdAndUpdate(id, data, { new: true })
    if (updated == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }

    if (this.useImages && (this.deleteImages != null) && (doc != null)) {
      if ((doc.toObject() as any).picture !== (data as any).picture) {
        const imageUrl = (doc.toObject() as any).picture
        await this.deleteImages(imageUrl)
      }
    }

    return {
      message: \`\${this.modelName} updated successfully\`,
      results: (this.parserFunction != null) ? this.parserFunction(updated!) : updated
    }
  }

  async delete (id: string): Promise<{ message: string }> {
    const doc = await this.model.findById(id)
    if (doc == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }

    if (this.useImages && (this.deleteImages != null) && (doc != null)) {
      const imageUrl = (doc.toObject() as any).picture
      await this.deleteImages(imageUrl)
    }

    await this.model.findByIdAndDelete(id)

    return {
      message: \`\${this.modelName} deleted successfully\`
    }
  }
}
EOL
# Crear el  test para el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.test.ts" <<EOL
import { BaseService } from './BaseService.js'
import Test from '../../../test/testHelpers/modelTest.help.js'
import { infoClean, resultParsedCreate, newData } from './testHelpers/testHelp.help.js'
import { setStringId, getStringId } from '../../../test/testHelpers/testStore.help.js'
import mongoose from 'mongoose'
import { deletFunctionTrue, deletFunctionFalse } from '../../../test/generalFunctions.js'
import { testSeeds } from './testHelpers/seeds.help.js'
import { resetDatabase } from '../../../test/jest.setup.js'

/* constructor (
    model: Model<T>,
    useImages = false,
    deleteImages?: typeof mockDeleteFunction,
    parserFunction?: ParserFunction<T>,
    modelName?: string,
    whereField?: keyof T
  ) */
// model, useImages, deleteImages, parserFunction
const testImsSuccess = new BaseService(Test, true, deletFunctionTrue, infoClean, 'Test', 'title')
const testImgFailed = new BaseService(Test, true, deletFunctionFalse, infoClean, 'Test', 'title')
const testParsed = new BaseService(Test, false, deletFunctionFalse, infoClean, 'Test', 'title')

describe('Unit tests for the BaseService class: CRUD operations.', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('The "create" method for creating a service', () => {
    it('should create an item with the correct parameters', async () => {
      const element = { title: 'page', count: 5, picture: 'https//pepe.com' }
      const response = await testParsed.create(element)
      setStringId(response.results.id)
      expect(response.message).toBe('Test page created successfully')
      // expect(response.results instanceof mongoose.Model).toBe(true);
      expect(response.results).toEqual(resultParsedCreate)
    })
    it('should throw an error when attempting to create the same item twice (error handling)', async () => {
      const element = { title: 'page', count: 5, picture: 'https//pepe.com' }
      try {
        await testParsed.create(element)
        throw new Error('❌ Expected a duplication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('This title already exists')
        } else {
          throw error // Re-lanza si no es el tipo esperado
        }
      }
    })
  })
  describe('"GET" methods. Return one or multiple services..', () => {
    beforeAll(async () => {
      await Test.insertMany(testSeeds)
    })
    it('"getAll" method: should return an array of services', async () => {
      const response = await testParsed.getAll()
      expect(response.message).toBe('Test retrieved')
      expect(response.results.length).toBe(26)
    })
    it('"findWithPagination" method: should return an array of services', async () => {
      const queryObject = { page: 1, limit: 10, filters: {}, sort: {} }
      const response = await testParsed.findWithPagination(queryObject)
      expect(response.message).toBe('Test list retrieved')
      expect(response.info).toEqual({ page: 1, limit: 10, totalPages: 3, count: 10, total: 26 })
      expect(response.results.length).toBe(10)
    })
    it('"findWithPagination" method should return page 2 of results', async () => {
      const queryObject = { page: 2, limit: 10, filters: {}, sort: {} }
      const response = await testParsed.findWithPagination(queryObject)
      expect(response.results.length).toBeLessThanOrEqual(10)
      expect(response.info.page).toBe(2)
    })
    it('"findWithPagination" method should return sorted results (by title desc)', async () => {
      const queryObject = { page: 1, limit: 5, sort: { title: -1 } as Record<string, 1 | -1> }
      const response = await testParsed.findWithPagination(queryObject)
      const titles = response.results.map(r => r.title)
      const sortedTitles = [...titles].sort().reverse()
      expect(titles).toEqual(sortedTitles)
    })

    it('"getOne" method: should return an service', async () => {
      const id = getStringId()
      const response = await testParsed.getOne(id)
      expect(response.results).toEqual(resultParsedCreate)
    })
    it('"getOne" should throw an error if service not exists', async () => {
      try {
        const invalidId = new mongoose.Types.ObjectId().toString()
        await testParsed.getOne(invalidId)
        throw new Error('❌ Expected a "Not found" error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(404)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('Test not found')
        } else {
          throw error
        }
      }
    })
  })
  describe('The "update" method - Handles removal of old images from storage.', () => {
    it('should update the document without removing any images', async () => {
      const id = getStringId()
      const data = newData
      const response = await testParsed.update(id, data)
      expect(response.message).toBe('Test updated successfully')
      expect(response.results).toMatchObject({
        id: expect.any(String) as string,
        title: 'page',
        picture: 'https://donJose.com',
        count: 5,
        enabled: true
      })
    })
    it('should update the document and remove the previous image', async () => {
      const id = getStringId()
      const newData = { picture: 'https://imagen.com.ar' }
      const response = await testImsSuccess.update(id, newData)
      expect(response.message).toBe('Test updated successfully')
    })
    it('should throw an error if image deletion fails during update', async () => {
      const id = getStringId()
      const newData = { picture: 'https://imagen44.com.ar' }
      try {
        const resp = await testImgFailed.update(id, newData)
        throw new Error('❌ Expected a update error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect(error).toBeInstanceOf(Error)
          expect((error as { status: number }).status).toBe(500)
          expect((error as { message: string }).message).toBe('Error processing ImageUrl: https://imagen.com.ar')
        } else {
          throw error
        }
      }
    })
  })
  describe('The "delete" method.', () => {
    it('should delete a document successfully (soft delete)', async () => {
      const id = getStringId()
      const response = await testImsSuccess.delete(id)
      expect(response.message).toBe('Test deleted successfully')
    })
    it('should throw an error if document do not exist', async () => {
      const id = getStringId()
      try {
        await testImgFailed.delete(id)
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect(error).toBeInstanceOf(Error)
          expect((error as { status: number }).status).toBe(404)
          expect((error as { message: string }).message).toBe('Test not found')
        } else {
          throw error
        }
      }
    })
  })
})
EOL
# Crear testHelp.help.ts
cat > "$PROJECT_DIR/src/Shared/Services/testHelpers/testHelp.test.ts" <<EOL
import { Types } from 'mongoose'
import { ITest } from '../../../../test/testHelpers/modelTest.help.js'

export type Info = Pick<ITest, '_id' | 'title' | 'count' | 'picture' | 'enabled'> & {
  _id: Types.ObjectId }
// { _id:Types.ObjectId, title: string, count: number, picture: string, enabled: boolean}

export interface ParsedInfo {
  id: string
  title: string
  count: number
  picture: string
  enabled: boolean
}

export const infoClean = (data: Info): ParsedInfo => {
  return {
    id: data._id.toString(),
    title: data.title,
    count: data.count,
    picture: data.picture,
    enabled: data.enabled
  }
}

export const resultParsedCreate: ParsedInfo = {
  id: expect.any(String) as string,
  title: 'page',
  count: 5,
  picture: 'https//pepe.com',
  enabled: true
}

export const newData: Omit<ParsedInfo, 'id'> = {
  title: 'page',
  count: 5,
  picture: 'https://donJose.com',
  enabled: true
}

export const responseNewData: ParsedInfo = {
  id: expect.any(String) as string,
  title: 'page',
  count: 5,
  picture: 'https://donJose.com',
  enabled: true
}
EOL
# Crear testHelp.help.ts
cat > "$PROJECT_DIR/src/Shared/Services/testHelpers/seeds.test.ts" <<EOL
export interface Seeds {
  title: string
  count: number
  picture: string
  enabled: boolean
}

export const testSeeds: Seeds[] = [
  { title: 'donJose', count: 5, picture: 'https://donJose.com', enabled: true },
  { title: 'about', count: 2, picture: 'https://about.com/img1', enabled: true },
  { title: 'contact', count: 7, picture: 'https://contact.com/img2', enabled: false },
  { title: 'services', count: 1, picture: 'https://services.com/img3', enabled: true },
  { title: 'portfolio', count: 9, picture: 'https://portfolio.com/img4', enabled: false },
  { title: 'home', count: 3, picture: 'https://home.com/img5', enabled: true },
  { title: 'products', count: 12, picture: 'https://products.com/img6', enabled: true },
  { title: 'team', count: 6, picture: 'https://team.com/img7', enabled: false },
  { title: 'careers', count: 0, picture: 'https://careers.com/img8', enabled: true },
  { title: 'blog', count: 4, picture: 'https://blog.com/img9', enabled: true },
  { title: 'faq', count: 10, picture: 'https://faq.com/img10', enabled: false },
  { title: 'support', count: 8, picture: 'https://support.com/img11', enabled: true },
  { title: 'terms', count: 15, picture: 'https://terms.com/img12', enabled: false },
  { title: 'privacy', count: 11, picture: 'https://privacy.com/img13', enabled: true },
  { title: 'login', count: 14, picture: 'https://login.com/img14', enabled: true },
  { title: 'register', count: 13, picture: 'https://register.com/img15', enabled: false },
  { title: 'dashboard', count: 17, picture: 'https://dashboard.com/img16', enabled: true },
  { title: 'settings', count: 16, picture: 'https://settings.com/img17', enabled: true },
  { title: 'notifications', count: 18, picture: 'https://notifications.com/img18', enabled: false },
  { title: 'messages', count: 19, picture: 'https://messages.com/img19', enabled: true },
  { title: 'billing', count: 21, picture: 'https://billing.com/img20', enabled: true },
  { title: 'reports', count: 22, picture: 'https://reports.com/img21', enabled: false },
  { title: 'analytics', count: 23, picture: 'https://analytics.com/img22', enabled: true },
  { title: 'integration', count: 24, picture: 'https://integration.com/img23', enabled: true },
  { title: 'feedback', count: 20, picture: 'https://feedback.com/img24', enabled: false }
]
EOL
#Crear el middleware
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddlewareHandler.ts" <<EOL
import { validate as uuidValidate } from 'uuid'
import mongoose from 'mongoose'
import { Request, Response, NextFunction } from 'express'

type FieldType = 'boolean' | 'int' | 'float' | 'string' | 'array'

interface FieldDefinition {
  name: string
  type: FieldType
  default?: any
}

export class MiddlewareHandler {
  static middError = (message: string, status: number): Error & { statusCode?: number } => {
    const error = new Error(message) as Error & { status?: number }
    error.status = status
    return error
  }

  static getDefaultValue (type: FieldType): any {
    switch (type) {
      case 'boolean': return false
      case 'int': return 1
      case 'float': return 1.0
      case 'string': return ''
      default: return null
    }
  }

  static validateBoolean (value: any): boolean {
    if (typeof value === 'boolean') return value
    if (value === 'true') return true
    if (value === 'false') return false
    throw new Error('Invalid boolean value')
  }

  static validateInt (value: any): number {
    const intValue = Number(value)
    if (isNaN(intValue) || !Number.isInteger(intValue)) {
      throw new Error('Invalid integer value')
    }
    return intValue
  }

  static validateFloat (value: any): number {
    const floatValue = parseFloat(value)
    if (isNaN(floatValue)) {
      throw new Error('Invalid float value')
    }
    return floatValue
  }

  static validateValue (
    value: any,
    fieldType: FieldType,
    fieldName: string,
    itemIndex: number | null = null
  ): any {
    const indexInfo = itemIndex !== null ? \` in item[\${itemIndex}]\` : ''

    switch (fieldType) {
      case 'boolean':
        return this.validateBoolean(value)
      case 'int':
        return this.validateInt(value)
      case 'float':
        return this.validateFloat(value)
      case 'array':
        if (!Array.isArray(value)) {
          throw new Error(\`Invalid array value for field \${fieldName}\${indexInfo}\`)
        }
        return value
      case 'string':
      default:
        if (typeof value !== 'string') {
          throw new Error(\`Invalid string value for field \${fieldName}\${indexInfo}\`)
        }
        return value
    }
  }

  static validateFields (requiredFields: FieldDefinition[]) {
    return (req: Request, res: Response, next: NextFunction) => {
      const newData = req.body
      if (!newData || Object.keys(newData).length === 0) {
        return next(this.middError('Invalid parameters', 400))
      }

      const missingFields = requiredFields.filter(field => !(field.name in newData))
      if (missingFields.length > 0) {
        return next(this.middError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400))
      }

      try {
        requiredFields.forEach(field => {
          const value = newData[field.name]
          newData[field.name] = this.validateValue(value, field.type, field.name)
        })

        Object.keys(newData).forEach(key => {
          if (!requiredFields.some(field => field.name === key)) {
            delete newData[key]
          }
        })
      } catch (error: any) {
        return next(this.middError(error.message, 400))
      }

      req.body = newData
      next()
    }
  }

  static validateFieldsWithItems (
    requiredFields: FieldDefinition[],
    secondFields: FieldDefinition[],
    arrayFieldName: string
  ) {
    return (req: Request, res: Response, next: NextFunction) => {
      try {
        const firstData = { ...req.body }
        const secondData = Array.isArray(req.body[arrayFieldName])
          ? [...req.body[arrayFieldName]]
          : null

        if (!firstData || Object.keys(firstData).length === 0) {
          return next(this.middError('Invalid parameters', 400))
        }

        const missingFields = requiredFields.filter((field) => !(field.name in firstData))
        if (missingFields.length > 0) {
          return next(this.middError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400))
        }

        requiredFields.forEach(field => {
          const value = firstData[field.name]
          firstData[field.name] = this.validateValue(value, field.type, field.name)
        })

        Object.keys(firstData).forEach(key => {
          if (!requiredFields.some(field => field.name === key)) {
            delete firstData[key]
          }
        })

        if ((secondData == null) || secondData.length === 0) {
          return next(this.middError(\`Missing \${arrayFieldName} array or empty array\`, 400))
        }

        const invalidStringItems = secondData.filter((item) => typeof item === 'string')
        if (invalidStringItems.length > 0) {
          return next(
            this.middError(
              \`Invalid "\${arrayFieldName}" content: expected objects but found strings (e.g., \${invalidStringItems[0]})\`,
              400
            )
          )
        }

        const validatedSecondData = secondData.map((item, index) => {
          const missingItemFields = secondFields.filter((field) => !(field.name in item))
          if (missingItemFields.length > 0) {
            throw this.middError(
              \`Missing parameters in \${arrayFieldName}[\${index}]: \${missingItemFields.map(f => f.name).join(', ')}\`,
              400
            )
          }

          secondFields.forEach(field => {
            const value = item[field.name]
            item[field.name] = this.validateValue(value, field.type, field.name, index)
          })

          return secondFields.reduce((acc: any, field) => {
            acc[field.name] = item[field.name]
            return acc
          }, {})
        })

        req.body = {
          ...firstData,
          [arrayFieldName]: validatedSecondData
        }

        next()
      } catch (err: any) {
        return next(this.middError(err.message, 400))
      }
    }
  }

  static validateQuery (requiredFields: FieldDefinition[]) {
    return (req: Request, res: Response, next: NextFunction) => {
      try {
        const validatedQuery: Record<string, any> = {}

        requiredFields.forEach(({ name, type, default: defaultValue }) => {
          let value = req.query[name]

          if (value === undefined) {
            value = defaultValue !== undefined ? defaultValue : this.getDefaultValue(type)
          } else {
            value = this.validateValue(value, type, name)
          }

          validatedQuery[name] = value
        })

        ;(req as any).validatedQuery = validatedQuery
        next()
      } catch (error: any) {
        return next(this.middError(error.message, 400))
      }
    }
  }

  static validateRegex (validRegex: RegExp, nameOfField: string, message: string | null = null) {
    return (req: Request, res: Response, next: NextFunction) => {
      if (!validRegex || !nameOfField || nameOfField.trim() === '') {
        return next(this.middError('Missing parameters in function!', 400))
      }
      const field = req.body[nameOfField]
      const personalizedMessage = message ? ' ' + message : ''
      if (!field || typeof field !== 'string' || field.trim() === '') {
        return next(this.middError(\`Missing \${nameOfField}\`, 400))
      }
      if (!validRegex.test(field)) {
        return next(this.middError(\`Invalid \${nameOfField} format!\${personalizedMessage}\`, 400))
      }
      next()
    }
  }

  static middUuid (fieldName: string) {
    return (req: Request, res: Response, next: NextFunction) => {
      const id = req.params[fieldName]
      if (!id) return next(this.middError('Falta el id', 400))
      if (!uuidValidate(id)) return next(this.middError('Parametros no permitidos', 400))
      next()
    }
  }

  static middObjectId (fieldName: string) {
    return (req: Request, res: Response, next: NextFunction) => {
      const id = req.params[fieldName]

      if (!id) {
        return next(this.middError('Falta el id', 400))
      }

      if (!mongoose.Types.ObjectId.isValid(id)) {
        return next(this.middError('Id no válido', 400))
      }

      next()
    }
  }

  static middIntId (fieldName: string) {
    return (req: Request, res: Response, next: NextFunction) => {
      const id = req.params[fieldName]
      if (!id) return next(this.middError('Falta el id', 400))
      if (!Number.isInteger(Number(id))) return next(this.middError('Parametros no permitidos', 400))
      next()
    }
  }

  static logRequestBody (req: Request, res: Response, next: NextFunction) {
    if (process.env.NODE_ENV !== 'test') {
      return next()
    }
    const timestamp = new Date().toISOString()
    console.log(\`[\${timestamp}] Request Body:\`, req.body)
    next()
  }
}
EOL
#Crear test para MiddlewareHandler
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddHandler.test.ts" <<EOL
import session from 'supertest'
import serverTest from './testHelpers/serverTest.help.js'
const agent = session(serverTest)

describe('Clase "MiddlewareHandler". Clase estatica de middlewares. Validacion y tipado de datos', () => {
  describe('Metodo "validateFields". Validacion y tipado datos en body (POST y PUT)', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [] as any[]
      }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)

      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: []
      })
    })

    it('deberia validar, tipar y arrojar un error si faltara algun parametro.', async () => {
      const data = { name: 'name', amount: '100', price: '55.44', arreglo: [] }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing parameters: enable')
    })

    it('deberia validar, tipar y arrojar un error si no fuera posible tipar un parametro.', async () => {
      const data = {
        name: 'name',
        amount: 'ppp',
        price: '55.44',
        enable: 'true',
        arreglo: []
      }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid integer value')
    })

    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () => {
      const data = {
        name: 'name',
        email: 'pepe@gmail.com',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: []
      }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)

      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: []
      })
    })
  })

  describe('Metodo "validateFieldsWithItems"', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [
          { name: 'name', picture: 'string', enable: 'true', arreglo: [] }
        ]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)

      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: [],
        items: [
          { name: 'name', picture: 'string', enable: true, arreglo: [] }
        ]
      })
    })

    it('deberia arrojar un error si faltara un parametro en items.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [{ name: 'name', enable: 'true', arreglo: [] }]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing parameters in items[0]: picture')
    })

    it('deberia arrojar un error si no se puede tipar un valor.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [
          {
            name: 'name',
            picture: 'string',
            enable: '445',
            arreglo: []
          }
        ]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid boolean value')
    })

    it('deberia quitar parametros extra.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [
          {
            name: 'name',
            picture: 'string',
            enable: 'true',
            deletedAt: 'queseyo',
            arreglo: []
          }
        ]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: [],
        items: [{ name: 'name', picture: 'string', enable: true, arreglo: [] }]
      })
    })
  })

  describe('Metodo "validateQuery"', () => {
    it('deberia tipar correctamente los query params.', async () => {
      const response = await agent
        .get('/test/param?page=2&size=2.5&fields=pepe&truthy=true')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.validData).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })

    it('deberia aplicar valores por defecto.', async () => {
      const response = await agent
        .get('/test/param')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.validData).toEqual({
        page: 1,
        size: 1,
        fields: '',
        truthy: false
      })
    })

    it('deberia lanzar error si no se puede tipar un valor.', async () => {
      const response = await agent
        .get('/test/param?page=pepe&size=2.5')
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid integer value')
    })

    it('deberia quitar campos no esperados.', async () => {
      const response = await agent
        .get(
          '/test/param?page=2&size=2.5&fields=pepe&truthy=true&demas=pepito'
        )
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.validData).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })
  })

  describe('Metodo "validateRegex"', () => {
    it('deberia permitir email valido.', async () => {
      const data = { email: 'emaildeprueba@ejemplo.com' }
      const response = await agent
        .post('/test/user')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.data).toEqual(data)
    })

    it('deberia rechazar email invalido.', async () => {
      const data = { email: 'emaildeprueba@ejemplocom' }
      const response = await agent
        .post('/test/user')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe(
        'Invalid email format! Introduzca un mail valido'
      )
    })
  })

  describe('Metodo "middUuid"', () => {
    it('deberia permitir UUID v4 valido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76-191f905a2edd'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })

    it('deberia rechazar UUID invalido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })

  describe('Metodo "middObjectId"', () => {
    it('deberia permitir ObjectId valido.', async () => {
      const id = '6820bf17074781c88b81ad82'
      const response = await agent
        .get(\`/test/param/mongoose/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })
    it('deberia rechazar ObjectId invalido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/mongoose/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Id no válido')
    })
  })
  describe('Metodo "middIntId"', () => {
    it('deberia permitir Integer valido.', async () => {
      const id = 22
      const response = await agent
        .get(\`/test/param/int/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })

    it('deberia rechazar Integer invalido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/int/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })
})
EOL
#Crear helperTest para MiddlewareHandler

cat > "$PROJECT_DIR/src/Shared/Middlewares/testHelpers/serverTest.help.ts" <<EOL
import express, { Request, Response, NextFunction } from 'express'
import { MiddlewareHandler } from '../MiddlewareHandler.js' 
import eh from '../../../Configs/errorHandlers.js'

interface FieldItem { name: string, type: 'string' | 'int' | 'float' | 'boolean' | 'array' }

const firstItems: FieldItem[] = [
  { name: 'name', type: 'string' },
  { name: 'amount', type: 'int' },
  { name: 'price', type: 'float' },
  { name: 'enable', type: 'boolean' },
  { name: 'arreglo', type: 'array' }
]

const secondItem: FieldItem[] = [
  { name: 'name', type: 'string' },
  { name: 'picture', type: 'string' },
  { name: 'enable', type: 'boolean' },
  { name: 'arreglo', type: 'array' }
]

const emailRegex: RegExp = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

const queries: FieldItem[] = [
  { name: 'page', type: 'int' },
  { name: 'size', type: 'float' },
  { name: 'fields', type: 'string' },
  { name: 'truthy', type: 'boolean' }
]

const serverTest = express()
serverTest.use(express.json())

serverTest.post(
  '/test/body/create',
  MiddlewareHandler.validateFields(firstItems),
  eh.catchController(
  async(req: Request, res: Response) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
))

serverTest.post(
  '/test/body/extra/create',
  MiddlewareHandler.validateFieldsWithItems(firstItems, secondItem, 'items'),
   eh.catchController(
  async(req: Request, res: Response) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
))

serverTest.post(
  '/test/user',
  MiddlewareHandler.validateRegex(
    emailRegex,
    'email',
    'Introduzca un mail valido'
  ),
   eh.catchController(
  async(req: Request, res: Response) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
))

serverTest.get(
  '/test/param',
  MiddlewareHandler.validateQuery(queries),
   eh.catchController(
  async(req: Request, res: Response) => {
    res.status(200).json({
      message: 'Passed middleware',
      data: req.query,
      validData: (req as any).validatedQuery // si se agrega en el middleware, se puede extender \`Request\`
    })
  }
))

serverTest.get(
  '/test/param/:id',
  MiddlewareHandler.middUuid('id'),
   eh.catchController(
  async(req: Request, res: Response) => {
    res.status(200).json({ message: 'Passed middleware' })
  }
))

serverTest.get(
  '/test/param/mongoose/:id',
  MiddlewareHandler.middObjectId('id'),
   eh.catchController(
  async(req: Request, res: Response) => {
    res.status(200).json({ message: 'Passed middleware' })
  }
))

serverTest.get(
  '/test/param/int/:id',
  MiddlewareHandler.middIntId('id'),
   eh.catchController(
  async(req: Request, res: Response) => {
    res.status(200).json({ message: 'Passed middleware' })
  }
))

serverTest.use(
  (err: any, req: Request, res: Response, next: NextFunction) => {
    const status: number = err.status || 500
    const message: string = err.message || err.stack
    res.status(status).json(message)
  }
)

export default serverTest
EOL

#Crear setup y archivos para Swagger
# Crear archivos principales Swagger
cat > "$PROJECT_DIR/src/Shared/Swagger/swaggerOptions.ts" <<EOL
import envConfig from '../../Configs/envConfig.js'
import {loadComponentSchemas} from './loadComponents.js'
import fs from 'fs';
import path from 'path';

function getJsdocFiles(dir: string): string[] {
  const absDir = path.resolve(process.cwd(), dir);
  return fs.readdirSync(absDir)
    .filter(file => file.endsWith('.jsdoc.ts') || file.endsWith('.jsdoc.js'))
    .map(file => path.join(dir, file).replace(/\\\/g, '/'));
}
const apis = getJsdocFiles('./src/Shared/Swagger/schemas');

const swaggerOptions = {
  swaggerDefinition: {
    openapi: '3.0.0',
    info: {
      title: "$PROYECTO_VALIDO",
      version: '1.0.0',
      description: 'Documentación de la API $PROYECTO_VALIDO con Swagger. Este modelo es ilustrativo'
    },

    servers: [
      {
        url: \`http://localhost:\${envConfig.Port}\`
      }
    ],
     components: {
      schemas: loadComponentSchemas(),
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    },
    // security: [
    //   {
    //     bearerAuth: []
       //}
    //]
  },
  apis,
  swaggerOptions: {
    docExpansion: 'none' // 👈 Oculta todas las rutas al cargar
  }
}

export default swaggerOptions
EOL
#Crear archivo loadComponentsSchemas
cat > "$PROJECT_DIR/src/Shared/Swagger/loadComponents.ts" <<EOL
import fs from 'fs';
import path from 'path';

export function loadComponentSchemas(): Record<string, any> {
  const schemasDir = path.resolve(process.cwd(), 'src/Shared/Swagger/schemas/components');
  const schemaFiles = fs.readdirSync(schemasDir).filter(file => file.endsWith('.json'));

  let components: Record<string, any> = {};

  for (const file of schemaFiles) {
    const schemaPath = path.join(schemasDir, file);
    const schemaContent = JSON.parse(fs.readFileSync(schemaPath, 'utf-8'));
    Object.assign(components, schemaContent);
  }
  return components;
}
EOL
# Crear schema jsdoc para user
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/user.jsdoc.ts" <<EOL
/**
* @swagger
* tags:
*   - name: Users
*     description: Operaciones relacionadas con users
 */

/**
* @swagger
* '/api/v1/user/create':
*   post:
*     summary: Crear un nuevo user
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             required:
*                - email
*                - password
*             properties:
*             email:
*               type: string
*               format: email
*               example: email ejemplo
*               description: Descripción de email
*             password:
*               type: string
*               example: password ejemplo
*               description: Descripción de password
*     responses:
*       201:
*         description: Creación exitosa
*         content:
*           application/json:
*             schema:
*               type: object
*               properties:
*                 success:
*                   type: boolean
*                 message:
*                   type: string
*                 results:
*                   \$ref: '#/components/schemas/User'
 */

/**
* @swagger
* '/api/v1/user/login':
*   post:
*     summary: Iniciar sesión
*     tags: [Users]
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             required:
*                - email
*                - password
*             properties:
*             email:
*               type: string
*               format: email
*               example: email ejemplo
*               description: Descripción de email
*             password:
*               type: string
*               example: password ejemplo
*               description: Descripción de password
*     responses:
*       200:
*         description: Login successfully
*         content:
*           application/json:
*             schema:
*               type: object
*               properties:
*                 success:
*                   type: boolean
*                 message:
*                   type: string
*                 results:
*                   type: object
*                   properties:
*                     user:
*                       \$ref: '#/components/schemas/User'   
*                     token:
*                       type: string
 */

/**
* @swagger
* '/api/v1/user':
*   get:
*     summary: Obtener todos los users
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: query
*         name: name
*         required: false
*         schema:
*           type: string
*         description: User name
*     responses:
*       200:
*         description: Lista de users
*         content:
*           application/json:
*             schema:
*               type: array
*               items:
*                 \$ref: '#/components/schemas/User'
 */

/**
* @swagger
* '/api/v1/user/{id}':
*   get:
*     summary: Obtener un user por ID
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: string
*         description: User id
*     responses:
*       200:
*         description: user encontrado
*         content:
*           application/json:
*             schema:
*               \$ref: '#/components/schemas/User'
*       404:
*         description: user no encontrado
 */

/**
* @swagger
* '/api/v1/user/{id}':
*   put:
*     summary: Actualizar un user
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: string
*         description: User id
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             properties:
*             email:
*               type: string
*               format: email
*               example: email ejemplo
*               description: Descripción de email
*             password:
*               type: string
*               example: password ejemplo
*               description: Descripción de password
*     responses:
*       200:
*         description: Actualización exitosa
*       400:
*         description: Error de validación
 */

/**
* @swagger
* '/api/v1/user/{id}':
*   delete:
*     summary: Eliminar un user
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: string
*         description: User id
*     responses:
*       200:
*         description: Eliminado correctamente
*       404:
*         description: user no encontrado
 */
EOL
# Crear archivo json para user
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/components/user.schema.json" <<EOL
{
  "User": {
    "type": "object",
    "properties": {
      "id": {
        "type": "string"
      },
      "email": {
        "type": "string",
        "example": "useremail@example.com"
      },
      "password": {
        "type": "string",
        "example": "L1234567"
      },
      "nickname": {
        "type": "string",
        "example": "useremail"
      },
      "picture": {
        "type": "string",
        "example": "https:/image.com"
      },
      "name": {
        "type": "string",
        "example": "email"
      },
      "surname": {
        "type": "string",
        "example": "user"
      },
      "country": {
        "type": "string",
        "example": "argentina"
      },
      "role": {
        "type": "string",
        "example": "User"
      },
      "enabled": {
        "type": "boolean",
        "example": true
      },
      "isVerify": {
        "type": "boolean",
        "example": true
      }
    },
    "required": [
      "id",
      "email",
      "password",
      "role",
      "enabled",
      "isVerify"
    ]
  }
}
EOL
# Crear archivo para creacion guiada de jsdoc
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/tools/generateSchema.ts" <<EOL
import fs from 'fs';
import path from 'path';
import inquirer from 'inquirer';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { generateComponentSchema } from './generateComponentSchema.js';

type Field = {
  name: string
  type: 'string' | 'number' | 'boolean' | 'integer'
  format?: string
}

type Parameter = {
  name: string
  in: 'path' | 'query'
  type: 'string' | 'integer' | 'boolean'
  description: string
  required: boolean
}

type SchemaInfo = {
  tag: string
  singular: string
  basePrefix: string;
  fields: Field[]
  pathParams: Parameter[]
  queryParams: Parameter[]
  includeSchema: boolean
}

const __dirname = dirname(fileURLToPath(import.meta.url));
const outputPath = path.join(__dirname, '../../schemas');

const askFields = async ():Promise<Field[]> => {
  const fields: Field[] = [];
  let addMore = true;

  while (addMore) {
    const { name, type, format } = await inquirer.prompt([
      { type: 'input', name: 'name', message: 'Nombre del campo (ej: title)' },
      {
        type: 'list',
        name: 'type',
        message: 'Tipo de dato',
        choices: ['string', 'number', 'boolean', 'integer']
      },
      {
        type: 'input',
        name: 'format',
        message: 'Formato (opcional, ej: email, date-time)',
        default: '',
        validate: (input) => true
      }
    ]);

    const field: Field = { name, type };
    if (format.trim()) field.format = format.trim();
    fields.push(field);

    const { shouldContinue } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'shouldContinue',
        message: '¿Querés agregar otro campo?',
        default: true
      }
    ]);

    addMore = shouldContinue;
  }

  return fields;
};

const askParameters = async (kind: 'path' | 'query' = 'path'): Promise<Parameter[]> => {
  const result = [];
  let addMore = true;

  while (addMore) {
    const { name, type, description, required } = await inquirer.prompt([
      { type: 'input', name: 'name', message: \`Nombre del parámetro (\${kind})\` },
      {
        type: 'list',
        name: 'type',
        message: 'Tipo de dato',
        choices: ['string', 'integer', 'boolean']
      },
      { type: 'input', name: 'description', message: 'Descripción' },
      {
        type: 'confirm',
        name: 'required',
        message: '¿Es requerido?',
        default: kind === 'path'
      }
    ]);

    result.push({ name, in: kind, type, description, required });

    const { shouldContinue } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'shouldContinue',
        message: \`¿Querés agregar otro parámetro (\${kind})?\`,
        default: false
      }
    ]);

    addMore = shouldContinue;
  }

  return result;
};

const askSchemaInfo = async (): Promise<SchemaInfo> => {
  const { tag } = await inquirer.prompt([
    { type: 'input', name: 'tag', message: 'Nombre del tag (ej: Users)' }
  ]);

  const { singular } = await inquirer.prompt([
    { type: 'input', name: 'singular', message: 'Nombre singular del recurso (ej: user)' }
  ]);

  const fields = await askFields();
  const pathParams = await askParameters('path');
  const queryParams = await askParameters('query');

  const { includeSchema } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'includeSchema',
      message: '¿Querés incluir la definición reusable (components.schemas)?',
      default: false
    }
  ]);
  const { basePrefix } = await inquirer.prompt([
  {
    type: 'input',
    name: 'basePrefix',
    message: '¿Cuál es el path base para la ruta? (ej: api, api/v1 o vacío para raíz)',
    default: 'api'
  }
]);

  return {
    tag,
    singular,
    fields,
    pathParams,
    queryParams,
    includeSchema,
    basePrefix
  };
};

const buildPropertiesBlock = (fields: Field[], indent = '            '): string => {
  return fields.map(f => {
    const example =
      f.type === 'string' ? \`\${f.name} ejemplo\` :
      f.type === 'boolean' ? true :
      1;

    return \`\${indent}\${f.name}:\n\${indent}  type: \${f.type}\${f.format ? \`\n\${indent}  format: \${f.format}\` : ''}\n\${indent}  example: \${example}\n\${indent}  description: Descripción de \${f.name}\`;
  }).join('\n');
};

// 👇 cambia el método renderParameters
const renderParameters = (params: Parameter[], indent = '    '): string => {
  if (!params.length) return '';
  return \`\${indent}parameters:\n\${params.map(p => (
\`\${indent}  - in: \${p.in}
\${indent}    name: \${p.name}
\${indent}    required: \${p.required}
\${indent}    schema:
\${indent}      type: \${p.type}
\${indent}    description: \${p.description}\`
  )).join('\n')}\`;
};

const wrapWithJSDoc = (content: string): string => {
  return '/**\n' + content.trim().split('\n').map(line => line.trim() ? \`* \${line}\` : '*').join('\n') + '\n */';
};

const generateJSDoc = (schema: SchemaInfo): string => {
  const { tag, singular, fields, pathParams, queryParams, includeSchema } = schema
  const schemaName = singular.charAt(0).toUpperCase() + singular.slice(1);
  const upperTag = tag.charAt(0).toUpperCase() + tag.slice(1);
  const required = fields.map(f => \`               - \${f.name}\`).join('\n');
  const props = buildPropertiesBlock(fields);
  const parametersBlock = renderParameters([...pathParams, ...queryParams]);
  const allParametersBlock = renderParameters(queryParams)

  //const basePath = \`/api/\${singular}\`;
  const prefix = schema.basePrefix?.replace(/^\/|\/$/g, ''); // limpia barras
  const basePath = \`/\${[prefix, singular].filter(Boolean).join('/')}\`;
  const pathWithId = \`\${basePath}/{id}\`;
  const blocks = [];

  // Tag block
  blocks.push(wrapWithJSDoc(\`
@swagger
tags:
  - name: \${upperTag}
    description: Operaciones relacionadas con \${tag.toLowerCase()}
\`));

  // Schema block (solo una vez si includeSchema es true)
  if (includeSchema) {
    blocks.push(wrapWithJSDoc(\`
@swagger
components:
  schemas:
    \${schemaName}:
      type: object
      properties:
\${props}
\`));
  }

  // Endpoints
  blocks.push(wrapWithJSDoc(\`
@swagger
'\${basePath}':
  post:
    summary: Crear un nuevo \${singular}
    tags: [\${upperTag}]
    requestBody:
      required: true
      content:
        application/json:
          schema:
            type: object
            required:
\${required}
            properties:
\${props}
    responses:
      201:
        description: Creación exitosa
        content:
          application/json:
            schema:
              type: object
              properties:
                success:
                  type: boolean
                message:
                  type: string
                results:
                  \$ref: '#/components/schemas/\${schemaName}'
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${basePath}':
  get:
    summary: Obtener todos los \${singular}s
    tags: [\${upperTag}]
\${allParametersBlock}
    responses:
      200:
        description: Lista de \${singular}s
        content:
          application/json:
            schema:
              type: array
              items:
                \$ref: '#/components/schemas/\${schemaName}'
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${pathWithId}':
  get:
    summary: Obtener un \${singular} por ID
    tags: [\${upperTag}]
\${renderParameters(pathParams)}
    responses:
      200:
        description: \${singular} encontrado
        content:
          application/json:
            schema:
              \$ref: '#/components/schemas/\${schemaName}'
      404:
        description: \${singular} no encontrado
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${pathWithId}':
  put:
    summary: Actualizar un \${singular}
    tags: [\${upperTag}]
\${renderParameters(pathParams)}
    requestBody:
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
\${props}
    responses:
      200:
        description: Actualización exitosa
      400:
        description: Error de validación
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${pathWithId}':
  delete:
    summary: Eliminar un \${singular}
    tags: [\${upperTag}]
\${renderParameters(pathParams)}
    responses:
      200:
        description: Eliminado correctamente
      404:
        description: \${singular} no encontrado
\`));

  return blocks.join('\n\n');
};

const generateSchemaFile = async (schemaInfo: SchemaInfo): Promise<void> => {
  if (!fs.existsSync(outputPath)) fs.mkdirSync(outputPath, { recursive: true });

  const fileName = \`\${schemaInfo.singular}.jsdoc.ts\`;
  const filePath = path.join(outputPath, fileName);
  const jsdocContent = generateJSDoc(schemaInfo);

  fs.writeFileSync(filePath, jsdocContent);
  console.log(\`✅ JSDoc generado: src/Shared/Swagger/schemas/\${fileName}\`);
};

const main = async (): Promise<void> => {
  const schemaInfo = await askSchemaInfo();
  await generateSchemaFile(schemaInfo);
  await generateComponentSchema()
};

main();
EOL
# Crear archivo gemeradpr de json para jsdoc
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/tools/generateComponentSchema.ts" <<EOL
import inquirer from 'inquirer';
import fs from 'fs/promises';
import path from 'path';

export async function generateComponentSchema() {
  const { componentName } = await inquirer.prompt([
    {
      type: 'input',
      name: 'componentName',
      message: 'Nombre del componente (por ejemplo: User):',
      validate: input => input.trim() ? true : 'Este campo es obligatorio.',
      
    },
  ]);

  const { numFields } = await inquirer.prompt([
    {
      type: 'number',
      name: 'numFields',
      message: \`¿Cuántos campos tiene el componente "\${componentName}"?\`,
      validate: (input: unknown) => {
        const num = typeof input === 'number' ? input : Number(input);
        if (!isNaN(num) && num > 0) return true;
        return 'Debe haber al menos un campo.';
                                    },
    },
  ]);

  const properties: Record<string, any> = {};
  const required: string[] = [];

  for (let i = 0; i < numFields; i++) {
    console.log(\`\n--- Campo #\${i + 1} ---\`);
    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'fieldName',
        message: 'Nombre del campo:',
        validate: input => input.trim() ? true : 'Este campo es obligatorio.',
      },
      {
        type: 'list',
        name: 'type',
        message: 'Tipo del campo:',
        choices: ['string', 'integer', 'boolean', 'number'],
      },
      {
        type: 'input',
        name: 'example',
        message: 'Ejemplo del campo:',
      },
      {
        type: 'confirm',
        name: 'isRequired',
        message: '¿Es un campo requerido?',
        default: true,
      },
    ]);

    const { fieldName, type, example, isRequired } = answers;

    properties[fieldName] = {
      type,
      example: castExample(type, example),
    };

    if (isRequired) {
      required.push(fieldName);
    }
  }

  const schema = {
    [componentName]: {
      type: 'object',
      properties,
      ...(required.length > 0 && { required }),
    },
  };

  console.log(\`\n✅ Componente Swagger generado para "\${componentName}":\n\`);
  console.dir(schema, { depth: null, colors: true });
  const outDir = path.resolve(process.cwd(), 'src/Shared/Swagger/schemas/components');
  const filePath = path.join(outDir, \`\${componentName.toLowerCase()}.schema.json\`);
  await fs.writeFile(filePath, JSON.stringify(schema, null, 2));

  console.log(\`\n📁 Guardado en: \${filePath}\`);

  return schema;
}

// Función auxiliar para convertir ejemplo a su tipo real
function castExample(type: string, value: string): any {
  if (!value) return undefined;
  if (type === 'integer') return parseInt(value, 10);
  if (type === 'number') return parseFloat(value);
  if (type === 'boolean') return value.toLowerCase() === 'true';
  return value;
}
EOL
# Crear el archivo jest.setup.ts
cat > "$PROJECT_DIR/test/jest.setup.ts" <<EOL
import mongoose from 'mongoose'
import connectDB from '../src/Configs/database.js'
import { beforeAll, afterAll } from '@jest/globals'

import Test from './testHelpers/modelTest.help.js'

// Inicializa la base de datos de MongoDB antes de las pruebas
async function initializeDatabase () {
  try {
    await connectDB()
    // Asegurarse de empezar en una BD vacía
    await mongoose.connection.dropDatabase()
    // Asegura que se creen los índices
    // await Test.syncIndexes()
    console.log('Índices sincronizados')
    console.log('Base de datos MongoDB inicializada correctamente ✔️')
  } catch (error) {
    console.error('Error inicializando DB MongoDB ❌', error)
  }
}

// Resetea la base de datos antes de cada prueba si es necesario
export async function resetDatabase () {
  try {
    if (mongoose.connection.db == null) {
      throw new Error('La conexión a la base de datos no está lista')
    }
    const collections = await mongoose.connection.db.collections()
    for (const coll of collections) {
      const count = await coll.countDocuments()
      console.log(\`🗃️ antes del reset: \${coll.collectionName}: \${count || 0} documentos\`)
    }
    await mongoose.connection.dropDatabase()
    console.log(\`🔍 Total de colecciones después del drop: \${collections.length}\`)
    console.log('Base de datos MongoDB reseteada ✔️')
  } catch (error) {
    console.error('Error reseteando MongoDB ❌', error)
  }
}

beforeAll(async () => {
  await initializeDatabase()
})

// afterEach(async () => {
//   // Opcional: limpiar tras cada test unitario
//   await resetDatabase();
// });

afterAll(async () => {
  try {
    await mongoose.disconnect()
    console.log('Conexión MongoDB cerrada ✔️')
  } catch (error) {
    console.error('Error cerrando conexión MongoDB ❌', error)
  }
})
EOL
#Crear archivo de integration test para user
cat > "$PROJECT_DIR/test/User.int.test.ts" <<EOL
import app from '../src/app.js'
import session from 'supertest'
import { resetDatabase } from './jest.setup.js'
const agent = session(app)

describe('Integration test. Route Tests: "User"', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('Create method', () => {
    it('should create an user with the correct parameters', async () => {
      const data = { email: 'josenomeacuerdo@gmail.com', password: 'L1234567' }
      const response = await agent
        .post('/api/v1/user/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(201)
      expect(response.body.message).toBe('User josenomeacuerdo@gmail.com created successfully')
      expect(response.body.results).toMatchObject({
        id: expect.any(String),
        email: 'josenomeacuerdo@gmail.com',
        nickname: 'josenomeacuerdo',
        picture: 'https://urlimageprueba.net',
        name: '',
        surname: '',
        country: '',
        role: 'User',
        isVerify: false,
        isRoot: false,
        enabled: true
      })
    })
    it('should throw an error when attempting to create the same user twice (error handling)', async () => {
      const data = { email: 'josenomeacuerdo@gmail.com', password: 'L1234567' }
      const response = await agent
        .post('/api/v1/user/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      console.log('que paso: ', response.body)
      expect(response.body).toEqual({ data: null, message: 'This email already exists', success: false })
    })
  })
})

EOL
#Crear archivo de ayudas para test
cat > "$PROJECT_DIR/test/generalFunctions.ts" <<EOL
import { throwError } from '../src/Configs/errorHandlers.js'

interface DeleteResult {
  success: true
  message: string
}
export async function mockDeleteFunction (url: string, result: boolean): Promise<DeleteResult> {
  if (result) {
    await new Promise(resolve => setTimeout(resolve, 1500))
    return {
      success: true,
      message: \`ImageUrl \${url} deleted succesfully\`
    }
  } else {
    await new Promise(reject => setTimeout(reject, 1500))
    throwError(\`Error processing ImageUrl \${url}\`, 500)
    throw new Error()
  }
}
export const deletFunctionTrue = async (url: string, _result?: boolean): Promise<DeleteResult> => {
  // console.log('probando deleteFunction: ', url);
  return {
    success: true,
    message: \`ImageUrl \${url} deleted succesfully\`
  }
}
export const deletFunctionFalse = async (url: string, _result?: boolean): Promise<never> => {
  // console.log('probando deleteErrorFunction: ', url);
  throwError(\`Error processing ImageUrl: \${url}\`, 500)
  throw new Error()
}
EOL
# Crear el archivo testStore.test.ts
cat > "$PROJECT_DIR/test/testHelpers/testStore.test.ts" <<EOL
let adminToken: string = ''
let userToken: string = ''
let storeId: string = ''
let numberId: number

export const setAdminToken = (newToken: string): void => {
  adminToken = newToken
}

export const getAdminToken = (): string => {
  return adminToken
}

export const setUserToken = (newToken: string): void => {
  userToken = newToken
}

export const getUserToken = (): string => {
  return userToken
}

export const setStringId = (newId: string): void => {
  storeId = newId
}

export const getStringId = (): string => {
  return storeId
}

export const setNumberId = (newId: number): void => {
  numberId = newId
}

export const getNumberId = (): number => {
  return numberId
}
EOL
# Crear el archivo userIntHelp.test.ts
cat > "$PROJECT_DIR/test/testHelpers/userIntHelp.test.ts" <<EOL
export const userCreated = {
  id: expect.any(String),
  email: 'josenomeacuerdo@gmail.com',
  nickname: 'josenomeacuerdo',
  picture: 'https://urlimageprueba.net',
  name: '',
  surname: '',
  country: '',
  role: 'User',
  isVerify: false,
  isRoot: false,
  enabled: true
}
EOL
######### Crear Features #######################
# Crear el usuario de ejemplo
# Crear archivo UserService.ts
cat > "$PROJECT_DIR/src/Features/user/UserService.ts" <<EOL
import bcrypt from 'bcrypt'
import { BaseService } from '../../Shared/Services/BaseService.js'
import { throwError } from '../../Configs/errorHandlers.js'
import { Auth } from '../../Shared/Auth/auth.js'
import { User, IUser } from '../../Shared/Models/userModel.js'
import { UserDto } from './userDto.js'
import envConfig from '../../Configs/envConfig.js'

export class UserService extends BaseService<IUser> {
  constructor () {
    super(
      User, // El modelo de Mongoose
      false, // useImages (ajusta según tu caso)
      undefined, // deleteImages (ajusta según tu caso)
      UserDto.infoClean, // parserFunction (ajusta según tu caso)
      'User', // modelName
      'email' // whereField (ajusta según tu caso)
    )
  }

  async create (data: { email: string, password: string, role?: number, isRoot?: boolean }): Promise<{ message: string, results: any }> {
    const field = this.whereField as string
    if (field && !(data as Record<string, any>)[field]) {
      throwError(\`Missing field '\${field}' for uniqueness check\`, 400)
    }

    if (field) {
      const exists = await this.model.findOne({ [field]: (data as Record<string, any>)[field] })
      if (exists != null) {
        throwError(\`This \${field} already exists\`, 400)
      }
    }
    const newData: Partial<IUser> = {
      email: data.email,
      password: await bcrypt.hash(data.password, 12),
      nickname: data.email.split('@')[0],
      picture: envConfig.UserImg,
      role: data.role || 1,
      isRoot: data.isRoot || false
    }
    const newDoc = await this.model.create(newData)
    const identifier = field && (data as Record<string, any>)[field] ? \`\${(data as Record<string, any>)[field]} \` : ''
    return {
      message: \`\${this.modelName} \${identifier}created successfully\`,
      results: (this.parserFunction != null) ? this.parserFunction(newDoc) : newDoc
    }
  }

  async login (data: { email: string, password: string }) {
    const { email, password } = data
    const userFound = await this.model.findOne({ email })
    if (userFound == null) { throwError('User not found', 404) }
    const hash: string | null = userFound!.password
    const passwordMatch = await bcrypt.compare(password, hash)
    if (!passwordMatch) { throwError('Invalid password', 400) }
    if (!userFound!.enabled) { throwError('User is blocked', 400) }
    const token = Auth.generateToken({
      id: userFound!._id.toString(),
      email: userFound!.email,
      role: userFound!.role
    })
    return {
      message: 'Login successfully',
      results:{user: (this.parserFunction != null) ? this.parserFunction(userFound!) : userFound,
      token : Auth.generateToken((userFound as any))
      }
    }
  }
}
EOL
# Crear el archivo userService.test.ts
cat > "$PROJECT_DIR/src/Features/user/UserService.test.ts" <<EOL
import { UserService } from './UserService.js'
import { resetDatabase } from '../../../test/jest.setup.js'
import { userCreated, userRootCreated } from './testHelpers/user.helperTest.help.js'
import { setStringId, getStringId } from '../../../test/testHelpers/testStore.help.js'

const test = new UserService()

describe('Unit tests for the BaseService class: CRUD operations.', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('The create method for creating a user', () => {
    it('should create an user with the correct parameters', async () => {
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      const response = await test.create(dataUser)
      setStringId(response.results.id)
      expect(response.message).toBe('User usuario@ejemplo.com created successfully')
      expect(response.results).toMatchObject(userCreated)
    })
    it('should throw an error when attempting to create the same user twice (error handling)', async () => {
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      try {
        await test.create(dataUser)
        throw new Error('❌ Expected a duplication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('This email already exists')
        } else {
          throw error
        }
      }
    })
    it('should create an root user with the correct parameters (super user)', async () => {
      const dataUser = { email: 'usuarioroot@ejemplo.com', password: 'L1234567', role: 3, isRoot: true }
      const response = await test.create(dataUser)
      expect(response.message).toBe('User usuarioroot@ejemplo.com created successfully')
      expect(response.results).toMatchObject(userRootCreated)
    })
  })
  describe('Login method for authenticate a user.', () => {
    it('should authenticate the user and return a message, user data, and a token', async () => {
      const data = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      const response = await test.login(data)
      expect(response.message).toBe('Login successfully')
      expect(response.results).toMatchObject(userCreated)
      expect(response.token).toBeDefined()
      expect(typeof response.token).toBe('string')
      expect(response.token).not.toBe('')
    })
    it('"should throw an error if the password is incorrect"', async () => {
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567dididi' }
      try {
        await test.login(dataUser)
        throw new Error('❌ Expected a authentication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('Invalid password')
        } else {
          throw error
        }
      }
    })
    it('"should throw an error if the user is blocked"', async () => {
      const data = { enabled: false }
      await test.update(getStringId(), data)
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      try {
        await test.login(dataUser)
        throw new Error('❌ Expected a authentication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('User is blocked')
        } else {
          throw error
        }
      }
    })
  })
})
EOL
# Crear el archivo UserController.ts
cat > "$PROJECT_DIR/src/Features/user/UserController.ts" <<EOL
import { Request, Response } from 'express'
import { BaseController } from '../../Shared/Controllers/BaseController.js'
import { UserService } from './UserService.js'
import { IUser } from '../../Shared/Models/userModel.js'
import { catchController } from '../../Configs/errorHandlers.js'

export class UserController extends BaseController<IUser> {
  private readonly userService: UserService

  constructor (userService: UserService) {
    super(userService)
    this.userService = userService
  }

  login = catchController(async (req: Request, res: Response) => {
    const data = req.body
    const response = await this.userService.login(data)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })
}
EOL
# Crear el archivo UserDto.ts
cat > "$PROJECT_DIR/src/Features/user/userDto.ts" <<EOL
import { Request, Response, NextFunction } from 'express'
import { IUser } from '../../Shared/Models/userModel.js'
import { Types } from 'mongoose'

export type UserInfo = Pick<IUser, '_id' | 'email' | 'nickname' | 'picture' | 'name' | 'surname' | 'country' | 'role' | 'isVerify' | 'isRoot' | 'enabled'> & {
  _id: Types.ObjectId
}

interface FieldItem { name: string, type: 'string' | 'int' | 'float' | 'boolean' | 'array' }

export interface ParsedUserInfo {
  id: string
  email: string
  nickname: string
  picture: string
  name?: string
  surname?: string
  country?: string
  isVerify: boolean
  role: string
  isRoot: boolean
  enabled: boolean
}

export class UserDto {
  static infoClean (data: UserInfo): ParsedUserInfo {
    return {
      id: data._id.toString(),
      email: data.email,
      nickname: data.nickname,
      picture: data.picture,
      name: data.name || '',
      surname: data.surname || '',
      country: data.country || '',
      role: roleScope(data.role),
      isVerify: data.isVerify,
      isRoot: data.isRoot,
      enabled: data.enabled
    }
  }

  static parsedUser (req: Request, res: Response, next: NextFunction) {
    const newNickname = req.body.email.split('@')[0]
    const numberRole = revertScope(req.body.role)
    req.body.nickname = newNickname
    req.body.role = numberRole
    next()
  }
}
export const create: FieldItem[] = [
  { name: 'email', type: 'string' },
  { name: 'password', type: 'string' }
]
export const update: FieldItem[] = [
  { name: 'email', type: 'string' },
  { name: 'password', type: 'string' },
  { name: 'picture', type: 'string' },
  { name: 'name', type: 'string' },
  { name: 'surname', type: 'string' },
  { name: 'country', type: 'string' },
  { name: 'role', type: 'string' },
  { name: 'enabled', type: 'boolean' }
]
function roleScope (data: number): string {
  const cases: Record<number, string> = {
    1: 'User',
    2: 'Moderator',
    3: 'Admin'
  }
  return cases[data] || 'User'
}
export function revertScope (data: string): number {
  const cases: Record<string, number> = {
    User: 1,
    Moderator: 2,
    Admin: 3
  }
  return cases[data] || 1
}
EOL
# Crear el archivo user.route.ts
cat > "$PROJECT_DIR/src/Features/user/user.route.ts" <<EOL
import { Router } from 'express'
import { UserService } from './UserService.js'
import { UserController } from './UserController.js'
import { MiddlewareHandler } from '../../Shared/Middlewares/MiddlewareHandler.js'
import { UserDto, create, update } from './userDto.js'
import { Auth } from '../../Shared/Auth/auth.js'

const userService = new UserService()
const user = new UserController(userService)

const password: RegExp = /^(?=.*[A-Z]).{8,}$/
const email: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const userRouter = Router()

userRouter.get(
  '/',
  Auth.verifyToken,
  user.getAll
)

userRouter.get(
  '/:id',
  Auth.verifyToken,
  MiddlewareHandler.middObjectId('id'),
  user.getOne
)

userRouter.post(
  '/create',
  Auth.verifyToken,
  MiddlewareHandler.validateFields(create),
  MiddlewareHandler.validateRegex(
    email,
    'email',
    'Introduzca un mail valido'
  ),
  MiddlewareHandler.validateRegex(
    password,
    'password',
    'Introduzca un password valido'
  ),
  user.create
)

userRouter.post(
  '/login',
  MiddlewareHandler.validateFields(create),
  MiddlewareHandler.validateRegex(
    email,
    'email',
    'Introduzca un mail valido'
  ),
  MiddlewareHandler.validateRegex(
    password,
    'password',
    'Introduzca un password valido'
  ),
  user.login
)

userRouter.put(
  '/:id',
  Auth.verifyToken,
  MiddlewareHandler.middObjectId('id'),
  MiddlewareHandler.validateFields(update),
  UserDto.parsedUser,
  user.update
)

userRouter.delete(
  '/:id',
  Auth.verifyToken,
  MiddlewareHandler.middObjectId('id'),
  user.delete
)

export default userRouter
EOL
# Crear el archivo user.helperTest.help.ts
cat > "$PROJECT_DIR/src/Features/user/testHelpers/user.helperTest.help.ts" <<EOL
export const userCreated = {

  id: expect.any(String),
  email: 'usuario@ejemplo.com',
  nickname: 'usuario',
  picture: 'https://urlimageprueba.net',
  name: '',
  surname: '',
  country: '',
  isVerify: false,
  role: 'User',
  isRoot: false,
  enabled: true
}

export const userRootCreated = {
  id: expect.any(String),
  email: 'usuarioroot@ejemplo.com',
  nickname: 'usuarioroot',
  picture: 'https://urlimageprueba.net',
  name: '',
  surname: '',
  country: '',
  isVerify: false,
  role: 'Admin',
  isRoot: true,
  enabled: true
}
EOL

# Crear el archivo jest.config.ts
cat > "$PROJECT_DIR/jest.config.ts" <<EOL
export default {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  extensionsToTreatAsEsm: ['.ts'],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      useESM: true
    }]
  },
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '\$1',
  },
  testMatch: [
    '**/__tests__/**/*.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts'
  ],
  setupFilesAfterEnv: ['./test/jest.setup.ts'],
  detectOpenHandles: true,
  forceExit: true
};
EOL
# Crear el archivo .env
cat > "$PROJECT_DIR/.env" <<EOL
PORT=3001
URI_DB=mongodb://127.0.0.1:27017/herethenameofdb
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://firebasestorage.googleapis.com/v0/b/proyectopreact.appspot.com/o/images%2F1729212207478-silueta.webp?alt=media&token=f0534af7-2df4-4efc-af99-f3f44bf72926"
EOL
# Crear el archivo .env.example
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=
URI_DB=mongodb://127.0.0.1:27017/herethenameofdb
JWT_EXPIRES_IN=1
JWT_SECRET=
USER_IMG=
EOL
# Crear el archivo .env.development
cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
URI_DB=mongodb://127.0.0.1:27017/dbcountriestype
JWT_EXPIRES_IN=1
JWT_SECRET=0f77f231cf98efc224e03781c97990b60d93165a9ed5cc1174cefc01401aa971
USER_IMG="https://firebasestorage.googleapis.com/v0/b/proyectopreact.appspot.com/o/images%2F1729212207478-silueta.webp?alt=media&token=f0534af7-2df4-4efc-af99-f3f44bf72926"
EOL
# Crear el archivo .env.test
cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
URI_DB=mongodb://127.0.0.1:27017/herethenameofdb
JWT_EXPIRES_IN=1
JWT_SECRET=33efe89c6429651a86f9e38e20e7a24400bbef0ba77b559491158de691a7b7f8
USER_IMG="https://urlimageprueba.net"
EOL
# Crear el archivo tsconfig.json
cat > "$PROJECT_DIR/tsconfig.json" <<EOL
{
  "compilerOptions": {
    /* Visit https://aka.ms/tsconfig to read more about this file */

    /* Projects */
    "incremental": true,                              /* Save .tsbuildinfo files to allow for incremental compilation of projects. */
    // "composite": true,                                /* Enable constraints that allow a TypeScript project to be used with project references. */
    // "tsBuildInfoFile": "./.tsbuildinfo",              /* Specify the path to .tsbuildinfo incremental compilation file. */
    // "disableSourceOfProjectReferenceRedirect": true,  /* Disable preferring source files instead of declaration files when referencing composite projects. */
    // "disableSolutionSearching": true,                 /* Opt a project out of multi-project reference checking when editing. */
    // "disableReferencedProjectLoad": true,             /* Reduce the number of projects loaded automatically by TypeScript. */

    /* Language and Environment */
    "target": "ESNext",                                  /* Set the JavaScript language version for emitted JavaScript and include compatible library declarations. */
    // "lib": [],                                        /* Specify a set of bundled library declaration files that describe the target runtime environment. */
    // "jsx": "preserve",                                /* Specify what JSX code is generated. */
    // "libReplacement": true,                           /* Enable lib replacement. */
    "experimentalDecorators": true,                   /* Enable experimental support for legacy experimental decorators. */
    "emitDecoratorMetadata": true,                    /* Emit design-type metadata for decorated declarations in source files. */
    // "jsxFactory": "",                                 /* Specify the JSX factory function used when targeting React JSX emit, e.g. 'React.createElement' or 'h'. */
    // "jsxFragmentFactory": "",                         /* Specify the JSX Fragment reference used for fragments when targeting React JSX emit e.g. 'React.Fragment' or 'Fragment'. */
    // "jsxImportSource": "",                            /* Specify module specifier used to import the JSX factory functions when using 'jsx: react-jsx*'. */
    // "reactNamespace": "",                             /* Specify the object invoked for 'createElement'. This only applies when targeting 'react' JSX emit. */
    // "noLib": true,                                    /* Disable including any library files, including the default lib.d.ts. */
    // "useDefineForClassFields": true,                  /* Emit ECMAScript-standard-compliant class fields. */
    // "moduleDetection": "auto",                        /* Control what method is used to detect module-format JS files. */

    /* Modules */
    "module": "NodeNext",                                /* Specify what module code is generated. */
    // "rootDir": "./",                                  /* Specify the root folder within your source files. */
     "removeComments": true,  
    "moduleResolution": "NodeNext",                     /* Specify how TypeScript looks up a file from a given module specifier. */
    // "baseUrl": "./",                                  /* Specify the base directory to resolve non-relative module names. */
    // "paths": {},                                      /* Specify a set of entries that re-map imports to additional lookup locations. */
    // "rootDirs": [],                                   /* Allow multiple folders to be treated as one when resolving modules. */
    // "typeRoots": [],                                  /* Specify multiple folders that act like './node_modules/@types'. */
    "types": ["node", "@types/jest", "jest"],                                      /* Specify type package names to be included without being referenced in a source file. */
    // "allowUmdGlobalAccess": true,                     /* Allow accessing UMD globals from modules. */
    // "moduleSuffixes": [],                             /* List of file name suffixes to search when resolving a module. */
    // "allowImportingTsExtensions": true,               /* Allow imports to include TypeScript file extensions. Requires '--moduleResolution bundler' and either '--noEmit' or '--emitDeclarationOnly' to be set. */
    // "rewriteRelativeImportExtensions": true,          /* Rewrite '.ts', '.tsx', '.mts', and '.cts' file extensions in relative import paths to their JavaScript equivalent in output files. */
    // "resolvePackageJsonExports": true,                /* Use the package.json 'exports' field when resolving package imports. */
    // "resolvePackageJsonImports": true,                /* Use the package.json 'imports' field when resolving imports. */
    // "customConditions": [],                           /* Conditions to set in addition to the resolver-specific defaults when resolving imports. */
    // "noUncheckedSideEffectImports": true,             /* Check side effect imports. */
    "resolveJsonModule": true,                        /* Enable importing .json files. */
    // "allowArbitraryExtensions": true,                 /* Enable importing files with any extension, provided a declaration file is present. */
    // "noResolve": true,                                /* Disallow 'import's, 'require's or '<reference>'s from expanding the number of files TypeScript should add to a project. */

    /* JavaScript Support */
    // "allowJs": true,                                  /* Allow JavaScript files to be a part of your program. Use the 'checkJS' option to get errors from these files. */
    // "checkJs": true,                                  /* Enable error reporting in type-checked JavaScript files. */
    // "maxNodeModuleJsDepth": 1,                        /* Specify the maximum folder depth used for checking JavaScript files from 'node_modules'. Only applicable with 'allowJs'. */

    /* Emit */
    // "declaration": true,                              /* Generate .d.ts files from TypeScript and JavaScript files in your project. */
    // "declarationMap": true,                           /* Create sourcemaps for d.ts files. */
    // "emitDeclarationOnly": true,                      /* Only output d.ts files and not JavaScript files. */
    // "sourceMap": true,                                /* Create source map files for emitted JavaScript files. */
    // "inlineSourceMap": true,                          /* Include sourcemap files inside the emitted JavaScript. */
    "noEmit": false,                                   /* Disable emitting files from a compilation. */
    // "outFile": "./",                                  /* Specify a file that bundles all outputs into one JavaScript file. If 'declaration' is true, also designates a file that bundles all .d.ts output. */
    "outDir": "./dist",                                   /* Specify an output folder for all emitted files. */
    // "removeComments": true,                           /* Disable emitting comments. */
    // "importHelpers": true,                            /* Allow importing helper functions from tslib once per project, instead of including them per-file. */
    // "downlevelIteration": true,                       /* Emit more compliant, but verbose and less performant JavaScript for iteration. */
    // "sourceRoot": "",                                 /* Specify the root path for debuggers to find the reference source code. */
    // "mapRoot": "",                                    /* Specify the location where debugger should locate map files instead of generated locations. */
    // "inlineSources": true,                            /* Include source code in the sourcemaps inside the emitted JavaScript. */
    // "emitBOM": true,                                  /* Emit a UTF-8 Byte Order Mark (BOM) in the beginning of output files. */
    // "newLine": "crlf",                                /* Set the newline character for emitting files. */
    // "stripInternal": true,                            /* Disable emitting declarations that have '@internal' in their JSDoc comments. */
    // "noEmitHelpers": true,                            /* Disable generating custom helper functions like '__extends' in compiled output. */
    // "noEmitOnError": true,                            /* Disable emitting files if any type checking errors are reported. */
    // "preserveConstEnums": true,                       /* Disable erasing 'const enum' declarations in generated code. */
    // "declarationDir": "./",                           /* Specify the output directory for generated declaration files. */

    /* Interop Constraints */
    "isolatedModules": true,                          /* Ensure that each file can be safely transpiled without relying on other imports. */
    // "verbatimModuleSyntax": true,                     /* Do not transform or elide any imports or exports not marked as type-only, ensuring they are written in the output file's format based on the 'module' setting. */
    // "isolatedDeclarations": true,                     /* Require sufficient annotation on exports so other tools can trivially generate declaration files. */
    // "erasableSyntaxOnly": true,                       /* Do not allow runtime constructs that are not part of ECMAScript. */
    "allowSyntheticDefaultImports": true,             /* Allow 'import x from y' when a module doesn't have a default export. */
    "esModuleInterop": true,                             /* Emit additional JavaScript to ease support for importing CommonJS modules. This enables 'allowSyntheticDefaultImports' for type compatibility. */
    // "preserveSymlinks": true,                         /* Disable resolving symlinks to their realpath. This correlates to the same flag in node. */
    "forceConsistentCasingInFileNames": true,            /* Ensure that casing is correct in imports. */

    /* Type Checking */
    "strict": true,                                      /* Enable all strict type-checking options. */
    // "noImplicitAny": true,                            /* Enable error reporting for expressions and declarations with an implied 'any' type. */
    // "strictNullChecks": true,                         /* When type checking, take into account 'null' and 'undefined'. */
    // "strictFunctionTypes": true,                      /* When assigning functions, check to ensure parameters and the return values are subtype-compatible. */
    // "strictBindCallApply": true,                      /* Check that the arguments for 'bind', 'call', and 'apply' methods match the original function. */
    "strictPropertyInitialization": false,             /* Check for class properties that are declared but not set in the constructor. */
    // "strictBuiltinIteratorReturn": true,              /* Built-in iterators are instantiated with a 'TReturn' type of 'undefined' instead of 'any'. */
    // "noImplicitThis": true,                           /* Enable error reporting when 'this' is given the type 'any'. */
    // "useUnknownInCatchVariables": true,               /* Default catch clause variables as 'unknown' instead of 'any'. */
    // "alwaysStrict": true,                             /* Ensure 'use strict' is always emitted. */
    // "noUnusedLocals": true,                           /* Enable error reporting when local variables aren't read. */
    // "noUnusedParameters": true,                       /* Raise an error when a function parameter isn't read. */
    // "exactOptionalPropertyTypes": true,               /* Interpret optional property types as written, rather than adding 'undefined'. */
    // "noImplicitReturns": true,                        /* Enable error reporting for codepaths that do not explicitly return in a function. */
    // "noFallthroughCasesInSwitch": true,               /* Enable error reporting for fallthrough cases in switch statements. */
    // "noUncheckedIndexedAccess": true,                 /* Add 'undefined' to a type when accessed using an index. */
    // "noImplicitOverride": true,                       /* Ensure overriding members in derived classes are marked with an override modifier. */
    // "noPropertyAccessFromIndexSignature": true,       /* Enforces using indexed accessors for keys declared using an indexed type. */
    // "allowUnusedLabels": true,                        /* Disable error reporting for unused labels. */
    // "allowUnreachableCode": true,                     /* Disable error reporting for unreachable code. */

    /* Completeness */
    // "skipDefaultLibCheck": true,                      /* Skip type checking .d.ts files that are included with TypeScript. */
    "skipLibCheck": true                                 /* Skip type checking all .d.ts files. */
  },
  "include": [
    "index.ts",
    "src/**/*.ts",
    "src/@types/**/*.d.ts", "src/Shared/Swagger/schemas/tools/generateSchema.ts",
      
  ],
  "exclude": [
    "node_modules",
    "dist",
    "data", 
    "test",
    "**/*.test.ts",
    "**/*.help.ts"
    
  ]
}
EOL
# Crear el archivo tsconfig.test.json
cat > "$PROJECT_DIR/tsconfig.test.json" <<EOL
{
  "extends": "./tsconfig.json",
  "include": [
    "index.ts",
    "src/**/*.ts",
    "test/**/*.ts",
    "test/**/*.setup.ts",
  ],
  "exclude": [
    "node_modules",
    "dist",
    "data"
  ]
}
EOL
# Crear el archivo package.json
cat > "$PROJECT_DIR/package.json" <<EOL
{
  "name": "$PROYECTO_PACKAGE",
  "version": "1.0.0",
  "main": "dist/index.js",
  "type": "module",
  "directories": {
    "test": "test"
  },
  "scripts": {
    "dev": "cross-env NODE_ENV=development tsx watch ./index.ts",
    "build": "tsc --project tsconfig.json",
    "start": "cross-env NODE_ENV=production node dist/index.js",
    "lint": "ts-standard",
    "lint:fix": "ts-standard --fix",
    "unit:test": "cross-env NODE_ENV=test node --experimental-vm-modules node_modules/jest/bin/jest.js --detectOpenHandles",
    "int:test": "cross-env NODE_ENV=test node --experimental-vm-modules node_modules/jest/bin/jest.js --detectOpenHandles",
    "gen:schema": "tsx src/Shared/Swagger/schemas/tools/generateSchema.ts"
  },
  "ts-standard": {
    "project": "./tsconfig.json",
    "env": [
      "node",
      "jest"
    ],
    "ignore": [
      "dist",
      "node_modules",
      "data"
    ]
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "description": "",
  "dependencies": {
  },
  "devDependencies": {
  }
}
EOL
# Crear README.md
cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express con Typescript

Base para el proyecto $PROYECTO_VALIDO de Express.ts con entornos de ejecución y manejo de errores.

## Sobre la API:

Esta API fue construida de manera híbrida. Es decir, la parte de Repositories, Services y Controllers está desarrollada bajo el paradigma OOP (Programación Orientada a Objetos). Sin embargo, los routers y la aplicación en sí no lo están. Los middlewares, si bien forman parte de una clase, esta es una clase de métodos estáticos. De esta forma, se aprovecha la escalabilidad y el orden de la POO, pero al mismo tiempo se minimiza el consumo de recursos utilizando funciones puras siempre que sea posible (las clases en JavaScript tienen un costo, aunque no muy elevado).

En esta plantilla encontrará ambos paradigmas funcionando codo a codo. A partir de aquí, puede adaptarla según su preferencia. Si bien está construida de una manera básica, es funcional. Al revisar el código podrá ver, si desea mantener este enfoque, cómo continuar. ¡Buena suerte y buen código!

## Cómo comenzar:

### Instalaciones:

La app viene con las instalaciones básicas para comenzar a trabajar con Mongoose y una base de datos MongoDb. Las variables de entorno vienen ya con un usuario por defecto (random) y una base de datos ficticia que en caso de ejecutarse se creará, usted deberia cambiar esto por su propia base de datos apropiada para cada entorno.

### Scripts disponibles:

- \`npm start\`: Inicializa la app en modo producción con Node.js y Express (.env.production).
- \`npm run dev\`: Inicializa la app en modo desarrollo con jsx y Express (.env.development).
- \`npm run unit:test\`: Ejecuta todos los tests. También puede ejecutarse un test específico, por ejemplo: \`npm run unit:test EnvDb\`. La app se inicializa en modo test (.env.test).
- \`npm run lint\`: Ejecuta el linter (ts-standard) y analiza la sintaxis del código (no realiza cambios).
- \`npm run lint:fix\`: Ejecuta el linter y corrige automáticamente los errores.
- \`npm run gen:schema\`: Inicializa la función \`generateSchema\`, que genera documentación Swagger para las rutas mediante una guía por consola. Si bien es susceptible de mejora, actualmente resulta muy útil para agilizar el trabajo de documentación.

La aplicación incluye un servicio de ejemplo que muestra su funcionalidad. En la carpeta \`Features/Services/user\` se encuentra un servicio modelo de usuario, con un Servicio, Controlador, Dto y test. El archivo \`user.route.ts\` conecta esta funcionalidad con la app a través de \`mainRouter\` (\`routes.ts\`).

La aplicación puede ejecutarse con \`npm run dev\` (modo desarrollo) o \`npm start\` (producción). Tambien puede (sería lo ideal) desarrollar la app por medio de los test, lo cual puede hacerse desde el comienzo.

Se requieren dos bases de datos: una para desarrollo y otra para test.

### Documentación y rutas:

Esta api cuenta con documentación por medio de Swagger, al inicializar la app en modo dev aparecerá el endpoint adonde se verán los endpoints declarados.

Para declarar los endpoints simplemente se ejecuta el comando \`npm run gen:schema\`, y aparecerá en la consola un menú interactivo adonde podrá ingresar los items, campos, parametros y rutas.

La documentación se escribe en \`jsdoc\`, asimismo se creará un archivo \`json\` con los parametros, el menú los guiará y automáticamente se añadiran a la documentación. Es posible que en los casos en que haya endpoints especiales como login y otros, haya que crearlos a mano en el mismo archivo, asi como también si se utilza o no protección con jwt, pero esta automatización garantiza que una gran parte del trabajo estará hecha y servirá de modelo a todo lo que haya que documentar.

### Manejo de errores:

- La función \`catchController\` se utiliza para envolver los controladores, como se detalla en \`BaseController.ts\`.
- La función \`throwError\` se utiliza en los servicios. Recibe un mensaje y un código de estado:

\`\`\`javascript
import eh from "./Configs/errorHandlers.ts";

eh.throwError("Usuario no encontrado", 404);
\`\`\`

- La función \`middError\` se usa en los middlewares:

\`\`\`javascript
import eh from "./Configs/errorHandlers.ts";

if (!user) {
  return next(eh.middError("Falta el usuario", 400));
}
\`\`\`

### Acerca de \`MiddlewareHandler.ts\`

Esta clase estática contiene una serie de métodos auxiliares para evitar la repetición de código en middlewares activos.

#### Métodos de validación disponibles:

- \`validateFields\`: validación y tipado de datos del body
- \`validateFieldsWithItems\`: validación de un objeto con un array de objetos anidados
- \`validateQuery\`: validación y tipado de queries (con copia debido a Express 5)
- \`validateRegex\`: validación de parámetros del body mediante expresiones regulares
- \`middUuid\`: validación de UUID
- \`middObjectId\`: validación de ID como ObjectId de mongoose.
- \`middIntId\`: validación de ID como número entero

#### validateFields:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const user = [
  {name: 'email', type: 'string'},
  {name: 'password', type: 'string'},
  {name: 'phone', type: 'int'}
];

router.post('/', MiddlewareHandler.validateFields(user), controlador);
\`\`\`

Tipos de datos permitidos:
- \`'string'\`
- \`'int'\`
- \`'float'\`
- \`'boolean'\`
- \`'array'\` (no valida su contenido)

Los datos no declarados serán eliminados del body. Si falta alguno de los declarados o no puede convertirse al tipo esperado, se emitirá el error correspondiente.

#### validateFieldsWithItems:

Valida también un array anidado:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const user = [
  {name: 'email', type: 'string'},
  {name: 'password', type: 'string'},
  {name: 'phone', type: 'int'}
];

const address = [
  {name:'street', type:'string'},
  {name:'number', type:'int'}
];

router.post('/', MiddlewareHandler.validateFieldsWithItems(user, address, 'address'), controlador);
\`\`\`

Ejemplo de body:

\`\`\`json
{
  "name": "Leanne Graham",
  "password": "xxxxxxxx",
  "phone": 5578896,
  "address": [
    { "street": "Kulas Light", "number": 225 },
    { "street": "Victor Plains", "number": 1230 }
  ]
}
\`\`\`

#### validateQuery:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const queries = [
  { name: 'page', type: 'int' },
  { name: 'size', type: 'float' },
  { name: 'fields', type: 'string' },
  { name: 'truthy', type: 'boolean' }
];

router.get('/', MiddlewareHandler.validateQuery(queries), controlador);
\`\`\`

Express 5 convierte \`req.query\` en inmutable. La copia validada estará disponible en \`req.validatedQuery\`.

#### validateRegex:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

router.post('/', MiddlewareHandler.validateRegex(emailRegex, 'email', 'Introduzca un mail válido'), controlador);
\`\`\`

#### middUuid y middIntId:

Funcionan de forma similar, cambiando solo el tipo de dato a validar:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

router.get('/:userId', MiddlewareHandler.middIntId('userId'), controlador);
\`\`\`

---

Se ha intentado cubrir la mayor cantidad de casos de uso posibles. Por supuesto, pueden existir muchos más, pero esta base ofrece un punto de partida sólido.

---

Espero que esta explicación te sea útil. ¡Suerte!
EOL
# Mensaje de confirmación
echo "Estructura de la aplicación Express creada en '$PROJECT_DIR'."

# Ir a la carpeta del PROJECT_DIR
cd $PROJECT_DIR

# Instalar dependencias
echo "Instalando dependencias:..."
npm install bcrypt cors cross-env dotenv express jsonwebtoken mongoose morgan uuid
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install -D typescript@5.8.3 @jest/globals @types/bcrypt @types/cors @types/dotenv @types/express @types/inquirer @types/jest @types/jsonwebtoken @types/mongoose @types/morgan @types/supertest @types/swagger-jsdoc @types/swagger-ui-express inquirer jest supertest swagger-jsdoc swagger-ui-express ts-jest ts-node ts-standard tsx
echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."



