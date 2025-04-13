#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Config,Middlewares,Controllers,Services,Services/mocks,Repositories,Modules,Modules/User,Modules/mocks,Modules/Post,Swagger,Swagger/schemas,Swagger/schemas/tools}
mkdir -p $PROJECT_DIR/test/{Middlewares,Middlewares/helpers,Repositories,Repositories/helpers}
# Crear el archivo index.js en src
cat > "$PROJECT_DIR/index.js" <<EOL
import fastify from './src/app.js'
import env from './src/Config/envConfig.js'

const starter = async () => {
  try {
    await fastify.listen({ port: env.Port, host: '0.0.0.0' })
    console.log(\` 🚀 Server is listening on port \${env.Port}\nServer in \${env.Status}\`)
    if (env.Status === 'development') {
      console.log(\` 📌 Swagger: Vea y pruebe los endpoints en http://localhost:\${env.Port}/api-docs\`)
    }
  } catch (error) {
    fastify.log.error(error)
    process.exit(1)
  }
}
starter()
EOL
# Crear el archivo app.js en src
cat > "$PROJECT_DIR/src/app.js" <<EOL
import Fastify from 'fastify'
import * as conf from './Config/serverConfigs.js'
// import prismaPlugin from './Config/db.js'
import cors from '@fastify/cors'
import multipart from '@fastify/multipart'
import mockRouter from './Modules/mocks/mocksRouter.js'
import { swaggerPlugin, swaggerUi } from './Swagger/pluginSwagger.js'
// import postRouter from './Modules/Posts/postRouter.js'
// import userRouter from './Modules/User/userRouter.js'
import swagger from '@fastify/swagger'
import swaggerUI from '@fastify/swagger-ui'

const fastify = Fastify({
  logger: conf.pinoPretty,
  ajv: { customOptions: conf.ajvOptions }
})

// fastify.register(prismaPlugin)
fastify.register(cors, conf.fastiCors)
fastify.register(multipart, {
  limits: {
    fileSize: 1000000 // 1 MB
  }
})

// await fastify.register(swaggerPlugin)
await fastify.register(swagger, swaggerPlugin)

await fastify.register(swaggerUI, swaggerUi)

await fastify.register(mockRouter, { prefix: '/api/users' })
// await fastify.register(postRouter, { prefix: '/api/post' })
// await fastify.register(userRouter, { prefix: '/api/user' })

fastify.setErrorHandler((error, request, reply) => { // Error EndWare
  const status = error.status || 500
  reply.status(status).send({
    success: false,
    message: error.message,
    results: 'Failed to process the request'
  })
})

export default fastify
EOL
# Crear el archivo envConfig.js en src/Config
cat > "$PROJECT_DIR/src/Config/envConfig.js" <<EOL
import dotenv from 'dotenv'
import path from 'path'
import fs from 'fs'

const configEnv = {
  development: '.env.development',
  production: '.env.production',
  test: '.env.test'
}
const envFile = configEnv[process.env.NODE_ENV] || '.env.production'

dotenv.config({ path: envFile })

const Status = process.env.NODE_ENV
const { PORT, DB_NAME } = process.env
const dbPath = 'db'//path.join(path.resolve('database'), DB_NAME) esta linea es para sqlite

// Generar el archivo .env dinámico para Prisma
fs.writeFileSync(
  '.env',
    \`PORT=\${PORT}\nDATABASE_URL=file:\${dbPath}\`
)
export default {
  Port: Number(PORT),
  Status,
  DBURL: \`file:\${dbPath}\`,
  cleanEnvFile: async () => {
    try {
      if (fs.existsSync('.env')) {
        await fs.promises.unlink('.env') // Elimina el archivo .env
        console.log('Archivo .env eliminado correctamente.')
      }
    } catch (error) {
      console.error('Error al eliminar el archivo .env:', error.message)
    }
  }
}
EOL
# Crear el archivo db.js en src/Config
cat > "$PROJECT_DIR/src/Config/db.js" <<EOL
import { PrismaClient } from '@prisma/client'
import fp from 'fastify-plugin'

const prisma = new PrismaClient()

export default fp(async (fastify) => {
  fastify.decorate('prisma', prisma)

  fastify.addHook('onClose', async () => {
    await prisma.\$disconnect()
  })
})
EOL
# Crear el archivo errorHandler.js en src/Config
cat > "$PROJECT_DIR/src/Config/errorHandlers.js" <<EOL
export default {
  throwError: (message, status) => {
    const error = new Error(message)
    error.status = status
    throw error
  }
}
EOL
# Crear el archivo serverConfig.js en src/Config
cat > "$PROJECT_DIR/src/Config/serverConfigs.js" <<EOL
export const pinoPretty = {
  transport: {
    target: 'pino-pretty',
    options: {
      translateTime: 'HH:MM:ss',
      ignore: 'pid,hostname,level',
      colorize: true
    }
  }
}

export const fastiCors = {
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['Content-Type', 'Authorization']
}

export const ajvOptions = { //* Esto para poder trabajar con swagger y ajv
  strict: false, // Permite palabras no estándar como "example"
  keywords: ['example'], // Declaramos explícitamente las keywords extra que queremos permitir
  coerceTypes: 'array', // Opcional: activar coerción de tipos (por ejemplo, convertir '123' en número)
  // Opcional: remover propiedades que no estén en el schema
  removeAdditional: 'failing', // o 'all' si querés borrarlas sin fallar
  allErrors: true // Validar todas las propiedades en vez de frenar al primer error
}
EOL
# Crear el archivo genericController.js en src/Controllers
cat > "$PROJECT_DIR/src/Controllers/genericController.js" <<EOL
const genericController = (service) => {
  const responder = (reply, status, success, message = null, results = null) => {
    reply.status(status).send({ success, message, results })
  }
  return {
    async create (request, reply) {
      const data = request.body
      const response = await service.create(data)
      return responder(reply, 201, true, response.message, response.results)
    },

    async getAll (request, reply) {
      const query = request.query || {}
      const response = await service.getAll(query)
      return responder(reply, 200, true, response.message, response.results)
    },

    async getById (request, reply) {
      const { id } = request.params
      const response = await service.getById(id)
      return responder(reply, 200, true, response.message, response.results)
    },

    async update (request, reply) {
      const { id } = request.params
      const data = request.body
      const response = await service.update(id, data)
      return responder(reply, 200, true, response.message, response.results)
    },

    async delete (request, reply) {
      const { id } = request.params
      const response = await service.delete(id)
      return responder(reply, 200, true, response.message, response.results)
    }
  }
}

export default genericController
EOL
# Crear el archivo MiddlewareHandler.js en src/Middlewares
cat > "$PROJECT_DIR/src/Middlewares/MiddlewareHandler.js" <<EOL
import { validate as uuidValidate } from 'uuid'
// Esta clase fue hecha para trabajar con fastify (metodos no validos para Express)

class MiddlewareHandler {
  static throwError (message, status) {
    const error = new Error(message)
    error.status = status
    throw error
  }

  static validateBoolean (value) {
    if (typeof value === 'boolean') return value
    if (value === 'true') return true
    if (value === 'false') return false
    MiddlewareHandler.throwError('Invalid boolean value', 400)
  }

  static validateInt (value) {
    const intValue = Number(value)
    if (isNaN(intValue) || !Number.isInteger(intValue)) MiddlewareHandler.throwError('Invalid integer value', 400)
    return intValue
  }

  static validateFloat (value) {
    const floatValue = parseFloat(value)
    if (isNaN(floatValue)) MiddlewareHandler.throwError('Invalid float value', 400)
    return floatValue
  }

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
          MiddlewareHandler.throwError(\`Invalid array value for field \${fieldName}\${indexInfo}\`, 400)
        }
        return value
      case 'string':
      default:
        if (typeof value !== 'string') {
          MiddlewareHandler.throwError(\`Invalid string value for field \${fieldName}\${indexInfo}\`, 400)
        }
        return value
    }
  }

  static validateFields (requiredFields = []) {
    return async (request, reply) => {
      const newData = request.body
      if (!newData || Object.keys(newData).length === 0) {
        MiddlewareHandler.throwError('Invalid parameters', 400)
      }

      const missingFields = requiredFields.filter(field => !(field.name in newData))
      if (missingFields.length > 0) {
        MiddlewareHandler.throwError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400)
      }

      requiredFields.forEach(field => {
        const value = newData[field.name]
        newData[field.name] = MiddlewareHandler.validateValue(value, field.type, field.name)
      })

      Object.keys(newData).forEach(key => {
        if (!requiredFields.some(field => field.name === key)) {
          delete newData[key]
        }
      })

      request.body = newData
    }
  }

  static validateFieldsWithItems (requiredFields = [], secondFields = [], arrayFieldName) {
    return async (request, reply) => {
      const firstData = { ...request.body }
      const secondData = Array.isArray(request.body[arrayFieldName]) ? [...request.body[arrayFieldName]] : null

      if (!firstData || Object.keys(firstData).length === 0) {
        MiddlewareHandler.throwError('Invalid parameters', 400)
      }

      const missingFields = requiredFields.filter(field => !(field.name in firstData))
      if (missingFields.length > 0) {
        MiddlewareHandler.throwError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400)
      }

      requiredFields.forEach(field => {
        const value = firstData[field.name]
        firstData[field.name] = MiddlewareHandler.validateValue(value, field.type, field.name)
      })

      Object.keys(firstData).forEach(key => {
        if (!requiredFields.some(field => field.name === key)) {
          delete firstData[key]
        }
      })

      if (!secondData || secondData.length === 0) {
        MiddlewareHandler.throwError(\`Missing \${arrayFieldName} array or empty array\`, 400)
      }

      const invalidStringItems = secondData.filter(item => typeof item === 'string')
      if (invalidStringItems.length > 0) {
        MiddlewareHandler.throwError(\`Invalid "\${arrayFieldName}" content: expected objects but found strings\`, 400)
      }

      const validatedSecondData = secondData.map((item, index) => {
        const missingItemFields = secondFields.filter(field => !(field.name in item))
        if (missingItemFields.length > 0) {
          MiddlewareHandler.throwError(\`Missing parameters in \${arrayFieldName}[\${index}]: \${missingItemFields.map(f => f.name).join(', ')}\`, 400)
        }

        secondFields.forEach(field => {
          const value = item[field.name]
          item[field.name] = MiddlewareHandler.validateValue(value, field.type, field.name, index)
        })

        return secondFields.reduce((acc, field) => {
          acc[field.name] = item[field.name]
          return acc
        }, {})
      })

      request.body = {
        ...firstData,
        [arrayFieldName]: validatedSecondData
      }
    }
  }

  static validateQuery (requiredFields = []) {
    return async (request, reply) => {
      const queryObject = request.query || {}

      try {
        requiredFields.forEach(field => {
          let value = queryObject[field.name]

          if (value === undefined) {
            // Asignar valores por defecto si el parámetro no está presente
            switch (field.type) {
              case 'boolean':
                value = false
                break
              case 'int':
                value = 1
                break
              case 'float':
                value = 1.0
                break
              case 'string':
              default:
                value = ''
            }
          } else {
            value = MiddlewareHandler.validateValue(value, field.type, field.name)
          }

          queryObject[field.name] = value
        })

        Object.keys(queryObject).forEach(key => {
          if (!requiredFields.some(field => field.name === key)) {
            delete queryObject[key]
          }
        })
      } catch (error) {
        MiddlewareHandler.throwError(\`Invalid query parameter: \${error.message}\`, 400)
      }

      request.query = queryObject
    }
  }

  static validateRegex (validRegex, nameOfField, message = null) {
    return async (request, reply) => {
      if (!validRegex || !nameOfField || nameOfField.trim() === '') {
        MiddlewareHandler.throwError('Missing parameters in function', 400)
      }
      const field = request.body[nameOfField]
      const personalizedMessage = message ? ' ' + message : ''
      if (!field || typeof field !== 'string' || field.trim() === '') {
        MiddlewareHandler.throwError(\`Missing parameter: \${nameOfField}\`, 400)
      }
      if (!validRegex.test(field)) {
        MiddlewareHandler.throwError(\`Invalid \${nameOfField} format!\${personalizedMessage}\`, 400)
      }
    }
  }

  static async middUuid (request, reply) {
    const { id } = request.params
    if (!id || !uuidValidate(id)) {
      MiddlewareHandler.throwError('Invalid UUID', 400)
    }
  }

  static async middIntId (request, reply) {
    const { id } = request.params
    if (!id || !Number.isInteger(Number(id))) {
      MiddlewareHandler.throwError('Invalid ID', 400)
    }
  }
}

export default MiddlewareHandler
EOL
# Crear el archivo repository.js en src/Repositories
cat > "$PROJECT_DIR/src/repositories/repositories.js" <<EOL
const repositories = (model, model2 = null) => {
  return {
    async create (data) {
      return await model.create({
        data
      })
    },

    async getAll () {
      return await model.findMany()
    },

    async getFilters (queryObject) {
      const { field, value } = queryObject
      return await model.findMany({
        where: {
          [field]:
                       { startsWith: value }
        }
      })
    },

    async getNumbersFilters (fieldObject) {
      const [[field, value]] = Object.entries(fieldObject)
      return await model.findMany({
        where: { [field]: parseInt(value) }
      })
    },
    async getWithItems () {
      return await model.findMany({
        include: {
          author: {
            select: {
              nickname: true
            }
          }
        }
      })
    },

    async getById (id) {
      return await model.findUnique({
        where: { id: parseInt(id) }
      })
    },

    async getOne (field, value) {
      return await model.findUnique({
        where: { [field]: value }
      })
    },

    async update (id, data) {
      return await model.update({
        where: { id: parseInt(id) },
        data
      })
    },

    async delete (id) {
      return await model.delete({
        where: { id: parseInt(id) }
      })
    }
  }
}

export default repositories
EOL
# Crear el archivo getFilterRepository.js en src/repositories
cat > "$PROJECT_DIR/src/repositories/getFilterRepository.js" <<EOL
const getFilterRepository = async (model, queryObject) => {
  const { field, value } = queryObject
  return await model.findMany({
    where: {
      [field]:
                   { startsWith: value }
    }
  })
}

export default getFilterRepository
EOL
# Crear el archivo userService.js en src/Services
cat > "$PROJECT_DIR/src/Services/userService.js" <<EOL
import eh from '../Config/errorHandlers.js'
import bcrypt from 'bcrypt'

const throwError = eh.throwError

const userService = (rep) => {
  return {
    async create (data) {
      const userExist = await rep.getOne('email', data.email)
      if (userExist) { throwError('Este usuario ya existe', 400) }
      const nickName = data.email.split('@')[0]
      const hashedPass = await bcrypt.hash(data.password, 12)
      const newUser = await rep.create({
        email: data.email,
        password: hashedPass,
        nickname: nickName,
        name: data.name || ''
      })
      return {
        message: 'Usuario creado correctamente',
        results: userParser(newUser)
      }
    },
    async login (data) {
      const userExist = await rep.getOne('email', data.email)
      if (!userExist) { throwError('Este usuario no existe', 404) }
      const passwordMatch = await bcrypt.compare(data.password, userExist.password)
      if (!passwordMatch) { throwError('Contraseñe incorrecta', 400) }
      return {
        message: 'Validacion exitosa',
        results: {
          user: userParser(userExist),
          token: null
        }
      }
    },
    async getAll () {
      const user = await rep.getAll()
      if (user.length === 0) { throwError('No hay datos aun', 404) }
      return {
        message: 'Busqueda exitoss',
        results: user.map(d => userParser(d))
      }
    },
    async getById (id) {
      const user = await rep.getById(id)
      if (!user) { throwError('Usuario no hallado', 404) }
      return {
        message: 'Busqueda exitosa',
        results: userParser(user)
      }
    },
    async update (id, data) {
      const user = await rep.getById(id)
      if (!user) { throwError('Usuario no hallado', 404) }
      const name = user.nickname
      const userUpd = await rep.update(id, data)
      return {
        message: \`Usuario \${name} actualizado exitosamente\`,
        results: userParser(userUpd)
      }
    },
    async delete (id) {
      const user = await rep.getById(id)
      if (!user) { throwError('Usuario no hallado', 404) }
      const name = user.nickname
      const email = user.email
      await rep.delete(id)
      return {
        message: \`Usuario \${name} eliminado exitosamente\`,
        results: email
      }
    }
  }
}
export default userService

function userParser (data) {
  return {
    id: data.id,
    email: data.email,
    name: data.name,
    nickname: data.nickname,
    biografy: data.biografy
  }
}
EOL
# Crear el archivo postService.js en src/Services
cat > "$PROJECT_DIR/src/Services/postService.js" <<EOL
import eh from '../Config/errorHandlers.js'

const throwError = eh.throwError

const postService = (rep) => {
  return {
    async create (data) {
      const postExist = await rep.getOne('title', data.title)
      if (postExist) { throwError('Este post ya existe', 400) }
      const newPost = await rep.create({
        title: data.title,
        content: data.content,
        authorId: data.authorId
      })
      return {
        message: 'Post creado correctamente',
        results: newPost
      }
    },
    async getAll () {
      const post = await rep.getWithItems()
      if (post.length === 0) { throwError('No hay datos aun', 404) }
      return {
        message: 'Busqueda exitosa',
        results: post
      }
    },
    async getNumFilters (queryObject) {
      const post = await rep.getNumbersFilters(queryObject)
      if (post.length === 0) { throwError('No hay datos aun', 404) }
      return {
        message: 'Busqueda exitosa',
        results: post
      }
    },
    async getById (id) {
      const post = await rep.getById(id)
      if (!post) { throwError('Post no hallado', 404) }
      return {
        message: 'Busqueda exitosa',
        results: post
      }
    },
    async update (id, data) {
      const post = await rep.getById(id)
      if (!post) { throwError('Post no hallado', 404) }
      const postUpd = await rep.update(id, data)
      const name = post.title
      return {
        message: \`Post \${name} actualizado exitosamente\`,
        results: postUpd
      }
    },
    async delete (id) {
      const post = await rep.getById(id)
      if (!post) { throwError('Usuario no hallado', 404) }
      const name = post.title
      await rep.delete(id)
      return {
        message: \`Usuario \${name} eliminado exitosamente\`,
        results: title
      }
    }
  }
}
export default postService
EOL
# Crear el archivo UserService.js en src/Services/mocks
cat > "$PROJECT_DIR/src/Services/mocks/UserService.js" <<EOL
import eh from '../../Config/errorHandlers.js'

const mockUserService = (Model) => {
  return {
  // Crear un nuevo usuario
    create (data) {
      const newId = Model.length ? Math.max(...Model.map(user => user.id)) + 1 : 1
      const randomSevenDigit = () => Math.floor(1000000 + Math.random() * 9000000)

      const newUser = {
        id: newId,
        name: data.name,
        username: data.username,
        email: data.email,
        enable: true,
        phone: randomSevenDigit()
      }
      Model.push(newUser)
      return {
        message: 'User created successfully',
        results: newUser
      }
    },

    // Obtener todos los usuarios
    getAll () {
      return {
        message: 'Users found',
        results: Model
      }
    },

    // Obtener un usuario por ID
    getById (id) {
      const response = Model.find(user => user.id === Number(id))
      if (!response) { eh.throwError('User not found', 404) }
      return {
        message: 'Users found',
        results: response
      }
    },

    // Actualizar un usuario por ID
    update (id, newData) {
      const index = Model.findIndex(user => user.id === Number(id))
      if (index === -1) { eh.throwError('This user do not exists', 404) };

      Model[index] = { ...Model[index], ...newData }
      return {
        message: 'Users updated successfully',
        results: Model[index]
      }
    },

    // Eliminar un usuario por ID
    delete (id) {
      const index = Model.findIndex(user => user.id === Number(id))
      if (index === -1) { eh.throwError('User not found', 404) }
      return {
        message: 'User deleted successfully',
        results: Model.splice(index, 1)[0] // Elimina y devuelve el usuario eliminado
      }
    }
  }
}

export default mockUserService
EOL
# Crear el archivo users.js en src/Services/mocks
cat > "$PROJECT_DIR/src/Services/mocks/users.js" <<EOL
const users = [
  {
    id: 1,
    name: 'Leanne Graham',
    username: 'Bret',
    email: 'Sincere@april.biz',
    enable: true,
    phone: 5578896
  },
  {
    id: 2,
    name: 'Ervin Howell',
    username: 'Antonette',
    email: 'Shanna@melissa.tv',
    enable: true,
    phone: 3420219
  },
  {
    id: 3,
    name: 'Clementine Bauch',
    username: 'Samantha',
    email: 'Nathan@yesenia.net',
    enable: true,
    phone: 7101901
  },
  {
    id: 4,
    name: 'Patricia Lebsack',
    username: 'Karianne',
    email: 'Julianne.OConner@kory.org',
    enable: true,
    phone: 3623102
  },
  {
    id: 5,
    name: 'Chelsey Dietrich',
    username: 'Kamren',
    email: 'Lucio_Hettinger@annie.ca',
    enable: true,
    phone: 1051203
  },
  {
    id: 6,
    name: 'Mrs. Dennis Schulist',
    username: 'Leopoldo_Corkery',
    email: 'Karley_Dach@jasper.info',
    enable: true,
    phone: 5862081
  },
  {
    id: 7,
    name: 'Kurtis Weissnat',
    username: 'Elwyn.Skiles',
    email: 'Telly.Hoeger@billy.biz',
    enable: true,
    phone: 7452263
  },
  {
    id: 8,
    name: 'Nicholas Runolfsdottir V',
    username: 'Maxime_Nienow',
    email: 'Sherwood@rosamond.me',
    enable: true,
    phone: 9235392
  },
  {
    id: 9,
    name: 'Glenna Reichert',
    username: 'Delphine',
    email: 'Chaim_McDermott@dana.io',
    enable: true,
    phone: 2582826
  },
  {
    id: 10,
    name: 'Clementina DuBuque',
    username: 'Moriah.Stanton',
    email: 'Rey.Padberg@karina.biz',
    enable: true,
    phone: 8987275
  }
]
export default users
EOL
# Crear el archivo userModule.js en Modules/User
cat > "$PROJECT_DIR/src/Modules/User/userModule.js" <<EOL
export const dataUser = [{
  name: 'email', type: 'string'
}, {
  name: 'password', type: 'string'
}]

export const dataUserUpd = [{
  name: 'name', type: 'string'
}, {
  name: 'password', type: 'string'
}, {
  name: 'biografy', type: 'string'
}]

export const mailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
export const passRegex = /^(?=.*[A-Z]).{8,}$/
EOL
# Crear el archivo userRouter.js en Modules/User
cat > "$PROJECT_DIR/src/Modules/User/userRouter.js" <<EOL
import { dataUser, dataUserUpd, mailRegex, passRegex } from './userModule.js'
import repositories from '../../repositories/repositories.js'
import userService from '../../Services/userService.js'
import genericController from '../../Controllers/genericController.js'
import MiddlewareHandler from '../../Middlewares/MiddlewareHandler.js'

export default async function userRouter (fastify, options) {
  const userRep = repositories(fastify.prisma.user)
  const user = userService(userRep)
  const cont = genericController(user)
  fastify.post('/create',
    {
      preHandler: [MiddlewareHandler.validateRegex(passRegex, 'password', 'Password musk contain at least 8 characters and 1 Uppercase'),
        MiddlewareHandler.validateRegex(mailRegex, 'email'),
        MiddlewareHandler.validateFields(dataUser)]
    },
    cont.create)
  fastify.post('/login',
    {
      preHandler: [MiddlewareHandler.validateRegex(passRegex, 'password'),
        MiddlewareHandler.validateRegex(mailRegex, 'email'),
        MiddlewareHandler.validateFields(dataUser)]
    },
    async (request, reply) => {
      const data = request.body
      const response = await user.login(data)
      return reply.status(200).send({ success: true, message: response.message, results: response.results })
    })
  fastify.get('/',
    { preHandler: MiddlewareHandler.validateQuery([{ name: 'authorId', type: 'int', required: false }]) },
    cont.getAll)
  fastify.get('/:id',
    { preHandler: MiddlewareHandler.middIntId },
    cont.getById)
  fastify.put('/:id',
    {
      preHandler: [MiddlewareHandler.middIntId,
        MiddlewareHandler.validateFields(dataUserUpd),
        MiddlewareHandler.validateRegex(passRegex, 'password', 'Password musk contain at least 8 characters and 1 Uppercase')]
    },
    cont.update)
  fastify.delete('/:id',
    { preHandler: MiddlewareHandler.middIntId },
    cont.delete)
}
EOL
# Crear el archivo postModule.js en Modules/Post
cat > "$PROJECT_DIR/src/Modules/Post/postModule.js" <<EOL
export const dataPost = [{
  name: 'title', type: 'string'
}, {
  name: 'content', type: 'string'
}, {
  name: 'authorId', type: 'int'
}
]

export const dataPostUpd = [{
  name: 'title', type: 'string'
}, {
  name: 'content', type: 'string'
}, {
  name: 'authorId', type: 'int'
}
]
EOL
# Crear el archivo postRouter.js en Modules/Post
cat > "$PROJECT_DIR/src/Modules/Post/postRouter.js" <<EOL
import repositories from '../../repositories/repositories.js'
import postService from '../../Services/postService.js'
import genericController from '../../Controllers/genericController.js'
import { dataPost, dataPostUpd } from './postModule.js'
import MiddlewareHandler from '../../Middlewares/MiddlewareHandler.js'

export default async function postRouter (fastify, options) {
  const postRep = repositories(fastify.prisma.post, fastify.prisma.user)
  const post = postService(postRep)
  const cont = genericController(post)

  fastify.post('/create',
    { preHandler: MiddlewareHandler.validateFields(dataPost) },
    cont.create)
  fastify.get('/',
    { preHandler: MiddlewareHandler.validateQuery([{ name: 'authorId', type: 'int', required: false }]) },
    cont.getAll)

  fastify.get('/admin', async (request, reply) => {
    const authorId = request.query
    const response = await post.getNumFilters(authorId)
    return reply.status(200).send({ success: true, message: response.message, results: response.results })
  })
  fastify.get('/perico', async (request, reply) => {
    return reply.status(200).send('estoy aca en perico')
  })

  fastify.get('/:id',
    { preHandler: MiddlewareHandler.middIntId },
    cont.getById)
  fastify.put('/:id',
    { preHandler: [MiddlewareHandler.middIntId, MiddlewareHandler.validateFields(dataPostUpd)] },
    cont.update)
  fastify.delete('/:id',
    { preHandler: MiddlewareHandler.middIntId },
    cont.delete)
}
EOL
# Crear el archivo auxFunctions.js en Modules/mocks
cat > "$PROJECT_DIR/src/Modules/mocks/auxFunctions.js" <<EOL
export const userCreate = [
  { name: 'name', type: 'string' },
  { name: 'username', type: 'string' },
  { name: 'email', type: 'string' }]

export const userUpdate = [
  { name: 'name', type: 'string' },
  { name: 'username', type: 'string' },
  { name: 'email', type: 'string' },
  { name: 'enable', type: 'boolean' },
  { name: 'phone', type: 'int' }]

export const regexEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
EOL
# Crear el archivo mocksRouter.js en Modules/mocks
cat > "$PROJECT_DIR/src/Modules/mocks/mocksRouter.js" <<EOL
import { userCreate, userUpdate, regexEmail } from './auxFunctions.js'
import mockUserService from '../../Services/mocks/UserService.js'
import users from '../../Services/mocks/users.js'
import genericController from '../../Controllers/genericController.js'
import MiddlewareHandler from '../../Middlewares/MiddlewareHandler.js'
import * as sw from '../../Swagger/schemas/user.schema.js'

const userM = mockUserService(users)
const cont = genericController(userM)
export default async function mockRouter (fastify, options) {
  fastify.post('/create',
    {
      schema: sw.createUserSchema,
      preHandler: [
        MiddlewareHandler.validateRegex(regexEmail, 'email'),
        MiddlewareHandler.validateFields(userCreate)],
      handler: cont.create
    })

  fastify.get('/', {
    schema: sw.listUsersSchema,
    preHandler: MiddlewareHandler.validateQuery([{ name: 'authorId', type: 'int', required: false }]),
    handler: cont.getAll
  })
  fastify.get('/:id', {
    schema: sw.getUserByIdSchema,
    preHandler: MiddlewareHandler.middIntId,
    handler: cont.getById
  })
  fastify.put('/:id', {
    schema: sw.updateUserSchema,
    preHandler: MiddlewareHandler.validateFields(userUpdate),
    handler: cont.update
  })
  fastify.delete('/:id', {
    schema: sw.deleteUserSchema,
    preHandler: MiddlewareHandler.middIntId,
    handler: cont.delete
  })
}
EOL
# Crear el archivo pluginSwagger.js en Swagger
cat > "$PROJECT_DIR/src/Swagger/pluginSwagger.js" <<EOL
import env from '../Config/envConfig.js'
import { userTag } from './schemas/user.schema.js'

// Registra el plugin de swagger
export const swaggerPlugin = {
  openapi: {
    info: {
      title: "$PROJECT_DIR",
      description: 'Documentación de la API',
      version: '1.0.0'
    },
    tags: [userTag],
    servers: [{
      url: \`http://localhost:\${env.Port}\`,
      description: 'Server REST de fastify'
    }],
     components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    },
    security: [
      {
        bearerAuth: []
      }
    ]
  },
  exposeRoute: true
}

// Registra la UI de swagger
export const swaggerUi = {
  routePrefix: '/api-docs',
  uiConfig: {
    docExpansion: 'none',
    deepLinking: false
  }
}
EOL
# Crear el archivo index en schemas
cat > "$PROJECT_DIR/src/Swagger/schemas/index.js" <<EOL
EOL
# Crear el archivo userSchema en schemas
cat > "$PROJECT_DIR/src/Swagger/schemas/user.schema.js" <<EOL
export const userTag = {
  name: 'Users',
  description: 'Operaciones relacionadas con usuarios (modo experimental)'
}

export const createUserSchema = {
  tags: ['Users'],
  summary: 'Crear un nuevo usuario',
  body: {
    type: 'object',
    properties: {
      name: { type: 'string' },
      username: { type: 'string' },
      email: { type: 'string', format: 'email' }
    },
    required: ['name', 'username', 'email']
  },
  response: {
    201: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        results: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            name: { type: 'string' },
            username: { type: 'string' },
            email: { type: 'string', format: 'email' },
            enable: { type: 'boolean' },
            phone: { type: 'integer' }
          },
          required: ['id', 'name', 'username', 'email', 'enable', 'phone']
        }
      },
      required: ['success', 'message', 'results']
    }
  }
}

export const listUsersSchema = {
  tags: ['Users'],
  summary: 'Lista de usuarios',
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        results: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              name: { type: 'string' },
              username: { type: 'string' },
              email: { type: 'string', format: 'email' },
              enable: { type: 'boolean' },
              phone: { type: 'integer' }
            },
            required: ['id', 'name', 'username', 'email', 'enable', 'phone']
          }
        }
      },
      required: ['success', 'message', 'results']
    }
  }
}

export const getUserByIdSchema = {
  summary: 'Detalle de un usuario',
  tags: ['Users'],
  params: {
    type: 'object',
    properties: {
      id: {
        type: 'integer',
        description: 'ID del usuario',
        example: 1
      }
    },
    required: ['id']
  },
  response: {
    200: {
      description: 'Usuario encontrado',
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        message: { type: 'string', example: 'Usuario encontrado' },
        results: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            name: { type: 'string' },
            username: { type: 'string' },
            email: { type: 'string', format: 'email' },
            enable: { type: 'boolean' },
            phone: { type: 'integer' }
          }
        }
      }
    },
    404: {
      description: 'Usuario no encontrado',
      type: 'object',
      properties: {
        success: { type: 'boolean', example: false },
        message: { type: 'string', example: 'Usuario no encontrado' }
      }
    }
  }
}

export const updateUserSchema = {
  summary: 'Actualizar un usuario existente',
  tags: ['Users'],
  params: {
    type: 'object',
    properties: {
      id: {
        type: 'integer',
        description: 'ID del usuario a actualizar',
        example: 1
      }
    },
    required: ['id']
  },
  body: {
    type: 'object',
    properties: {
      name: { type: 'string' },
      username: { type: 'string' },
      email: { type: 'string', format: 'email' },
      enable: { type: 'boolean' },
      phone: { type: 'integer' }
    },
    required: ['name', 'username', 'email']
  },
  response: {
    200: {
      description: 'Usuario actualizado exitosamente',
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        message: { type: 'string', example: 'Usuario actualizado' },
        results: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            name: { type: 'string' },
            username: { type: 'string' },
            email: { type: 'string', format: 'email' },
            enable: { type: 'boolean' },
            phone: { type: 'integer' }
          }
        }
      }
    },
    404: {
      description: 'Usuario no encontrado',
      type: 'object',
      properties: {
        success: { type: 'boolean', example: false },
        message: { type: 'string', example: 'Usuario no encontrado' }
      }
    }
  }
}
export const deleteUserSchema = {
  summary: 'Eliminar un usuario',
  tags: ['Users'],
  params: {
    type: 'object',
    properties: {
      id: {
        type: 'integer',
        description: 'ID del usuario a eliminar',
        example: 1
      }
    },
    required: ['id']
  },
  response: {
    200: {
      description: 'Usuario eliminado exitosamente',
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        message: { type: 'string', example: 'Usuario eliminado' }
      }
    },
    404: {
      description: 'Usuario no encontrado',
      type: 'object',
      properties: {
        success: { type: 'boolean', example: false },
        message: { type: 'string', example: 'Usuario no encontrado' }
      }
    }
  }
}
EOL
# Crear el archivo generateSchema en schemas/tuols
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

const askSchemaInfo = async () => {
  const { tag } = await inquirer.prompt([
    { type: 'input', name: 'tag', message: 'Nombre del tag (ej: Users)' }
  ]);

  const { singular } = await inquirer.prompt([
    { type: 'input', name: 'singular', message: 'Nombre singular del recurso (ej: user)' }
  ]);

  const { include } = await inquirer.prompt([
    {
      type: 'checkbox',
      name: 'include',
      message: '¿Qué partes del schema querés incluir?',
      choices: [
        { name: 'body', checked: true },
        { name: 'params' },
        { name: 'querystring' },
        { name: 'response', checked: true }
      ]
    }
  ]);

  return {
    tag,
    singular,
    fields: await askFields(),
    include: {
      body: include.includes('body'),
      params: include.includes('params'),
      querystring: include.includes('querystring'),
      response: include.includes('response')
    }
  };
};

const buildProperties = (fields) => {
  const props = {};
  fields.forEach(field => {
    props[field.name] = { type: field.type };
    if (field.format) props[field.name].format = field.format;
  });
  return props;
};

const capitalize = (str) => str.charAt(0).toUpperCase() + str.slice(1);

const sectionCode = {
  params: (singular) => \`
  params: {
    type: 'object',
    properties: {
      id: { type: 'integer', description: 'ID del \${singular}' }
    },
    required: ['id']
  },\`,

  querystring: (properties, required) => \`
  querystring: {
    type: 'object',
    properties: \${JSON.stringify(properties, null, 2)},
    required: \${JSON.stringify(required)}
  },\`,

  body: (properties, required) => \`
  body: {
    type: 'object',
    properties:\${JSON.stringify(properties, null, 2)},
    required: \${JSON.stringify(required)}
  },\`,

  response: (properties, required, isArray = false) => \`
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message: { type: 'string' },
        results: \${isArray ? \`{
          type: 'array',
          items: {
            type: 'object',
            properties: \${JSON.stringify(properties, null, 2)},
            required: \${JSON.stringify(required)}
          }
        }\` : \`{
          type: 'object',
          properties: \${JSON.stringify(properties, null, 2)},
          required: \${JSON.stringify(required)}
        }\`}
      },
      required: ['success', 'message', 'results']
    }
  },\`
};

const buildOperation = (name, summary, tag, parts, capital, singular, properties, required, isArray = false) => {
  const includedSections = [
    parts.body ? sectionCode.body(properties, required) : '',
    parts.querystring ? sectionCode.querystring(properties, required) : '',
    name === 'getById' || name === 'update' || name === 'delete'
      ? sectionCode.params(singular) : '',
    parts.response ? sectionCode.response(properties, required, isArray) : ''
  ].join('\n');

  return \`
export const \${name}\${capital}Schema = {
  tags: ['\${tag}'],
  summary: '\${summary}',
  security: [{ bearerAuth: [] }],
  \${includedSections.trim()}
};\`.trim();
};

const generateSchemaFile = async ({ tag, singular, fields, include }) => {
  const fileName = \`\${singular}.schema.js\`;
  const filePath = path.join(outputPath, fileName);

  const capital = capitalize(singular);
  const required = fields.map(f => f.name);
  const properties = buildProperties(fields);

  const tagExport = \`
export const \${singular}Tag = {
  name: '\${tag}',
  description: 'Operaciones relacionadas con \${tag.toLowerCase()}'
};\n\`;

  const allSchemas = [
    buildOperation('create', \`Crear un nuevo \${singular}\`, tag, include, capital, singular, properties, required),
    buildOperation('getAll', \`Obtener todos los \${singular}s\`, tag, include, capital, singular, properties, required, true),
    buildOperation('getById', \`Obtener un \${singular} por ID\`, tag, include, capital, singular, properties, required),
    buildOperation('update', \`Actualizar un \${singular}\`, tag, include, capital, singular, properties, required),
    buildOperation('delete', \`Eliminar un \${singular}\`, tag, include, capital, singular, properties, required)
  ];

  fs.writeFileSync(filePath, tagExport + '\n' + allSchemas.join('\n\n') + '\n');

  // export in index.js
  const indexPath = path.join(outputPath, 'index.js');
  const exportLine = \`export * from './\${singular}.schema.js';\n\`;

  if (!fs.existsSync(indexPath)) {
    fs.writeFileSync(indexPath, exportLine);
  } else {
    const current = fs.readFileSync(indexPath, 'utf8');
    if (!current.includes(exportLine)) fs.appendFileSync(indexPath, exportLine);
  }

  console.log(\`✅ Schema creado: schemas/\${fileName}\`);
};

const main = async () => {
  if (!fs.existsSync(outputPath)) fs.mkdirSync(outputPath);
  const schemaInfo = await askSchemaInfo();
  await generateSchemaFile(schemaInfo);
};

main();
EOL
# Crear el archivo vitest.setup.js en test
cat > "$PROJECT_DIR/test/vitest.setup.js" <<EOL
import { PrismaClient } from '@prisma/client'
import { execSync } from 'child_process'
import { beforeAll, afterAll } from 'vitest'

// global.__db_initialized = false; // Variable global para controlar la inicialización
export const prisma = new PrismaClient()

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
})
EOL
# Crear el archivo EnvDb.test.js en test
cat > "$PROJECT_DIR/test/EnvDb.test.js" <<EOL
import { describe, expect, it } from 'vitest'
import env from '../src/Config/envConfig.js'
import { prisma } from './vitest.setup.js'

const user = prisma.user
const post = prisma.post

describe('Test de variables de entorno y Db', () => {
  //  beforeAll(async ()=>{
  //     initializeDatabase()
  // })
  it('deberia conectarse al entorno correcto', () => {
    const estado = env.Status
    expect(estado).toBe('test')
  })
  it('deberia retornar un array vacio al consultar', async () => {
    const models = [user, post]
    for (const model of models) {
      const records = await model.findMany()
      expect(Array.isArray(records)).toBe(true)
    }
  })
})
EOL
# Crear el archivo MiddHandler.test.js en test/Middlewares
cat > "$PROJECT_DIR/test/Middlewares/MiddHandler.test.js" <<EOL
import { describe, it, expect } from 'vitest'
import serverTest from './helpers/serverTest.js'

describe('Clase "MiddlewareHandler". Clase estatica de middlewares. Validacion y tipado de datos', () => {
  describe('Metodo "validateFields". Validacion y tipado datos en body (POST y PUT)', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const payload = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: []
      }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/create',
        payload
      })
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      const json = response.json()
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      // Se espera que el middleware haya validado y limpiado el payload
      expect(json.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: []
      })
    })
    it('deberia validar, tipar y arrorjar un error si faltara algun parametro.', async () => {
      const payload = { name: 'name', amount: '100', price: '55.44', arreglo: [] }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/create',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Missing parameters: enable')
    })
    it('deberia validar, tipar y arrorjar un error si no fuera posible tipar un parametro.', async () => {
      const payload = {
        name: 'name',
        amount: 'ppp',
        price: '55.44',
        enable: 'true',
        arreglo: []
      }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/create',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Invalid integer value')
    })
    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () => {
      const payload = {
        name: 'name',
        email: 'pepe@gmail.com',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: []
      }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/create',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      expect(json.data).toEqual({
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
      const payload = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [{ name: 'name', picture: 'string', enable: 'true', arreglo: [] }]
      }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/extra/create',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      expect(json.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: [],
        items: [{ name: 'name', picture: 'string', enable: true, arreglo: [] }]
      })
    })
    it('deberia validar, tipar y arrorjar un error si faltara algun parametro.', async () => {
      const payload = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [{ name: 'name', enable: 'true', arreglo: [] }]
      }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/extra/create',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Missing parameters in items[0]: picture')
    })
    it('deberia validar, tipar y arrorjar un error si no fuera posible tipar un parametro.', async () => {
      const payload = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [{ name: 'name', picture: 'string', enable: '445', arreglo: [] }]
      }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/extra/create',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Invalid boolean value')
    })
    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () => {
      const payload = {
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
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/body/extra/create',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      expect(json.data).toEqual({
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
      const response = await serverTest.inject({
        method: 'GET',
        url: '/test/param?page=2&size=2.5&fields=pepe&truthy=true'
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      expect(json.data).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })
    it('deberia llenar la query con valores por defecto si esta llegare vacía.', async () => {
      const response = await serverTest.inject({
        method: 'GET',
        url: '/test/param'
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      expect(json.data).toEqual({
        page: 1,
        size: 1,
        fields: '',
        truthy: false
      })
    })
    it('deberia arrojar un error si algun parametro incorrecto no se pudiere convertir.', async () => {
      const response = await serverTest.inject({
        method: 'GET',
        url: '/test/param?page=pepe&size=2.5'
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Invalid query parameter: Invalid integer value')
    })
    it('deberia eliminar los valores que excedan a los declarados.', async () => {
      const response = await serverTest.inject({
        method: 'GET',
        url: '/test/param?page=2&size=2.5&fields=pepe&truthy=true&demas=pepito'
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      expect(json.data).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })
  })
  describe('Metodo "validateRegex", validacion de campo especifico a traves de un regex.', () => {
    it('deberia permitir el paso si el parametro es correcto.', async () => {
      const payload = { email: 'emaildeprueba@ejemplo.com' }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/user',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
      expect(json).toHaveProperty('data')
      expect(json.data).toEqual({
        email: 'emaildeprueba@ejemplo.com'
      })
    })
    it('deberia arrojar un error si el parametro no es correcto.', async () => {
      const payload = { email: 'emaildeprueba@ejemplocom' }
      const response = await serverTest.inject({
        method: 'POST',
        url: '/test/user',
        payload
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Invalid email format! Introduzca un mail valido')
    })
  })
  describe('Metodo "middUuid", validacion de id en "param". Tipo de dato UUID v4', () => {
    it('deberia permitir el paso si el Id es uuid válido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76-191f905a2edd'
      const response = await serverTest.inject({
        method: 'GET',
        url: \`/test/param/\${id}\`
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
    })
    it('deberia arrojar un error si el Id no es uuid válido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await serverTest.inject({
        method: 'GET',
        url: \`/test/param/\${id}\`
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Invalid UUID')
    })
  })
  describe('Metodo "middIntId", validacion de id en "param". Tipo de dato INTEGER.', () => {
    it('deberia permitir el paso si el Id es numero entero válido', async () => {
      const id = 1
      const response = await serverTest.inject({
        method: 'GET',
        url: \`/test/param/int/\${id}\`
      })
      const json = response.json()
      expect(response.statusCode).toBe(200)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Passed middleware')
    })
    it('deberia arrojar un error si el Id no es numero entero válido.', async () => {
      const id = 'dkdi'
      const response = await serverTest.inject({
        method: 'GET',
        url: \`/test/param/int/\${id}\`
      })
      const json = response.json()
      expect(response.statusCode).toBe(400)
      expect(response.headers['content-type']).toMatch(/json/)
      expect(json).toHaveProperty('message', 'Invalid ID')
    })
  })
})
EOL
# Crear el archivo serverTest.js en test/Middlewares/helpers
cat > "$PROJECT_DIR/test/Middlewares/helpers/serverTest.js" <<EOL
import Fastify from 'fastify'
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

const serverTest = new Fastify({ logger: true })

serverTest.post(
  '/test/body/create',
  { preHandler: MiddlewareHandle.validateFields(firstItems) },
  (request, reply) => {
    reply.status(200).send({ message: 'Passed middleware', data: request.body })
  }
)

serverTest.post(
  '/test/body/extra/create',
  { preHandler: MiddlewareHandle.validateFieldsWithItems(firstItems, secondItem, 'items') },
  (request, reply) => {
    reply.status(200).send({ message: 'Passed middleware', data: request.body })
  }
)

serverTest.post(
  '/test/user',
  {
    preHandler: MiddlewareHandle.validateRegex(
      emailRegex,
      'email',
      'Introduzca un mail valido'
    )
  },
  (request, reply) => {
    reply.status(200).send({ message: 'Passed middleware', data: request.body })
  }
)

serverTest.get(
  '/test/param',
  { preHandler: MiddlewareHandle.validateQuery(queries) },
  (request, reply) => {
    reply.status(200).send({ message: 'Passed middleware', data: request.query })
  }
)

serverTest.get('/test/param/:id',
  { preHandler: MiddlewareHandle.middUuid },
  (request, reply) => {
    reply.status(200).send({ message: 'Passed middleware' })
  })

serverTest.get(
  '/test/param/int/:id',
  { preHandler: MiddlewareHandle.middIntId },
  (request, reply) => {
    reply.status(200).send({ message: 'Passed middleware' })
  }
)

// serverTest((err, request, reply) => {
//   const statusCode = err.statusCode || 500;
//   const message = err.message || err.stack;
//   reply.statusCode(statusCode).send(message);
// });

export default serverTest
EOL
# Crear el archivo repositories.test.js en test/Repositories
cat > "$PROJECT_DIR/test/Repositories/repositories.test.js" <<EOL
import { beforeAll, describe, expect, it } from 'vitest'
import { prisma, initializeDatabase, resetDatabase } from '../vitest.setup.js'
import repositories from '../../src/repositories/repositories.js'
import { createUsers, users } from './helpers/helperRepo.js'

const user = repositories(prisma.user)

describe('Test repositorios ', () => {
  // beforeAll(async () => {
  //   await initializeDatabase()
  //   await resetDatabase()
  // })
  describe('Creacion de elemento', () => {
    it('deberia crear un elemento 🧑‍💻', async () => {
      const data = { email: 'pepito@gmail.com', name: 'jose', nickname: 'pepito', password: '123456' }
      const response = await user.create(data)
      expect(response).toEqual({ id: 1, email: 'pepito@gmail.com', name: 'jose', nickname: 'pepito', biografy: null, password: '123456' })
    })
  })
  describe('Funciones Get', () => {
    describe('funcion GetAll', () => {
      it('deberia retornar una arreglo de elementos', async () => {
        const response = await user.getAll()
        expect(response).toEqual([{ id: 1, email: 'pepito@gmail.com', name: 'jose', nickname: 'pepito', biografy: null, password: '123456' }])
      })
    })
    describe('funcion getById', () => {
      it('deberia retornar un elemento', async () => {
        const id = 1
        const response = await user.getById(id)
        expect(response).toEqual({ id: 1, email: 'pepito@gmail.com', name: 'jose', nickname: 'pepito', biografy: null, password: '123456' })
      })
    })
    describe('funcion getOne', () => {
      it('deberia retornar un elemento por nombre', async () => {
        const field = 'email' // El field debe estar declarado como unico
        const value = 'pepito@gmail.com'
        const response = await user.getOne(field, value)
        expect(response).toEqual({ id: 1, email: 'pepito@gmail.com', name: 'jose', nickname: 'pepito', biografy: null, password: '123456' })
      })
    })
    describe('funcion getFilters', () => {
      it('deberia retornar un arreglo de elementos filtrados ', async () => {
        await createUsers(users, prisma.user)
        const query = { field: 'name', value: 'j' }
        const response = await user.getFilters(query)
        expect(response).toEqual([
          {
            id: 1,
            name: 'jose',
            email: 'pepito@gmail.com',
            nickname: 'pepito',
            biografy: null,
            password: '123456'
          },
          {
            id: 3,
            name: 'juan',
            email: 'juanchoo@gmail.com',
            nickname: 'juancho',
            biografy: null,
            password: '123456'
          }
        ])
      })
    })
  })
  describe('Funcion update', () => {
    it('deberia actualizar un elemento si recibe los datos correctos', async () => {
      const id = 1
      const newData = { name: 'perico' }
      const response = await user.update(id, newData)
      expect(response).toEqual({ id: 1, email: 'pepito@gmail.com', name: 'perico', nickname: 'pepito', biografy: null, password: '123456' })
    })
  })
  describe('Funcion delete', () => {
    it('deberia borrar un elemento si recibe un id', async () => {
      const id = 1
      const response = await user.delete(id)
      expect(response).toEqual({ id: 1, email: 'pepito@gmail.com', name: 'perico', nickname: 'pepito', biografy: null, password: '123456' })
    })
  })
})
EOL
# Crear el archivo helperRepo.js en test/Repositories/helpers
cat > "$PROJECT_DIR/test/Repositories/helpers/helperRepo.js" <<EOL
export const createUsers = async (data, model) => {
  await model.createMany({ data })
  return 'ok'
}

export const users = [
  { email: 'perico@gmail.com', name: 'pedro', nickname: 'perico', password: '123456' },
  { email: 'juanchoo@gmail.com', name: 'juan', nickname: 'juancho', password: '123456' },
  { email: 'nose@gmail.com', name: 'no se', nickname: 'nose', password: '123456' }
]
EOL
# Crear el archivo .env.development en la raiz del proyecto
cat > "$PROJECT_DIR/.env.development" <<EOL
PORT=4000
DATABASE_URL=
EOL
# Crear el archivo .env.test en la raiz del proyecto
cat > "$PROJECT_DIR/.env.test" <<EOL
PORT=8080
DATABASE_URL=
EOL
# Crear el archivo .env.production en la raiz del proyecto
cat > "$PROJECT_DIR/.env.production" <<EOL
PORT=3000
DATABASE_URL=
EOL
# Crear el archivo vitest.config.js en la raiz del proyecto
cat > "$PROJECT_DIR/vitest.config.js" <<EOL
import { defineConfig } from 'vitest/config'

export default defineConfig({
  setupFiles: ['./test/vitest.setup.js'], // Carga el setup antes de ejecutar los tests
  testTimeout: 10000 // Opcional: aumenta el timeout para pruebas asíncronas largas
})
EOL
# Crear el archivo package.json en la raiz del proyecto
cat > "$PROJECT_DIR/package.json" <<EOL
{
  "name": "$PROYECTO_PACKAGE",
  "version": "1.2.0",
  "main": "index.js",
  "type": "module",
  "directories": {
    "test": "test"
  },
  "scripts": {
    "start": "cross-env NODE_ENV=production node index.js",
    "dev": "cross-env NODE_ENV=development nodemon index.js",
    "lint": "standard",
    "lint:fix": "standard --fix",
    "unit:test": "cross-env NODE_ENV=test vitest",
    "test:ui": "cross-env NODE_ENV=test vitest --ui",
    "gen:schema": "node src/Swagger/schemas/tools/generateSchema.js"
  },
  "keywords": [
    "fastify",
    "functions",
    "prisma",
    "swagger"
  ],
  "author": "antorrg",
  "license": "ISC",
  "description": "",
  "dependencies": {
  
  },
  "devDependencies": {
   
  },
  "eslintConfig": {
    "extends": "./node_modules/standard/eslintrc.json"
  }
}
EOL

# Mensaje de confirmación
echo "Estructura de la aplicación Fastify creada en '$PROJECT_DIR'."

# Ir a la carpeta del PROJECT_DIR
cd $PROJECT_DIR

# Instalar dependencias
echo "Instalando dependencias:..."
npm install cross-env@latest dotenv@latest fastify@latest fastify-plugin jsonwebtoken @fastify/cors @fastify/multipart pino-pretty bcrypt @prisma/client@latest prisma@latest uuid@latest
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install vitest @fastify/swagger @fastify/swagger-ui nodemon @vitest/ui standard inquirer -D
  
echo "¡Tu aplicación Fastify está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."

