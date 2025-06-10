#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Configs,Shared,Shared/Middlewares,Shared/Middlewares/testHelpers,Shared/Controllers,Shared/Services,Shared/Services/testHelpers,Shared/Models,Modules,Modules/users,Shared/Swagger,Shared/Swagger/schemas,Shared/Swagger/schemas/tools}
mkdir -p $PROJECT_DIR/test/helperTest

# Crear el archivo index.js en src
cat > "$PROJECT_DIR/index.js" <<EOL
import app from './src/app.js'
import env from './src/Configs/envConfig.js'
// import { connectDB } from './src/Configs/database.js'

app.listen(env.Port, async () => {
  try {
    //await connectDB()
    console.log(\`Servidor corriendo en http://localhost:\${env.Port}\nServer in \${env.Status}\`)
    if (env.Status === 'development') {
      console.log(\`Swagger: Vea y pruebe los endpoints en http://localhost:\${env.Port}/api-docs\`)
    }
  } catch (error) {
    console.error('Error conectando la DB: ', error)
  }
})
EOL
# Crear el archivo app.js en src
cat > "$PROJECT_DIR/src/app.js" <<EOL
import express from 'express'
import morgan from 'morgan'
import cors from 'cors'
import helmet from 'helmet'
import mainRouter from './routes.js'
import eh from './Configs/errorHandlers.js'
import env from './Configs/envConfig.js'
import swaggerUi from 'swagger-ui-express'
import swaggerJsDoc from 'swagger-jsdoc'
import swaggerOptions from './Swagger/swaggerOptions.js'

// Swagger:
const swaggerDocs = swaggerJsDoc(swaggerOptions)
const swaggerUiOptions = {
  swaggerOptions: {
    docExpansion: 'none' // 👈 Oculta todas las rutas al cargar
  }
}
// Inicializo la app:
const app = express()
app.use(morgan('dev'))
app.use(cors())
app.use(helmet())
app.use(express.json())
app.use(eh.validJson)
// Habilita Swagger:
if (env.Status === 'development') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocs, swaggerUiOptions))
}

app.use(mainRouter)

app.use((req, res, next) => {
  return next(eh.middError('Not Found', 404))
})
app.use((err, req, res, next) => {
  const status = err.status || 500
  const message = err.message || 'Unexpected server error'
  res.status(status).json({
    success: false,
    message,
    results: 'Fail'
  })
})

export default app
EOL
# Crear el archivo routes.js en src
cat > "$PROJECT_DIR/src/routes.js" <<EOL
import express from 'express'
import userRouter from './Modules/users/user.routes.js'

const mainRouter = express.Router()

mainRouter.use('/api/user', userRouter)

export default mainRouter
EOL
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

const Status = process.env.NODE_ENV
const { PORT, URI_DB, } = process.env


export default {
  Port: parseInt(PORT),
  UriDb: URI_DB,
  Status,
}
EOL
# Crear archivo de manejo de errores de Express
cat > "$PROJECT_DIR/src/Configs/errorHandlers.js" <<EOL
import env from './envConfig.js'

class CustomError extends Error {
  constructor (log = false) {
    super()
    this.log = log
  }

  throwError (message, status, err = null) {
    const error = new Error(message)
    error.status = Number(status) || 500
    if (this.log && err) {
      console.error('Error: ', err)
    }
    throw error
  }

  processError (err, contextMessage) {
    const defaultStatus = 500
    const status = err.status || defaultStatus

    const message = err.message
      ? \`\${contextMessage}: \${err.message}\`
      : contextMessage

    // Creamos un nuevo error con la información combinada
    const error = new Error(message)
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
const environment = env.Status
const errorHandler = new CustomError(environment === 'development')

export default {
  catchController: (controller) => {
    return (req, res, next) => {
      return Promise.resolve(controller(req, res, next)).catch(next)
    }
  },

  throwError: errorHandler.throwError.bind(errorHandler),

  processError: errorHandler.processError.bind(errorHandler),

  middError: (message, status = 500) => {
    const error = new Error(message)
    error.status = Number(status) || 500
    return error
  },

  validJson: (err, req, res, next) => {
    if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
      res.status(400).json({ success: false, data: null, message: 'Invalid JSON format' })
    } else {
      next()
    }
  }
}
/*
Ejemplo de uso:
 } catch (err) {
      Preservamos el error original pero añadimos contexto
      errorHandler.processError(err, 'Error al buscar usuario');
    }

      */
EOL
# Crear archivo de configuracion de base de datos Mongodb
cat > "$PROJECT_DIR/src/Configs/database.js" <<EOL
import { connect } from 'mongoose'
import env from './envConfig.js'

// const DB_URI= \`mongodb://\${onlyOne}\`

const connectDB = async () => {
  try {
    await connect(env.UriDb)
    console.log('DB conectada exitosamente ✅')
  } catch (error) {
    console.error(error + ' algo malo pasó 🔴')
  }
}

export default connectDB
EOL
#Crear el archivo de test para entorno y db
cat > "$PROJECT_DIR/src/Configs/EnvDb.test.js" <<EOL
import env from './envConfig.js'
import User from '../shared/Models/user.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.js" y existencia de tablas en DB.', () => {
  afterAll(() => {
    console.log('Finalizando todas las pruebas...')
  })

  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${env.Status}\n\` +
                   \`Base de datos de testing: \${env.UriDb}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: mongodb://127.0.0.1:27017/testing')
  })
  it('Debería hacer una consulta básica en cada tabla sin errores', async () => {
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
# Crear el modelo y el index
cat > "$PROJECT_DIR/src/Shared/Models/user.js" <<EOL
import mongoose from 'mongoose'
import { applyBaseSchema } from './baseSchemaMixin.js'

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

const User = mongoose.model('User', userSchema)

export default User
EOL
# Crear la base de modelos
cat > "$PROJECT_DIR/src/Shared/Models/baseSchemaMixin.js" <<EOL
const baseSchemaFields = {
  enabled: { type: Boolean, default: true },
  deleted: { type: Boolean, default: false }
}

export function applyBaseSchema (schema) {
  schema.add(baseSchemaFields)

  // Garantiza que los campos estén siempre presentes
  schema.pre('save', function (next) {
    if (this.enabled === undefined) this.enabled = true
    if (this.deleted === undefined) this.deleted = false
    next()
  })

  // Método de instancia: soft delete
  schema.methods.softDelete = function () {
    this.deleted = true
    this.enabled = false
    return this.save()
  }

  // Método estático: encuentra solo activos
  schema.statics.findEnabled = function (filter = {}) {
    return this.find({ ...filter, enabled: true, deleted: false })
  }

  return schema
}
EOL
# Crear el modelo de Test
cat > "$PROJECT_DIR/test/helperTest/modelTest.js" <<EOL
import mongoose from "mongoose";
import {applyBaseSchema} from '../../src/Shared/Models/baseSchemaMixin.js'

const testSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      unique: true,
    },
    count: {
      type: Number,
      required: true,

    },
    picture: {
      type: String,
      required: true,
    },
    
  },
  {
    timestamps: true,
  }
);

applyBaseSchema(testSchema)

const Test = mongoose.model("Test", testSchema);

export default Test;
EOL
# Crear el Controlador
cat > "$PROJECT_DIR/src/Shared/Controllers/BaseController.js" <<EOL
import eh from '../../Configs/errorHandlers.js'
const catchController = eh.catchController

export default class BaseController {
  constructor (service) {
    this.service = service
  }

  // Methods:
  static responder (res, status, success, message = null, info= null, results = null) {
    res.status(status).json({ success, message, info, results })
  }

  // Controllers:
  create = catchController(async (req, res) => {
    const data = req.body
    const response = await this.service.create(data)
    return BaseController.responder(res, 201, true, response.message, null, response.results)
  })

  getAll = catchController(async (req, res) => {
    const queryObject = req.context?.query || req.query
    const response = await this.service.getAll(queryObject)
    return BaseController.responder(res, 200, true, response.message, response.info, response.results)
  })
  getAdmin = catchController(async (req, res) => {
    const queryObject = req.context?.query || req.query
    const response = await this.service.getAllAdmin(queryObject)
    return BaseController.responder(res, 200, true, response.message, response.info, response.results)
  })

  getById = catchController(async (req, res) => {
    const { id } = req.params
    const response = await this.service.getById(id)
    return BaseController.responder(res, 200, true, response.message, null, response.results)
  })

  update = catchController(async (req, res) => {
    const { id } = req.params
    const newData = req.body
    const response = await this.service.update(id, newData)
    return BaseController.responder(res, 200, true, response.message, null, response.results)
  })

  delete = catchController(async (req, res) => {
    const { id } = req.params
    const response = await this.service.delete(id)
    return BaseController.responder(res, 200, true, response.message, null, response.results)
  })
}
EOL
# Crear el servicio
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.js" <<EOL
import eh from '../../Configs/errorHandlers.js'

class BaseService {
  constructor (model, useImages = false, deleteImages = null, parserFunction = null, modelName = '') {
    this.model = model
    this.useImages = useImages
    this.deleteImages = deleteImages
    this.parserFunction = parserFunction
    this.modelName = modelName
  }

  async create (data, whereField = '') {
    try {
      const whereClause = whereField ? { [whereField]: data[whereField] } : {}
      if (whereField && !data[whereField]) {
        eh.throwError(\`Missing field '\${whereField}' for uniqueness check\`, 400)
      }
      //console.log('whereClause:', whereClause)
      if (whereField) {
        const exists = await this.model.findOne(whereClause)
        if (exists) { eh.throwError(\`This \${whereField} already exists\`, 400) }
      }
      const newDoc = await this.model.create(data)

      const identifier = whereField && data[whereField] ? \`\${data[whereField]}\` : ''
      return {
        message: \`\${whereField} \${identifier}created successfully\`,
        results: this.parserFunction ? this.parserFunction(newDoc) : newDoc
      }
    } catch (error) {
      eh.processError(error, 'Error created')
    }
  }

  async #findElements (queryObject, isAdmin=false) {
    const { page = 1, limit = 10, filters = {}, sort = {} } = queryObject
    const skip = (page - 1) * limit

    // Filtro base para excluir eliminados
    const query = { deleted: false }

    // Filtros dinámicos
    for (const key in filters) {
      const value = filters[key]
      if (typeof value === 'string') {
        query[key] = { \$regex: value, \$options: 'i' }
      } else {
        query[key] = value
      }
    }
    const sortOptions = {}
    for (const key in sort) {
      const order = sort[key]
      sortOptions[key] = order === 'desc' ? -1 : 1
    }
    const conditionalSearch = isAdmin
      ? await this.model.find(query).sort(sortOptions).skip(skip).limit(limit)
      : await this.model.findEnabled(query).sort(sortOptions).skip(skip).limit(limit)

    const countQuery = isAdmin
      ? query
      : { ...query, enabled: true, deleted: false }

    const [results, total] = await Promise.all([
      conditionalSearch,
      this.model.countDocuments(countQuery)
    ])
    const finalResults = this.parserFunction ? results.map(doc => this.parserFunction(doc)) : results
    return {
      message: 'Elements found successfully!',
      info: {
        page: parseInt(page),
        limit,
        totalPages: Math.ceil(total / limit),
        count: total,
        sort: sort
      },
      results: finalResults
    }
  }

  async getAll (queryObject){
    return await this.#findElements(queryObject, false)
  }
  async getAllAdmin (queryObject){
    return await this.#findElements(queryObject, true)
  }

  async getById (id) {
    const doc = await this.model.findOne({ _id: id, deleted: false })
    if (!doc) { eh.throwError('Not found', 404) }
    return {
      message: \`The \${this.modelName} was found!\`,
      results: this.parserFunction ? this.parserFunction(doc) : doc
    }
  }

  async update (id, data) {
    try {
      let imageUrl = ''
      const register = await this.model.findOne({ _id: id, deleted: false })
      if (!register) { eh.throwError(\`\${this.modelName} not found\`, 404) }
      if (this.useImages) {
        if (register.picture !== data.picture) { imageUrl = register.picture }
      }
      const newData = await this.model.updateOne(
        { _id: id, deleted: false },
        data,
        { new: true }
      )
      if (this.useImages && imageUrl.trim()) {
        await this.deleteImages(imageUrl)
      }
      return {
        message: \`\${this.modelName} updated successfully!\`,
        results: newData
      }
    } catch (error) {
      eh.processError(error, 'Error updating')
    }
  }
  async #conditionalDel (id, isHard) {
    try {
      let imageUrl = ''
      const register = await this.model.findOne({ _id: id })
      if (!register) { eh.throwError(\`\${this.modelName} not found\`, 404) }

      if (this.useImages) { imageUrl = register.picture }
      const  conditionalDelete = isHard
        ? await this.model.findByIdAndDelete(id)
        : await this.model.findByIdAndUpdate(id, { deleted: true }, { new: true })

      const erased = await conditionalDelete
      if (this.useImages && imageUrl.trim() && isHard) {
        await this.deleteImages(imageUrl)
      }
      const message = isHard ? 'hard deleted': 'deleted'
      return {
        message: \`\${this.modelName} \${message} successfully\`,
        results: isHard ? erased : null
      }
    } catch (error) {
      eh.processError(error, 'Error deleting')
    }
  }

  async delete (id) {
    return await this.#conditionalDel(id, false)
  }

  async hardDelete (id) {
    return await this.#conditionalDel(id, true)
  }

}

export default BaseService
EOL
# Crear el  test para el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.test.js" <<EOL
import BaseService from './BaseService.js'
import Test from '../../../test/helperTest/modelTest.js'
import * as info from './testHelpers/testHelp.js'
import { setId, getId } from '../../../test/helperTest/testStore.js'
import mongoose from 'mongoose'
import * as fns from '../../../test/helperTest/generalFunctions.js'
import { testSeeds } from './testHelpers/seeds.js'
import { resetDatabase } from '../../../test/jest.setup.js'

// model, useImages, deleteImages, parserFunction
const testImsSuccess = new BaseService(Test, true, fns.deletFunctionTrue, info.infoClean, 'Test')
const testImgFailed = new BaseService(Test, true, fns.deletFunctionFalse, info.infoClean, 'Test')
const testParsed = new BaseService(Test, false, null, info.infoClean, 'Test')

describe('Unit tests for the BaseService class: CRUD operations.', () => {
  afterAll(async ()=>{
    await resetDatabase()
  })
  describe('The "create" method for creating a service', () => {
    it('should create an item with the correct parameters', async () => {
      const element = { title: 'page', count: 5, picture: 'https//pepe.com' }
      const response = await testParsed.create(element, 'title')
      setId(response.results.id)
      expect(response.message).toBe('title page created successfully')
      // expect(response.results instanceof mongoose.Model).toBe(true);
      expect(response.results).toEqual(info.resultParsedCreate)
    })
    it('should throw an error when attempting to create the same item twice (error handling)', async () => {
      const element = { title: 'page', count: 5, picture: 'https//pepe.com' }
      try {
        await testParsed.create(element, 'title')
        throw new Error('❌ Expected a duplication error, but none was thrown')
      } catch (error) {
        expect(error.status).toBe(400)
        expect(error).toBeInstanceOf(Error)
        expect(error.message).toBe('Error created: This title already exists')
      }
    })
  })
  describe('"GET" methods. Return one or multiple services..', () => {
    beforeAll(async ()=>{
      await Test.insertMany(testSeeds)
    })
    it('"getAll" method: should return an array of services', async () => {
      const queryObject = { page: 1, limit: 10, filters: {}, sort:{} }
      const response = await testParsed.getAll(queryObject)
      expect(response.message).toBe('Elements found successfully!')
      expect(response.info).toEqual({ page: 1, limit: 10, totalPages: 2, count: 17, sort: {} })
      expect(response.results.length).toBe(10)
    })
    it('"getAll" method should return page 2 of results', async () => {
      const queryObject = { page: 2, limit: 10, filters: {}, sort: {} }
      const response = await testParsed.getAll(queryObject)
      expect(response.results.length).toBeLessThanOrEqual(10)
      expect(response.info.page).toBe(2)
    })
    it('"getAll" method should return sorted results (by title desc)', async () => {
      const queryObject = { page: 1, limit: 5, sort: { title: 'desc' } }
      const response = await testParsed.getAll(queryObject)
      const titles = response.results.map(r => r.title)
      const sortedTitles = [...titles].sort().reverse()
      expect(titles).toEqual(sortedTitles)
    })

    it('"getById" method: should return an service', async () => {
      const id = getId()
      const response = await testParsed.getById(id)
      expect(response.results).toEqual(info.resultParsedCreate)
    })
    it('"getById" should throw an error if service not exists', async () => {
      try {
        const invalidId = new mongoose.Types.ObjectId()
        await testParsed.getById(invalidId)
        throw new Error('❌ Expected a "Not found" error, but none was thrown')
      } catch (error) {
        expect(error.status).toBe(404)
        expect(error).toBeInstanceOf(Error)
        expect(error.message).toBe('Not found')
      }
    })
  })
  describe('The "update" method - Handles removal of old images from storage.', () => {
    it('should update the document without removing any images', async () => {
      const id = getId()
      const newData = info.newData
      const response = await testParsed.update(id, newData)
      expect(response.message).toBe('Test updated successfully!')
      expect(response.results).toEqual({
        acknowledged: true,
        modifiedCount: 1,
        upsertedId: null,
        upsertedCount: 0,
        matchedCount: 1
      })
    })
    it('should update the document and remove the previous image', async () => {
      const id = getId()
      const newData = { picture: 'https://imagen.com.ar' }
      const response = await testImsSuccess.update(id, newData)
      expect(response.message).toBe('Test updated successfully!')
    })
    it('should throw an error if image deletion fails during update', async () => {
      const id = getId()
      const newData = { picture: 'https://imagen44.com.ar' }
      try {
        const resp = await testImgFailed.update(id, newData)
        console.log('a ver si entro: ', resp)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error updating: Error processing ImageUrl: https://imagen.com.ar')
      }
    })
  })
  describe('The "delete" method.', () => {
    it('should delete a document successfully (soft delete)', async () => {
      const id = getId()
      const response = await testImgFailed.delete(id)
      expect(response.message).toBe('Test deleted successfully')
    })
    it('should throw an error if image deletion fails during hard delete', async () => {
      const id = getId()
      try {
        await testImgFailed.hardDelete(id)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error deleting: Error processing ImageUrl: https://imagen44.com.ar')
      }
    })
  })
})

EOL
# Crear el archivo con los seeds
cat > "$PROJECT_DIR/src/Shared/Services/testHelpers/seeds.js" <<EOL
export const testSeeds = [
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
# Crear el Servicio de muestra
cat > "$PROJECT_DIR/src/Shared/Services/testHelpers/testHelp.js" <<EOL
export const infoClean = (data) => {
  return {
    id: data._id.toString(),
    title: data.title,
    count: data.count,
    picture: data.picture,
    enabled: data.enabled
  }
}
export const resultParsedCreate = {
  id: expect.any(String),
  title: 'page',
  count: 5,
  picture: 'https//pepe.com',
  enabled: true
}
export const newData = {
  title: 'page',
  count: 5,
  picture: 'https://donJose.com',
  enabled: true
}
export const responseNewData = {
  id: expect.any(String),
  title: 'page',
  count: 5,
  picture: 'https://donJose.com',
  enabled: true
}
EOL

# Crear el Middleware de uso general
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddlewareHandler.js" <<EOL
import { validate as uuidValidate } from 'uuid'
import mongoose from 'mongoose'

class MiddlewareHandler {
  static middError (message, status = 500) {
    const error = new Error(message)
    error.status = status
    return error
  }

   // Nueva función para manejar valores por defecto según el tipo
  static getDefaultValue (type) {
    switch (type) {
      case 'boolean': return false
      case 'int': return 1
      case 'float': return 1.0
      case 'string': return ''
      default: return null
    }
  }

  static validateBoolean (value) {
    if (typeof value === 'boolean') return value
    if (value === 'true') return true
    if (value === 'false') return false
    throw new Error('Invalid boolean value')
  }

  static validateInt (value) {
    const intValue = Number(value)
    if (isNaN(intValue) || !Number.isInteger(intValue)) throw new Error('Invalid integer value')
    return intValue
  }

  static validateFloat (value) {
    const floatValue = parseFloat(value)
    if (isNaN(floatValue)) throw new Error('Invalid float value')
    return floatValue
  }

  // Nueva función para aislar la lógica de validación
  static validateValue (value, fieldType, fieldName, itemIndex = null) {
    const indexInfo = itemIndex !== null ? \` in item[\${itemIndex}]\` : ''

    switch (fieldType) {
      case 'boolean':
        return MiddlewareHandler.validateBoolean(value)
      case 'int':
        return MiddlewareHandler.validateInt(value)
      case 'float':
        return MiddlewareHandler.validateFloat(value)
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

  static validateFields (requiredFields = []) {
    return (req, res, next) => {
      const newData = req.body
      if (!newData || Object.keys(newData).length === 0) {
        return next(MiddlewareHandler.middError('Invalid parameters', 400))
      }
      const missingFields = requiredFields.filter(field => !(field.name in newData))
      if (missingFields.length > 0) {
        return next(MiddlewareHandler.middError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400))
      }
      try {
        requiredFields.forEach(field => {
          const value = newData[field.name]
          newData[field.name] = MiddlewareHandler.validateValue(value, field.type, field.name)
        })

        Object.keys(newData).forEach(key => {
          if (!requiredFields.some(field => field.name === key)) {
            delete newData[key]
          }
        })
      } catch (error) {
        return next(MiddlewareHandler.middError(error.message, 400))
      }
      req.body = newData
      next()
    }
  }

  static validateFieldsWithItems (requiredFields = [], secondFields = [], arrayFieldName) {
    return (req, res, next) => {
      try {
        // Copiar datos del body
        const firstData = { ...req.body } // Datos principales
        const secondData = Array.isArray(req.body[arrayFieldName])
          ? [...req.body[arrayFieldName]] // Array dinámico
          : null

        // Validar existencia de 'firstData'
        if (!firstData || Object.keys(firstData).length === 0) {
          return next(MiddlewareHandler.middError('Invalid parameters', 400))
        }

        // Verificar campos faltantes en 'firstData'
        const missingFields = requiredFields.filter((field) => !(field.name in firstData))
        if (missingFields.length > 0) {
          return next(MiddlewareHandler.middError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400))
        }

        try {
          requiredFields.forEach(field => {
            const value = firstData[field.name]
            firstData[field.name] = MiddlewareHandler.validateValue(value, field.type, field.name)
          })

          // Filtrar campos adicionales no permitidos en \`firstData\`
          Object.keys(firstData).forEach(key => {
            if (!requiredFields.some(field => field.name === key)) {
              delete firstData[key]
            }
          })
        } catch (error) {
          return next(MiddlewareHandler.middError(error.message, 400))
        }

        // Validar existencia y estructura de \`secondData\`
        if (!secondData || secondData.length === 0) {
          return next(MiddlewareHandler.middError(\`Missing \${arrayFieldName} array or empty array\`, 400))
        }

        // Validar contenido de 'secondData' (no debe contener strings)
        const invalidStringItems = secondData.filter((item) => typeof item === 'string')
        if (invalidStringItems.length > 0) {
          return next(
            MiddlewareHandler.middError(
              \`Invalid "\${arrayFieldName}" content: expected objects but found strings (e.g., \${invalidStringItems[0]})\`,
              400
            )
          )
        }

        // Validar cada objeto dentro de 'secondData'
        const validatedSecondData = secondData.map((item, index) => {
          const missingItemFields = secondFields.filter((field) => !(field.name in item))
          if (missingItemFields.length > 0) {
            return next(MiddlewareHandler.middError(
              \`Missing parameters in \${arrayFieldName}[\${index}]: \${missingItemFields.map(f => f.name).join(', ')}\`,
              400
            ))
          }

          // Validar tipos de campos en cada \`item\` usando la función aislada
          secondFields.forEach(field => {
            const value = item[field.name]
            item[field.name] = MiddlewareHandler.validateValue(value, field.type, field.name, index)
          })

          // Filtrar campos adicionales en cada \`item\`
          return secondFields.reduce((acc, field) => {
            acc[field.name] = item[field.name]
            return acc
          }, {})
        })

        // Actualizar \`req.body\` con datos validados
        req.body = {
          ...firstData,
          [arrayFieldName]: validatedSecondData // Asignar dinámicamente
        }

        // Continuar al siguiente middleware
        next()
      } catch (err) {
        return next(MiddlewareHandler.middError(err.message, 400)) // Manejar errores
      }
    }
  }

  // MiddlewareHandler.validateQuery([{name: 'authorId', type: 'int', required: true}]),
  static validateQuery(requiredFields = []) {
    return (req, res, next) => {
      try {
        const validatedQuery = {};
  
        requiredFields.forEach(({ name, type, default: defaultValue }) => {
          let value = req.query[name];
  
          if (value === undefined) {
            value = defaultValue !== undefined ? defaultValue : MiddlewareHandler.getDefaultValue(type);
          } else {
            value = MiddlewareHandler.validateValue(value, type, name);
          }
  
          validatedQuery[name] = value;
        });
  
        req.validatedQuery = validatedQuery; // Nuevo objeto tipado en lugar de modificar req.query
        next();
      } catch (error) {
        return next(MiddlewareHandler.middError(error.message, 400));
      }
    };
  }

  static validateRegex (validRegex, nameOfField, message = null) {
    return (req, res, next) => {
      if (!validRegex || !nameOfField || nameOfField.trim() === '') {
        return next(MiddlewareHandler.middError('Missing parameters in function!', 400))
      }
      const field = req.body[nameOfField]
      const personalizedMessage = message ? ' ' + message : ''
      if (!field || typeof field !== 'string' || field.trim() === '') {
        return next(MiddlewareHandler.middError(\`Missing \${nameOfField}\`, 400))
      }
      if (!validRegex.test(field)) {
        return next(MiddlewareHandler.middError(\`Invalid \${nameOfField} format!\${personalizedMessage}\`, 400))
      }
      next()
    }
  }

  static middUuid (fieldName) {
    return (req, res, next) => {
      const id = req.params[fieldName]
      if (!id) return next(MiddlewareHandler.middError('Falta el id', 400))
      if (!uuidValidate(id)) return next(MiddlewareHandler.middError('Parametros no permitidos', 400))
      next()
    }
  }

  static middObjectId (fieldName) {
    return (req, res, next) => {
      const id = req.params[fieldName]

      if (!id) {
        return next(MiddlewareHandler.middError('Falta el id', 400))
      }

      if (!mongoose.Types.ObjectId.isValid(id)) {
        return next(MiddlewareHandler.middError('Id no válido', 400))
      }

      next()
    }
  }

  static middIntId (fieldName) {
    return (req, res, next) => {
      const id = req.params[fieldName]
      if (!id) return next(MiddlewareHandler.middError('Falta el id', 400))
      if (!Number.isInteger(Number(id))) return next(MiddlewareHandler.middError('Parametros no permitidos', 400))
      next()
    }
  }

  static logRequestBody (req, res, next) {
    if (process.env.NODE_ENV !== 'test') {
      return next()
    }
    const timestamp = new Date().toISOString()
    console.log(\`[\${timestamp}] Request Body:\`, req.body)
    next()
  }
}

export default MiddlewareHandler
EOL
# Crear el archivo de test del Middleware:
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddHandler.test.js" <<EOL
import session from 'supertest'
import serverTest from './helperTest/serverTest.js'
const agent = session(serverTest)

describe('Clase "MiddlewareHandler". Clase estatica de middlewares. Validacion y tipado de datos', () => {
  describe('Metodo "validateFields". Validacion y tipado datos en body (POST y PUT)', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
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
  describe('Metodo "validateFieldsWithItems". Validacion y tipado datos en body (POST y PUT). Objeto anidado.', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [{ name: 'name', picture: 'string', enable: 'true', arreglo: [] }]
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
        items: [{ name: 'name', picture: 'string', enable: true, arreglo: [] }]
      })
    })
    it('deberia validar, tipar y arrojar un error si faltara algun parametro.', async () => {
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
    it('deberia validar, tipar y arrojar un error si no fuera posible tipar un parametro.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [{ name: 'name', picture: 'string', enable: '445', arreglo: [] }]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid boolean value')
    })
    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () => {
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
      expect(response.body.message).toBe('Passed middleware')
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
  describe('Metodo "validateQuery", validacion y tipado de queries en peticiones GET', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const response = await agent
        .get('/test/param?page=2&size=2.5&fields=pepe&truthy=true')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.validData).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })
    it('deberia llenar la query con valores por defecto si esta llegare vacía.', async () => {
      const response = await agent
        .get('/test/param')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.validData).toEqual({
        page: 1,
        size: 1,
        fields: '',
        truthy: false
      })
    })
    it('deberia arrojar un error si algun parametro incorrecto no se pudiere convertir.', async () => {
      const response = await agent
        .get('/test/param?page=pepe&size=2.5')
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid integer value')
    })
    it('deberia eliminar los valores que excedan a los declarados.', async () => {
      const response = await agent
        .get('/test/param?page=2&size=2.5&fields=pepe&truthy=true&demas=pepito')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.validData).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })
  })
  describe('Metodo "validateRegex", validacion de campo especifico a traves de un regex.', () => {
    it('deberia permitir el paso si el parametro es correcto.', async () => {
      const data = { email: 'emaildeprueba@ejemplo.com' }
      const response = await agent
        .post('/test/user')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        email: 'emaildeprueba@ejemplo.com'
      })
    })
    it('deberia arrojar un error si el parametro no es correcto.', async () => {
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
  describe('Metodo "middUuid", validacion de id en "param". Tipo de dato UUID v4', () => {
    it('deberia permitir el paso si el Id es uuid válido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76-191f905a2edd'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })
    it('deberia arrojar un error si el Id no es uuid válido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })
  describe('Metodo "middObjectId", validacion de id en "param". Tipo de dato ObjectId de mongoose', () => {
    it('deberia permitir el paso si el Id es objectId válido.', async () => {
      const id = '6820bf17074781c88b81ad82'
      const response = await agent
        .get(\`/test/param/mongoose/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })
    it('deberia arrojar un error si el Id no es objectId válido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/mongoose/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Id no válido')
    })
  })
  describe('Metodo "middIntId", validacion de id en "param". Tipo de dato INTEGER.', () => {
    it('deberia permitir el paso si el Id es numero entero válido', async () => {
      const id = 1
      const response = await agent
        .get(\`/test/param/int/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })
    it('deberia arrojar un error si el Id no es numero entero válido.', async () => {
      const id = 'dkdi'
      const response = await agent
        .get(\`/test/param/int/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })
})
EOL
#Crear el archivo de server para pruebas de middleware
cat > "$PROJECT_DIR/src/Shared/Middlewares/testHelpers/serverTest.js" <<EOL
import express from 'express'
import MiddlewareHandle from '../MiddlewareHandler.js'

// Los metodos son: validateField, validateFieldWithItems, middUuid, midIntId, validateRegex
// Para validateField y validateFieldWithItems los parametros van acompañados de su tipo en minuscula:
const firstItems = [
  { name: 'name', type: 'string' },
  { name: 'amount', type: 'int' },
  { name: 'price', type: 'float' },
  { name: 'enable', type: 'boolean' },
  { name: 'arreglo', type: 'array' }
]
const secondItem = [
  { name: 'name', type: 'string' },
  { name: 'picture', type: 'string' },
  { name: 'enable', type: 'boolean' },
  { name: 'arreglo', type: 'array' }
]

const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

const queries = [
  { name: 'page', type: 'int' },
  { name: 'size', type: 'float' },
  { name: 'fields', type: 'string' },
  { name: 'truthy', type: 'boolean' }
]

const serverTest = express()
serverTest.use(express.json())

serverTest.post(
  '/test/body/create',
  MiddlewareHandle.validateFields(firstItems),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
)

serverTest.post(
  '/test/body/extra/create',
  MiddlewareHandle.validateFieldsWithItems(firstItems, secondItem, 'items'),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
)

serverTest.post(
  '/test/user',
  MiddlewareHandle.validateRegex(
    emailRegex,
    'email',
    'Introduzca un mail valido'
  ),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
)

serverTest.get(
  '/test/param',
  MiddlewareHandle.validateQuery(queries),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware', data: req.query, validData: req.context.query//req.validatedQuery
    })
  }
)

serverTest.get(
  '/test/param/:id',
  MiddlewareHandle.middUuid('id'),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware' })
  })
serverTest.get(
  '/test/param/mongoose/:id',
  MiddlewareHandle.middObjectId('id'),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware' })
  })

serverTest.get(
  '/test/param/int/:id',
  MiddlewareHandle.middIntId('id'),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware' })
  }
)

serverTest.use((err, req, res, next) => {
  const status = err.status || 500
  const message = err.message || err.stack
  res.status(status).json(message)
})

export default serverTest
EOL
#&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
# Crear el archivo swaggerOptions.js en Swagger:
cat > "$PROJECT_DIR/src/Shared/Swagger/swaggerOptions.js" <<EOL
import env from './../Configs/envConfig.js'

const swaggerOptions = {
  swaggerDefinition: {
    openapi: '3.0.0',
    info: {
      title: "$PROYECTO",
      version: '1.0.0',
      description: 'Documentación de mi API $PROYECTO con Swagger. Este modelo es ilustrativo'
    },

    servers: [
      {
        url: \`http://localhost:\${env.Port}\`
      }
    ]
    // components: {
    //   securitySchemes: {
    //     bearerAuth: {
    //       type: 'http',
    //       scheme: 'bearer',
    //       bearerFormat: 'JWT'
    //     }
    //   }
    // },
    // security: [
    //   {
    //     bearerAuth: []
    //   }
    // ]
  },
  apis: ['./src/Swagger/schemas/user.jsdoc.js'], // Ruta a tus archivos de rutas
  swaggerOptions: {
    docExpansion: 'none' // 👈 Oculta todas las rutas al cargar
  }
}

export default swaggerOptions
EOL

# Crear el archivo swUser.js
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/user.jsdoc.js" <<EOL
/**
* @swagger
* tags:
*   - name: Users
*     description: Operaciones relacionadas con users
 */

/**
* @swagger
* components:
*   schemas:
*     User:
*       type: object
*       properties:
*             name:
*               type: string
*               example: name ejemplo
*               description: Descripción de name
*             username:
*               type: string
*               example: username ejemplo
*               description: Descripción de username
*             email:
*               type: string
*               example: email ejemplo
*               description: Descripción de email
 */

/**
* @swagger
* '/api/user':
*   post:
*     summary: Crear un nuevo user
*     tags: [Users]
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             required:
*                - name
*                - username
*                - email
*             properties:
*             name:
*               type: string
*               example: name ejemplo
*               description: Descripción de name
*             username:
*               type: string
*               example: username ejemplo
*               description: Descripción de username
*             email:
*               type: string
*               example: email ejemplo
*               description: Descripción de email
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
* '/api/user':
*   get:
*     summary: Obtener todos los users
*     tags: [Users]
*     parameters:
*       - in: query
*         name: search
*         required: false
*         schema:
*           type: string
*         description: Busqueda
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
* '/api/user/{id}':
*   get:
*     summary: Obtener un user por ID
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: integer
*         description: Id del usuario
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
* '/api/user/{id}':
*   put:
*     summary: Actualizar un user
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: integer
*         description: Id del usuario
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             properties:
*             name:
*               type: string
*               example: name ejemplo
*               description: Descripción de name
*             username:
*               type: string
*               example: username ejemplo
*               description: Descripción de username
*             email:
*               type: string
*               example: email ejemplo
*               description: Descripción de email
*     responses:
*       200:
*         description: Actualización exitosa
*       400:
*         description: Error de validación
 */

/**
* @swagger
* '/api/user/{id}':
*   delete:
*     summary: Eliminar un user
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: integer
*         description: Id del usuario
*     responses:
*       200:
*         description: Eliminado correctamente
*       404:
*         description: user no encontrado
 */
EOL
# Crear el archivo swUser.js
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/tools/generateSchema.js" <<EOL
import fs from 'fs';
import path from 'path';
import inquirer from 'inquirer';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outputPath = path.join(__dirname, '../../schemas');

const askFields = async () => {
  const fields = [];
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

    const field = { name, type };
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

const askParameters = async (kind = 'path') => {
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

const askSchemaInfo = async () => {
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

  return {
    tag,
    singular,
    fields,
    pathParams,
    queryParams,
    includeSchema
  };
};

const buildPropertiesBlock = (fields, indent = '            ') => {
  return fields.map(f => {
    const example =
      f.type === 'string' ? \`\${f.name} ejemplo\` :
      f.type === 'boolean' ? true :
      1;

    return \`\${indent}\${f.name}:\n\${indent}  type: \${f.type}\${f.format ? \`\n\${indent}  format: \${f.format}\` : ''}\n\${indent}  example: \${example}\n\${indent}  description: Descripción de \${f.name}\`;
  }).join('\n');
};

// 👇 cambia el método renderParameters
const renderParameters = (params, indent = '    ') => {
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

const wrapWithJSDoc = (content) => {
  return '/**\n' + content.trim().split('\n').map(line => line.trim() ? \`* \${line}\` : '*').join('\n') + '\n */';
};

const generateJSDoc = ({ tag, singular, fields, pathParams, queryParams, includeSchema }) => {
  const schemaName = singular.charAt(0).toUpperCase() + singular.slice(1);
  const upperTag = tag.charAt(0).toUpperCase() + tag.slice(1);
  const required = fields.map(f => \`               - \${f.name}\`).join('\n');
  const props = buildPropertiesBlock(fields);
  const parametersBlock = renderParameters([...pathParams, ...queryParams]);
  const allParametersBlock = renderParameters(queryParams)

  const basePath = \`/api/\${singular}\`;
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

const generateSchemaFile = async (schemaInfo) => {
  if (!fs.existsSync(outputPath)) fs.mkdirSync(outputPath, { recursive: true });

  const fileName = \`\${schemaInfo.singular}.jsdoc.js\`;
  const filePath = path.join(outputPath, fileName);
  const jsdocContent = generateJSDoc(schemaInfo);

  fs.writeFileSync(filePath, jsdocContent);
  console.log(\`✅ JSDoc generado: docs/jsdoc/\${fileName}\`);
};

const main = async () => {
  const schemaInfo = await askSchemaInfo();
  await generateSchemaFile(schemaInfo);
};

main();
EOL
# Crear el archivo user.routes.js en src
cat > "$PROJECT_DIR/src/Modules/users/user.routes.js" <<EOL
import express from 'express'
import { userController, userCreate, userUpdate, regexEmail } from './mainUser.js'
import MiddlewareHandler from '../../Middlewares/MiddlewareHandler.js'
const userRouter = express.Router()

userRouter.get('/user', (req, res)=>{
res.status(200).send('Hello World!')
})

export default userRouter
EOL
# Crear el archivo mainUser en users
cat > "$PROJECT_DIR/src/Modules/users/mainUser.js" <<EOL
import UserService from '../../Services/UserService.js'
import genericController from '../../Controllers/GenericController.js'
import { users } from '../../Services/users.js'

const userService = new UserService(users)
export const userController = genericController(userService)

export const userCreate = [{ name: 'name', type: 'string' }, { name: 'username', type: 'string' }, { name: 'email', type: 'string' }]
export const userUpdate = [{ name: 'name', type: 'string' }, { name: 'username', type: 'string' }, { name: 'email', type: 'string' }, { name: 'enable', type: 'boolean' }, { name: 'phone', type: 'int' }]
export const regexEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
EOL
# Crear el archivo jest.setup en test
cat > "$PROJECT_DIR/test/jest.setup.js" <<EOL
import mongoose from 'mongoose';
import connectDB from '../server/Configs/database.js';
import Test from './baseHelperTest/modelTest.js'

// Inicializa la base de datos de MongoDB antes de las pruebas
async function initializeDatabase() {
  try {
    await connectDB();
    // Asegurarse de empezar en una BD vacía
    await mongoose.connection.dropDatabase();
      // Asegura que se creen los índices
  //await Test.syncIndexes()
  console.log('Índices sincronizados')
    console.log('Base de datos MongoDB inicializada correctamente ✔️');
  } catch (error) {
    console.error('Error inicializando DB MongoDB ❌', error);
  }
}

// Resetea la base de datos antes de cada prueba si es necesario
export async function resetDatabase() {
  try {
      const collections = await mongoose.connection.db.collections();
    for (const coll of collections) {
      const count = await coll.countDocuments();
      console.log(\`🗃️ antes del reset: \${coll.collectionName}: \${count || 0} documentos\`);
    }
    await mongoose.connection.dropDatabase();
    console.log(\`🔍 Total de colecciones después del drop: \${collections.length}\`)
    console.log('Base de datos MongoDB reseteada ✔️');
  } catch (error) {
    console.error('Error reseteando MongoDB ❌', error);
  }
}

beforeAll(async () => {
  await initializeDatabase();
});

// afterEach(async () => {
//   // Opcional: limpiar tras cada test unitario
//   await resetDatabase();
// });

afterAll(async () => {
  try {
    await mongoose.disconnect();
    console.log('Conexión MongoDB cerrada ✔️');
  } catch (error) {
    console.error('Error cerrando conexión MongoDB ❌', error);
  }
});
EOL

# Crear archivo de ayuda de test
cat > "$PROJECT_DIR/test/helperTest/generalFunctions.js" <<EOL
const throwError = (message, status) => {
  const error = new Error(message)
  error.status = status
  throw error
}

export function mockDeleteFunction (url, result) {
  if (result) {
    return {
      success: true,
      message: \`ImageUrl \${url} deleted succesfully\`
    }
  } else {
    throwError(\`Error processing ImageUrl \${url}\`, 500)
  }
}
export const deletFunctionTrue = (url) => {
  // console.log('probando deleteFunction: ', url);
  return {
    success: true,
    message: \`ImageUrl \${url} deleted succesfully\`
  }
}
export const deletFunctionFalse = (url) => {
  // console.log('probando deleteErrorFunction: ', url);
  throwError(\`Error processing ImageUrl: \${url}\`, 500)
}
EOL

# Crear archivo para guardar variables
cat > "$PROJECT_DIR/test/helperTest/testStore.js" <<EOL
let token = ''
let userId = ''

export const setToken = (newToken) => {
  token = newToken
}

export const getToken = () => {
  return token
}

export const setId = (newid) => {
  userId = newid
}

export const getId = () => {
  return userId
}
EOL
# Crear archivo jest.config.js
cat > "$PROJECT_DIR/jest.config.js" <<EOL
export default {
  testEnvironment: 'node',
  //setupFilesAfterEnv: ['./test/jest.setup.js']
}
EOL
# Crear el package.json
cat > "$PROJECT_DIR/package.json" <<EOL
{
  "name": "$PROYECTO_PACKAGE",
  "version": "1.0.0",
  "description": "Una aplicación Express generada con Bash",
  "main": "index.js",
  "type": "module",
  "scripts": {
    "start": "cross-env NODE_ENV=production node index.js",
    "dev": "cross-env NODE_ENV=development nodemon index.js",
    "unit:test": "cross-env NODE_ENV=test jest --detectOpenHandles",
    "lint": "standard",
    "lint:fix": "standard --fix",
    "gen:schema": "node src/Swagger/schemas/tools/generateSchema.js"
  },
  "dependencies": {
  },
  "devDependencies": {
  },
   "babel": {
    "env": {
      "test": {
        "presets": [
          "@babel/preset-env"
        ]
      }
    }
  },
  "eslintConfig": {
    "extends": "./node_modules/standard/eslintrc.json"
  }
}
EOL
# Crear archivos de entorno
cat > "$PROJECT_DIR/.env.production" <<EOL
PORT=3000
URI_DB=mongodb://127.0.0.1:27017/"herethenameofdb"
EOL

cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
URI_DB=mongodb://127.0.0.1:27017/"herethenameofdb"
EOL

cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
URI_DB=mongodb://127.0.0.1:27017/"herethenameofdb"
EOL
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=
URI_DB=mongodb://127.0.0.1:27017/"herethenameofdb"
EOL
# Crear README.md
cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express

Base para el proyecto $PROYECTO_VALIDO de Express.js con entornos de ejecución y manejo de errores.

## Sobre la API:

Esta API fue construida de manera funcional. Los repositories, services y controllers estan diseñados bajo el paradigma de factory Functions. Los middlewares, si bien forman parte de una clase, esta es una clase de métodos estáticos. De esta forma, se ordena, y escala la app con la menor redundancia de codigo y al mismo tiempo se minimiza el consumo de recursos utilizando funciones siempre que sea posible (diseñado para hostings stateless). De esta manera logramos: 
- Menor memoria: No carga toda una jerarquía de clases
- Arranque rápido: Sólo incluye lo que se necesita para cada operación
- Serialización: Los objetos planos son más fáciles de serializar/deserializar
- Escalabilidad: Facilita el diseño de sistemas distribuidos

En esta plantilla encontrará ambos paradigmas funcionando codo a codo. A partir de aquí, puede adaptarla según su preferencia. Si bien está construida de una manera básica, es funcional. Al revisar el código podrá ver, si desea mantener este enfoque, cómo continuar. ¡Buena suerte y buen código!

## Cómo comenzar:

### Instalaciones:

La app viene con las instalaciones básicas para comenzar a trabajar con Sequelize y una base de datos PostgreSQL. En caso de querer utilizar MySQL o SQLite, las dependencias específicas de PostgreSQL que deben desinstalarse son \`pg\` y \`pg-hstore\`.

### Scripts disponibles:

- \`npm start\`: Inicializa la app en modo producción con Node.js y Express (.env.production).
- \`npm run dev\`: Inicializa la app en modo desarrollo con Nodemon y Express (.env.development).
- \`npm run unit:test\`: Ejecuta todos los tests. También puede ejecutarse un test específico, por ejemplo: \`npm run unit:test EnvDb\`. La app se inicializa en modo test (.env.test).
- \`npm run lint\`: Ejecuta el linter (standard) y analiza la sintaxis del código (no realiza cambios).
- \`npm run lint:fix\`: Ejecuta el linter y corrige automáticamente los errores.
- \`npm run gen:schema\`: Inicializa la función \`generateSchema\`, que genera documentación Swagger para las rutas mediante una guía por consola. Si bien es susceptible de mejora, actualmente resulta muy útil para agilizar el trabajo de documentación.

La aplicación incluye un servicio de ejemplo que muestra su funcionalidad. En la carpeta \`Services\` se encuentra el archivo \`users.js\` que contiene un arreglo de usuarios. Estos, junto con los controladores y servicios, son utilizados en \`mainUser.js\`, ubicado dentro del directorio \`Modules/users\`. Allí también se declaran los tipos de datos que se esperan como entrada. El archivo \`user.routes.js\` conecta esta funcionalidad con la app a través de \`mainRouter\` (\`routes.js\`).

La aplicación puede ejecutarse con \`npm run dev\` (modo desarrollo) o \`npm start\` (producción). Los tests pueden ejecutarse solo una vez que conectado la base de datos de test en .env.test.

Se requieren dos bases de datos: una para desarrollo y otra para test. Una vez configurado todo, puede comenzar a testear las funciones ya hechas. Luego, ajuste los tests según su caso de uso.

### Manejo de errores:

- La función \`catchController\` se utiliza para envolver los controladores, como se detalla en \`GenericController.js\`.
- La función \`throwError\` se utiliza en los servicios. Recibe un mensaje y un código de estado:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";

eh.throwError("Usuario no encontrado", 404);
\`\`\`

- La función \`middError\` se usa en los middlewares:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";

if (!user) {
  return next(eh.middError("Falta el usuario", 400));
}
\`\`\`

### Acerca de \`MiddlewareHandler.js\`

Esta clase estática contiene una serie de métodos auxiliares para evitar la repetición de código en middlewares activos.

#### Métodos de validación disponibles:

- \`validateFields\`: validación y tipado de datos del body
- \`validateFieldsWithItems\`: validación de un objeto con un array de objetos anidados
- \`validateQuery\`: validación y tipado de queries (con copia debido a Express 5)
- \`validateRegex\`: validación de parámetros del body mediante expresiones regulares
- \`middUuid\`: validación de UUID
- \`middIntId\`: validación de ID como número entero

#### validateFields:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'

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
import MiddlewareHandler from '../MiddlewareHandler.js'

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
import MiddlewareHandler from '../MiddlewareHandler.js'

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
import MiddlewareHandler from '../MiddlewareHandler.js'

const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

router.post('/', MiddlewareHandler.validateRegex(emailRegex, 'email', 'Introduzca un mail válido'), controlador);
\`\`\`

#### middUuid y middIntId:

Funcionan de forma similar, cambiando solo el tipo de dato a validar:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'

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
npm install cross-env@latest cors@latest dotenv@latest express@latest helmet@latest morgan@latest mongoose uuid@latest 
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install @babel/core @babel/preset-env babel-jest nodemon@latest standard@latest supertest@latest jest@latest swagger-jsdoc swagger-ui-express inquirer -D
  
echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."
