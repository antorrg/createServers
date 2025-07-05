#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Configs,Middlewares,Controllers,Services,Repositories,Modules,Modules/users,Swagger,Swagger/schemas,Swagger/schemas/tools}
mkdir -p $PROJECT_DIR/test/{helperTest,Middlewares,Middlewares/helpers,Repositories,Services}

# Crear el archivo index.js en src
cat > "$PROJECT_DIR/index.js" <<EOL
import app from './src/app.js'
import env from './src/Configs/envConfig.js'
// import { startApp } from './src/Configs/database.js'

app.listen(env.Port, async () => {
  try {
  // startApp()
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
# Crear archivo de manejo de errores de Express
cat > "$PROJECT_DIR/src/Configs/errorHandlers.js" <<EOL
export default {
  catchController: (controller) => {
    return (req, res, next) => {
      return Promise.resolve(controller(req, res, next)).catch(next)
    }
  },

  throwError: (message, status) => {
    const error = new Error(message)
    error.status = Number(status) || 500
    throw error
  },

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
# Crear el Controlador
cat > "$PROJECT_DIR/src/Controllers/GenericController.js" <<EOL
import eh from '../Configs/errorHandlers.js'
const catchController = eh.catchController

class GenericController {
  constructor (service) {
    this.service = service
  }

  // Methods:
  static responder (res, status, success, message = null, results = null) {
    res.status(status).json({ success, message, results })
  }

  // Controllers:
  create = catchController(async (req, res) => {
    const data = req.body
    const response = await this.service.create(data)
    return GenericController.responder(res, 201, true, response.message, response.results)
  })

  getAll = catchController(async (req, res) => {
    const response = await this.service.getAll()
    return GenericController.responder(res, 200, true, response.message, response.results)
  })

  getById = catchController(async (req, res) => {
    const { id } = req.params
    const response = await this.service.getById(id)
    return GenericController.responder(res, 200, true, response.message, response.results)
  })

  update = catchController(async (req, res) => {
    const { id } = req.params
    const newData = req.body
    const response = await this.service.update(id, newData)
    return GenericController.responder(res, 200, true, response.message, response.results)
  })

  delete = catchController(async (req, res) => {
    const { id } = req.params
    const response = await this.service.delete(id)
    return GenericController.responder(res, 200, true, response.message, response.results)
  })
};

export default GenericController
EOL
# Crear el repositorio
cat > "$PROJECT_DIR/src/Repositories/BaseRepository.js" <<EOL
import eh from '../Configs/errorHandlers.js'

const throwError = eh.throwError
// Esto es lo mas parecido a una clase abstracta, no se puede instanciar, solo se puede extender.

class BaseRepository {
  constructor (Model, dataEmpty = null) {
    if (new.target === BaseRepository) {
      throw new Error('No se puede instanciar una clase abstracta.')
    }
    this.Model = Model
    this.dataEmpty = dataEmpty
  }

  async create (data, uniqueField) {
    try {
      const whereClause = {}
      if (uniqueField) {
        whereClause[uniqueField] = data[uniqueField]
      }
      const existingRecord = await this.Model.findUnique({ where: whereClause })

      if (existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} \${uniqueField || 'entry'} already exists\`, 400)
      }
      const newRecord = await this.Model.create({ data })

      return newRecord
    } catch (error) {
      throw error
    }
  }

  async getAll (searchField = '', search = null, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10) {
    const offset = (page - 1) * limit
    // Construimos el filtro de búsqueda
    const searchFilter = search ? { [searchField]: { contains: search, mode: 'insensitive' } } : {}
    // Combinamos filtros personalizados con búsqueda
    const where = { ...searchFilter, ...filters }
    const existingRecords = await this.Model.findMany({
      where,
      orderBy: { [sortBy]: order },
      skip: offset,
      take: limit
    })
    if (existingRecords.length === 0) {
      if (this.dataEmpty) {
        existingRecords.push(this.dataEmpty)
      } else { throwError(\`This \${this.Model.name.toLowerCase()} \${searchField || 'entry'} do not exists\`, 404) }
    }

    // Contamos el total de registros
    const total = await this.Model.count({ where })

    return {
      info: {
        total,
        page,
        totalPages: Math.ceil(total / limit)
      },
      data: existingRecords
    }
  }

  async getOne (data, uniqueField) {
    try {
      const whereClause = {}
      if (uniqueField) {
        whereClause[uniqueField] = data
      }
      const existingRecord = await this.Model.findUnique({ where: whereClause })
      if (!existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} name do not exists\`, 404)
      }
      return existingRecord
    } catch (error) {
      throw error
    }
  };

  async getById (id) {
    try {
      const existingRecord = await this.Model.findUnique({ where: { id } })
      if (!existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} name do not exists\`, 404)
      }
      return existingRecord
    } catch (error) {
      throw error
    }
  };

  async update (id, data) {
    const dataFound = await this.Model.findUnique({ where: { id } })
    if (!dataFound) {
      throwError(\`\${this.Model.name} not found\`, 404)
    }
    const upData = await this.Model.update({
      where: { id: parseInt(id) },
      data
    })
    return upData
  };

  async delete (id) {
    const dataFound = await this.Model.findUnique({ where: { id } })
    if (!dataFound) {
      throwError(\`\${this.Model} not found\`, 404)
    }
    await this.Model.delete({
      where: { id: parseInt(id) }
    })
    return \`\${this.Model.name} deleted successfully\`
  };
}

export default BaseRepository
EOL
# Crear el Servicio 
cat > "$PROJECT_DIR/src/Services/GeneralService.js" <<EOL
import eh from '../Configs/errorHandlers.js'
import NodeCache from 'node-cache'

const throwError = eh.throwError
const cache = new NodeCache({ stdTTL: 1800 }) // TTL (Time To Live) de media hora

class GeneralService {
  constructor (Repository, fieldName, useCache = false, parserFunction = null, useImage = false, deleteImages = null) {
    this.Repository = Repository
    this.fieldName = fieldName
    this.useCache = useCache
    this.useImage = useImage
    this.deleteImages = deleteImages
    this.parserFunction = parserFunction
  }

  clearCache () {
    cache.del(\`\${this.Repository.name.toLowerCase()}\`)
  }

  async handleImageDeletion (imageUrl) {
    if (this.useImage && imageUrl) {
      await this.deleteImages(imageUrl)
    }
  }

  async create (data, uniqueField = null) {
    try {
      const newRecord = await this.Repository.create(data, uniqueField)

      if (this.useCache) this.clearCache()
      return newRecord
    } catch (error) {
      throw error
    }
  }

  //searchField = '', search = null, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10

  async getAll (queryObject, isAdmin = false,) {
    // console.log('service',emptyObject)
    const { searchField = '', page = 1, limit, search = null, filters = {}, sortBy = 'id', order = 'desc',} = queryObject
    const cacheKey = \`\${this.fieldName.toLowerCase()}\`
    if (this.useCache) {
      const cachedData = cache.get(cacheKey)
      if (cachedData) {
        return {
          data: cachedData,
          cache: true
        }
      }
    }
    const data = await this.Repository.getAll(searchField, search, filters, sortBy, order, page, limit,)

    const dataParsed = isAdmin ? data : data.map(dat => this.parserFunction(dat))
    // console.log('soy la data: ', dataParsed)
    if (this.useCache) {
      cache.set(cacheKey, dataParsed)
    }
    // console.log(dataParsed)
    return {
      data: dataParsed,
      cache: false
    }
  }

  async getById (id, isAdmin = false) {
    const data = await this.Repository.getById(id, isAdmin)

    return isAdmin ? data : this.parserFunction(data)
  }

  async update (id, newData) {
    // console.log('soy el id en el service : ', id)
    // console.log('soy newData en el service : ', newData)

    let imageUrl = ''
    let deleteImg = false

    const dataFound = await this.Repository.getById(id, newData)

    if (this.useImage && dataFound.picture && dataFound.picture !== newData.picture) {
      imageUrl = dataFound.picture
      deleteImg = true
    }

    const upData = await this.Repository.update(id, newData)

    if (deleteImg) {
      await this.handleImageDeletion(imageUrl)
    }

    if (this.useCache) this.clearCache()
    return {
      message: \`\${this.fieldName} updated successfully\`,
      data: upData
    }
  }

  async delete (id) {
    let imageUrl = ''
    try {
      const dataFound = await this.Repository.getById(id)
      const dataReg = dataFound[this.fieldName]
      this.useImage ? imageUrl = dataFound.picture : ''

      await this.Repository.delete(id)

      await this.handleImageDeletion(imageUrl)

      if (this.useCache) this.clearCache()
      return { message: \`\${this.fieldName} deleted successfully\`, data: dataReg }
    } catch (error) {
      throw error
    }
  }
}

export default GeneralService
EOL
# Crear el Servicio de muestra
cat > "$PROJECT_DIR/src/Services/UserService.js" <<EOL
import eh from '../Configs/errorHandlers.js'

class UserService {
  constructor (Model) {
    this.Model = Model
  }

  // Crear un nuevo usuario
  create (data) {
     const newId = this.Model.length ? Math.max(...this.Model.map(user => user.id)) + 1 : 1
    const randomSevenDigit =()=> Math.floor(1000000 + Math.random() * 9000000)
   
    const newUser = {
      id: newId,
      name: data.name,
      username: data.username,
      email: data.email,
      enable: true,
      phone: randomSevenDigit()
    }
    this.Model.push(newUser)
    return {
      message: 'User created successfully',
      results: newUser
    }
  }

  // Obtener todos los usuarios
  getAll () {
    return {
      message: 'Users found',
      results: this.Model
    }
  }

  // Obtener un usuario por ID
  getById (id) {
    const response = this.Model.find(user => user.id === Number(id))
    if (!response) { eh.throwError('User not found', 404) }
    return {
      message: 'Users found',
      results: response
    }
  }

  // Actualizar un usuario por ID
  update (id, newData) {
    const index = this.Model.findIndex(user => user.id === Number(id))
    if (index === -1) { eh.throwError('This user do not exists', 404) };

    this.Model[index] = { ...this.Model[index], ...newData }
    return {
      message: 'Users updated successfully',
      results: this.Model[index]
    }
  }

  // Eliminar un usuario por ID
  delete (id) {
    const index = this.Model.findIndex(user => user.id === Number(id))
    if (index === -1) { eh.throwError('User not found', 404) }
    return {
      message: 'User deleted successfully',
      results: this.Model.splice(index, 1)[0] // Elimina y devuelve el usuario eliminado
    }
  }
}

export default UserService
EOL
# Crear el array de datos:
cat > "$PROJECT_DIR/src/Services/users.js" <<EOL
export const users = [
  {
    id: 1,
    name: 'Leanne Graham',
    username: 'Bret',
    email: 'Sincere@april.biz',
    enable:true,
    phone: 5578896
  },
  {
    id: 2,
    name: 'Ervin Howell',
    username: 'Antonette',
    email: 'Shanna@melissa.tv',
    enable:true,
    phone: 3420219
  },
  {
    id: 3,
    name: 'Clementine Bauch',
    username: 'Samantha',
    email: 'Nathan@yesenia.net',
    enable:true,
    phone: 7101901
  },
  {
    id: 4,
    name: 'Patricia Lebsack',
    username: 'Karianne',
    email: 'Julianne.OConner@kory.org',
    enable:true,
    phone: 3623102
  },
  {
    id: 5,
    name: 'Chelsey Dietrich',
    username: 'Kamren',
    email: 'Lucio_Hettinger@annie.ca',
    enable:true,
    phone: 1051203
  },
  {
    id: 6,
    name: 'Mrs. Dennis Schulist',
    username: 'Leopoldo_Corkery',
    email: 'Karley_Dach@jasper.info',
    enable:true,
    phone: 5862081
  },
  {
    id: 7,
    name: 'Kurtis Weissnat',
    username: 'Elwyn.Skiles',
    email: 'Telly.Hoeger@billy.biz',
    enable:true,
    phone: 7452263
  },
  {
    id: 8,
    name: 'Nicholas Runolfsdottir V',
    username: 'Maxime_Nienow',
    email: 'Sherwood@rosamond.me',
    enable:true,
    phone: 9235392
  },
  {
    id: 9,
    name: 'Glenna Reichert',
    username: 'Delphine',
    email: 'Chaim_McDermott@dana.io',
    enable:true,
    phone: 2582826
  },
  {
    id: 10,
    name: 'Clementina DuBuque',
    username: 'Moriah.Stanton',
    email: 'Rey.Padberg@karina.biz',
    enable:true,
    phone: 8987275
  }
]
EOL
# Crear el Middleware de uso general
cat > "$PROJECT_DIR/src/Middlewares/MiddlewareHandler.js" <<EOL
import { validate as uuidValidate } from 'uuid'

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
# Crear el archivo swaggerOptions.js en Swagger:
cat > "$PROJECT_DIR/src/Swagger/swaggerOptions.js" <<EOL
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
cat > "$PROJECT_DIR/src/Swagger/schemas/user.jsdoc.js" <<EOL
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
cat > "$PROJECT_DIR/src/Swagger/schemas/tools/generateSchema.js" <<EOL
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

userRouter.post(
  '/',
  MiddlewareHandler.validateFields(userCreate),
  MiddlewareHandler.validateRegex(regexEmail, 'email'),
  userController.create
)
userRouter.get('/',
  userController.getAll
)
userRouter.get('/:id',
  MiddlewareHandler.middIntId('id'),
  userController.getById
)
userRouter.put(
  '/:id',
  MiddlewareHandler.middIntId('id'),
  MiddlewareHandler.validateFields(userUpdate),
  MiddlewareHandler.validateRegex(regexEmail, 'email'),
  userController.update
)
userRouter.delete(
  '/:id',
  MiddlewareHandler.middIntId('id'),
  userController.delete
)

export default userRouter
EOL
# Crear el archivo mainUser en users
cat > "$PROJECT_DIR/src/Modules/users/mainUser.js" <<EOL
import UserService from '../../Services/UserService.js'
import GenericController from '../../Controllers/GenericController.js'
import { users } from '../../Services/users.js'

const userService = new UserService(users)
export const userController = new GenericController(userService)

export const userCreate = [{ name: 'name', type: 'string' }, { name: 'username', type: 'string' }, { name: 'email', type: 'string' }]
export const userUpdate = [{ name: 'name', type: 'string' }, { name: 'username', type: 'string' }, { name: 'email', type: 'string' }, { name: 'enable', type: 'boolean' }, { name: 'phone', type: 'int' }]
export const regexEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
EOL
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
# Crear archivo de test de entorno y db
cat > "$PROJECT_DIR/test/EnvDb.test.js" <<EOL
import env from '../src/Configs/envConfig.js'
import { prisma } from '../src/Configs/database.js'

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
#Crear archivo de test Middleware
cat > "$PROJECT_DIR/test/Middlewares/MiddHandler.test.js" <<EOL
import session from 'supertest'
import serverTest from './helpers/serverTest.js'
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
    it('deberia validar, tipar y arrorjar un error si faltara algun parametro.', async () => {
      const data = { name: 'name', amount: '100', price: '55.44', arreglo: [] }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing parameters: enable')
    })
    it('deberia validar, tipar y arrorjar un error si no fuera posible tipar un parametro.', async () => {
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
    it('deberia validar, tipar y arrorjar un error si faltara algun parametro.', async () => {
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
    it('deberia validar, tipar y arrorjar un error si no fuera posible tipar un parametro.', async () => {
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
# Crear archivo de serverMock para middlewares
cat > "$PROJECT_DIR/test/Middlewares/helpers/serverTest.js" <<EOL
import express from 'express'
import MiddlewareHandle from '../../../src/Middlewares/MiddlewareHandler.js'

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
    res.status(200).json({ message: 'Passed middleware', data: req.query, validData: req.validatedQuery})
  }
)

serverTest.get('/test/param/:id', MiddlewareHandle.middUuid, (req, res) => {
  res.status(200).json({ message: 'Passed middleware' })
})

serverTest.get(
  '/test/param/int/:id',
  MiddlewareHandle.middIntId,
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
# Crear archivo de test para Repositories
cat > "$PROJECT_DIR/test/Repositories/RepBase.test.js" <<EOL
import BaseRepository from '../../src/Repositories/BaseRepository.js'
import { prisma } from '../../src/Configs/database.js'
import * as info from './helpers/baseRep.js'

class TestClass extends BaseRepository {
  constructor (Model, dataEmpty) {
    super(Model, dataEmpty)
  }
}
//const tests = new TestClass(prisma.example) Se necesita tener al menos una tabla declarada en la DB
//const failed = new TestClass(prisma.example, info.dataEmpty)

describe('BaseRepository tests (abstract class)', () => {
  describe('Test de extension e instancias', () => {
    it('Deberia arrojar un error al intentar instanciar la clase BaseRepository.', () => {
      expect(() => new BaseRepository(prisma.landing)).toThrow(Error)
      expect(() => new BaseRepository(prisma.landing)).toThrow('No se puede instanciar una clase abstracta.')
    })
    it('debería heredar e instanciar correctamente la clase sin lanzar error', () => {
      const instance = new TestClass(prisma.landing)
      // Verifica que la instancia sea de TestClass y de BaseRepository
      expect(instance).toBeInstanceOf(TestClass)
      expect(instance).toBeInstanceOf(BaseRepository)
      // Verifica que la propiedad Model se asignó correctamente
      expect(instance.Model).toBe(prisma.landing)
    })
  })
  xdescribe('Tests unitarios. Metodos de BaseRepository', () => {
    describe('Metodo create.', () => {
      it('Deberia crear un elemento con los parametros correctos.', async () => {
        const element = info.createData
        const uniqueField = 'title'
        const response = await tests.create(element, uniqueField)
        const responseCleaned = info.cleanData(response)
        expect(responseCleaned).toEqual(info.responseData)
      })
      it('Deberia arrojar un error al intentar crear el mismo elemento dos veces (mismo nombre).', async () => {
        const element = info.createData
        const uniqueField = 'title'
        try {
          await tests.create(element, uniqueField)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.message).toBe('This landing title already exists')
          expect(error.status).toBe(400)
        }
      })
    })
    describe('Metodos GET, retornando un arreglo de elementos o un elemento.', () => {
      it('Metodo "getAll": deberia retornar un arreglo de elementos.', async () => {
        //, { search, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10 }
        const response = await tests.getAll('title')
        console.log('A ver el get', response)
        const finalRes = response.data.map(info.cleanData)
        expect(finalRes).toEqual([info.responseData])
        expect(response.info).toEqual({ page: 1, total: 1, totalPages: 1 })
      })
      it('Metodo "getAll": deberia retornar un arreglo simbólico si no hubiera elementos en la base de datos.', async () => {
        const response = await failed.getAll('name')
        const finalRes = response.data.map(info.cleanData)
        expect(finalRes).toEqual([info.dataEmpty])
      })
      it('Metodo "getAll": deberia arrojar un error si no existe el objeto simbolico.', async () => {
        try {
          await failed.getAll('name')
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.message).toBe('This genre name do not exists')
          expect(error.status).toBe(404)
        }
      })
      it('Metodo "getById": deberia retornar un objeto con un elemento.', async () => {
        const id = 1
        const response = await tests.getById(id)
        const finalRes = info.cleanData(response)
        expect(finalRes).toEqual(info.responseData)
      })
      it('Metodo "getById": deberia arrojar un error si el id es incorrecto o el objeto no es enable true con admin en false.', async () => {
        const id = 2
        try {
          await tests.getById(id)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.status).toBe(404)
          expect(error.message).toBe('This landing name do not exists')
        }
      })
      it('Metodo "getOne": deberia retornar un objeto con un elemento.', async () => {
        const uniqueField = 'title'
        const data = 'Titulo de la landing'
        const response = await tests.getOne(data, uniqueField)
        const finalRes = info.cleanData(response)
        expect(finalRes).toEqual(info.responseData)
      })
      it('Metodo "getOne": deberia arrojar un error si el campo de busqueda es incorrecto o el objeto no es enable true con admin en false.', async () => {
        const uniqueField = 'title'
        const data = 'landing2'
        try {
          await tests.getOne(data, uniqueField)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.status).toBe(404)
          expect(error.message).toBe('This landing name do not exists')
        }
      })
    })
    describe('Metodo "update', () => {
      it('Deberia actualizar el elemento si los parametros son correctos.', async () => {
        const id = 1
        const newData = { id, title: 'landing3', enable: true }
        const response = await tests.update(id, newData)
        const responseJs = info.cleanData(response)
        expect(responseJs).toMatchObject(info.responseUpdData)
      })
    })
    describe('Metodo "delete".', () => {
      it('Deberia borrar un elemento', async () => {
        const id = 1
        const response = await tests.delete(id)
        expect(response).toBe('Landing deleted successfully')
      })
    })
  })
})
EOL
# Crear archivo de serverMock para services
cat > "$PROJECT_DIR/test/Services/ServGeneral.test.js" <<EOL
import BaseRepository from '../../src/Repositories/BaseRepository.js'
import GeneralService from '../../src/Services/GeneralService.js'
import { Landing } from '../../src/Configs/database.js'
import * as info from '../helperTest/baseRep.js'
import * as fns from '../helperTest/generalFunctions.js'

class TestClass extends BaseRepository {
  constructor (Model) {
    super(Model)
  }
}
const testing = new TestClass(Landing)

// repository, fieldName(string), cache(boolean), parserFunction(function), useImage(boolean), deleteImages(function)
const serv = new GeneralService(testing, 'Landing', false, null, true, fns.deletFunctionFalse)
const servCache = new GeneralService(testing, 'Landing', true, info.cleanData, false, fns.deletFunctionTrue)
const servParse = new GeneralService(testing, 'Landing', false, info.cleanData, true, fns.deletFunctionTrue)

xdescribe('Test unitarios de la clase GeneralService: CRUD.', () => {
  describe('El metodo "create" para crear un servicio', () => {
    it('deberia crear un elemento con los parametros correctos', async () => {
      const element = info.createData // data, uniqueField=null, parserFunction=null, isAdmin = false
      const response = await servParse.create(element, 'name')
      expect(response).toMatchObject(info.responseData)
    })
    it('deberia arrojar un error al intentar crear dos veces el mismo elemento (manejo de errores)', async () => {
      const element = { name: 'Landing1' }
      try {
        await servParse.create(element)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.message).toBe('This landing entry already exists')
        expect(error.status).toBe(400)
      }
    })
  })
  describe('Metodos "GET". Retornar servicios o un servicio con o sin cache.', () => {
    it('Metodo "getAll": deberia retornar un arreglo con los servicios sin cache habilitado', async () => {
      const response = await servParse.getAll()
      expect(response.data).toEqual([info.responseData])
      expect(response.cache).toBe(false)
    })
    it('Metodo "getAll": deberia retornar un arreglo con los servicios con cache habilitado', async () => {
      const response = await servCache.getAll()
      expect(response.data).toEqual([info.responseData])
      expect(response.cache).toBe(false)
      const response2 = await servCache.getAll()
      expect(response2.data).toEqual([info.responseData])
      expect(response2.cache).toBe(true)
    })
  })
  describe('Metodo "update". Eliminacion de imagenes viejas del storage.', () => {
    it('deberia actualizar los elementos y no eliminar imagenes', async () => {
      const id = 1
      const newData = info.responseData
      const response = await servParse.update(id, newData)
      expect(response.message).toBe('Landing updated successfully')
      expect(response.data).toMatchObject(info.responseData)
    })
    it('deberia actualizar los elementos y gestionar eliminacion de imagenes', async () => {
      const id = 1
      const newData = { picture: 'https://imagen.com.ar' }
      const response = await servParse.update(id, newData)
      expect(response.message).toBe('Landing updated successfully')
      expect(response.data).toMatchObject(info.responseDataImg)
    })
    it('deberia arrojar un error si falla la eliminacion de imagenes', async () => {
      const id = 1
      const newData = info.responseData
      try {
        await serv.update(id, newData)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error processing ImageUrl: https://imagen.com.ar')
      }
    })
  })
  describe('Metodo "delete".', () => {
    it('deberia borrar un elemento', async () => {
      const id = 1
      const response = await servParse.delete(id)
      expect(response).toBe('Landing deleted successfully')
    })
    it('deberia arrojar un error si falla la eliminacion de imagenes', async () => {
      const element = info.createData
      await serv.create(element, 'name')
      const id = 2
      try {
        await serv.delete(id)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error processing ImageUrl: https://picture.com.ar')
      }
    })
  })
})
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
    "lint:fix": "standard --fix"
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
DATABASE_URL=
EOL

cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DATABASE_URL=
EOL

cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DATABASE_URL=
EOL
# Crear README.md
cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express

Base para el proyecto $PROYECTO_VALIDO de Express.js con entornos de ejecución y manejo de errores.

## Sobre la API:

Esta api fue construida de manera hibrida, es decir: la parte de Repositories, Services y Controllers está construida bajo el paradigma OOP (o POO en español, Programacion Orientada a Objetos), sin embargo los routers y la aplicacion en si misma no lo está, los Middlewares sin bien forman parte de una clase, esta es una clase de metodos estaticos, de manera que aproveche la escalabilidad y orden de la POO pero al mismo tiempo minimize el consumo de recursos utilizando funciones puras en todo lugar en el que se pueda (las clases en javascript tienen siempre un costo, no muy elevado pero costo al fin), de manera que en esta plantilla va a encontar los dos paradigmas funcionando codo a codo, usted puede a partir de aqui darle la forma que desee. Si bien está construida de una manera muy básica, esta funciona, por lo que al revisar el codigo podrá ver (si desea mantener este sistema de trabajo) como seguir. ¡Buena suerte y buen codigo!

## Cómo comenzar:

En la aplicacion hay un servicio hecho a modo de ejemplo para mostrar la funcionalidad de la api, en la carpeta Services se encuentra un archivo \`users.js\` que contiene un arreglo con un grupo de usuarios, estos junto con los controladores y servicios son llamados y utilizados en el archivo \`mainUser.js\` que se encuentra dentro del directorio Modules en la carpeta users, aqui tambien se declaran los tipos de datos que van a ingresar, y por medio del archivo \`user.routes.js\` la funcion userRouter conecta todo esto con la app en mainRouter (\`routes.js\`). La aplicacion se puede ejecutar tanto con el comando \`npm run dev\` (en desarrollo) o \`npm start\` (produccion). Los test solo podrán utilizarse luego de haber declarado los modelos y conectado la base de datos.

Es importante decir que necesitará dos dbs, una para desarrollo y otra para test, luego de tener todo listo, debe descomentar la linea en jest.config.js y el codigo que se encuentra en jest.setup.js dentro de la carpeta test, luego tendra que ajustar los tests a su caso de uso

### Manejo de errores:

La funcion catchController se utiliza para envolver a los controladores como esta detallado en \`GenericController.js\`.

La función \`throwError\` es para los servicios, esta espera un mensaje y un estado. Ejemplo:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";
// Esta importación es solo a modo de ejemplo

eh.throwError("Usuario no encontrado", 404);
\`\`\`

La función \`middError\` está diseñada para usarse en los middlewares de este modo:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";
// Esta importación es solo a modo de ejemplo

if (!user) {
  return next(eh.middError("Falta el usuario", 400));
}
\`\`\`

### Acerca de MiddlewareHandler.js

Esta clase estática alberga una serie de métodos, muchos de los cuales no se utilizan (y no se deberian utilizar) de manera directa, más bien son funciones auxiliares de los middlewares activos que están alli como una manera de evitar escribir codigo repetitivo. 

Los métodos de validación de esta clase son los siguientes:

- validateFields: validacion y tipado de un conjunto de datos del body,
- validateFieldsWithItems: validacion y tipado de un objeto con un array de objetos anidado,
- validateQuery: validacion y tipado de queries (Por causa de Express 5 crea una copia de esta).
- validateRegex: validacion de parametro del body por medio de regex,
- middUuid: validacion de UUID
- middIntId: validacion de id como numero entero.

#### validateFields:
\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
// Los elementos se validan ingresando el nombre y el tipo de dato dentro de un objeto:
const user = [{name: 'email', type: 'string'}, {name: 'password', type: 'string'}, {name:'phone', type: 'int'}]
// y en el router:
router.post('/', MiddlewareHandler.validateFields(user), controlador)

//Los tipos de datos permitidos son: 
'string': //para los strings,
'int': //para numeros enteros,
'float'. //para numeros decimales,
'boolean' //para booleanos
'array' //en el caso de un array (no valida su interior)

\`\`\`
Cabe aclarar que en caso de validateFields, validateFieldsWithItems y validateQuery los datos que no estén declarados serán borrados del body, los que estén declarados y falten se emitirá el mensaje y status de error correspondientes asi como tambien en el caso de no poder convertir un dato a su correspondiente tipo. 
<hr>

#### validateFieldsWithItems:
Este metodo es similar al anterior solo que valida tambien un array 
\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
// Los elementos se validan ingresando el nombre y el tipo de dato dentro de un objeto:
const user = [{name: 'email', type: 'string'}, {name: 'password', type: 'string'}, {name:'phone', type: 'int'}]
const address = [{name:'street', type:'string'}, {name:'number', type:'int'}]
// y en el router:
router.post('/', MiddlewareHandler.validateFieldsWithItems(user, address, 'address'), controlador)
 //Es necesario ingresar el nombre de la propiedad que va a evaluarse, en nuestro caso el json se veria asi:
 {
    "name": "Leanne Graham",
    "password": "xxxxxxxx",
    "phone": 5578896,
    "address":[{
        "street": "Kulas Light",
         "number": 225
        },
        {
          "street": "Victor Plains",
         "number": 1230
        }]
  }
\`\`\`
<hr>

### validateQuery
Los tipos de datos y validacion son los mismos que para los metodos anteriores, solo que en este caso se examina el objeto req.query:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
const queries = [
  { name: 'page', type: 'int' },
  { name: 'size', type: 'float' },
  { name: 'fields', type: 'string' },
  { name: 'truthy', type: 'boolean' }
]
router.get('/', MiddlewareHandler.validateQuery(queries),controlador)
//Y en este caso la url se veria asi:
//http://localhost:4000?page=2&size=2.5&fields=pepe&truthy=true'

\`\`\`
El objeto req.query quedará tal como está, ya que Express a partir de la version 5 lo convierte en un objeto inmutable, pero se hará una copia con los datos validados (validacion de los existentes y si no están crea por defecto) en el controlador a través de req.validatedQuery.

<hr>

### validateRegex
Este método se utiliza para validar por medio de regex una propiedad del body que lo requiera, es muy util para validar emails y passwords.
Los parametros requeridos son: el regex (que puede estar como en el ejemplo, en una variable), el nombres de la propiedad a validar y un mensaje si se quiere añadir algo al "Invalid xxx format".

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

router.post('/', MiddlewareHandler.validateRegex(emailRegex, 'email', 'Introduzca un mail valido'),controlador)
\`\`\`
<hr>

### middUuid y middIntid 

Están juntos ya que su funcionamiento es igual en ambos casos, solo cambia el tipo de dato a validar, en ambos se debe especificar el nombre dado al parametro a evaluar, por ejemplo:
\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...

router.get('/:userId', MiddlewareHandler.middIntId('userId'), controlador)

\`\`\`
El nombre aqui es solo ilustrativo, adoptará el nombre que se le pase.

Con esto se trató de alcanzar la mayor cantidad de casos de uso posibles, por supuesto, puede haber muchisimos más pero una gran parte ha quedado cubierta.
<hr>

Espero que esta breve explicación sirva. ¡Suerte!
EOL

# Mensaje de confirmación
echo "Estructura de la aplicación Express creada en '$PROJECT_DIR'."

# Ir a la carpeta del PROJECT_DIR
cd $PROJECT_DIR

# Instalar dependencias
echo "Instalando dependencias:..."
#npm install cross-env@latest cors@latest dotenv@latest express@latest helmet@latest morgan@latest @prisma/client@latest prisma@latest uuid@latest
echo "Instalando dependencias de desarrollo, aguarde un momento..."
#npm install @babel/core @babel/preset-env babel-jest nodemon@latest standard@latest supertest@latest jest@latest swagger-jsdoc swagger-ui-express -D
  
echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."
