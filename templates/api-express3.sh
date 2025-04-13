#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

mkdir -p $PROJECT_DIR/src/{Configs,Middlewares,Controllers,Services,Repositories,Modules,Modules/users,Swagger,Swagger/schemas,Swagger/schemas/tools,Models}
mkdir -p $PROJECT_DIR/test/{helperTest,Middlewares,Middlewares/helpers,Repositories,Repositories/helpers,Services}

# Crear el archivo index.js en src
cat > "$PROJECT_DIR/index.js" <<EOL
import app from './src/app.js'
import env from './src/Configs/envConfig.js'
// import { sequelize } from './src/Configs/database.js'

app.listen(env.Port, async () => {
  try {
    //await sequelize.authenticate()
    console.log(\`Servidor corriendo en http://localhost:\${env.Port}\nServer in \${env.Status}\`)
    if (env.Status === 'development') {
      //await sequelize.sync({ force: false })
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
const { PORT, DATABASE_URL } = process.env


export default {
  Port: parseInt(PORT),
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
import {Sequelize} from 'sequelize'
import models from '../Models/index.js'
import env from './envConfig.js'

const sequelize = new Sequelize(env.DatabaseUrl,{
    logging: false,
    native: false,
  })
  
Object.values(models).forEach(model => model(sequelize))

const {
  User,
  Landing,
} = sequelize.models;
//Relations here:

export {
 User,
 Landing,
 sequelize
}
EOL
# Crear el modelo y el index
cat > "$PROJECT_DIR/src/Models/user.js" <<EOL
import { DataTypes } from "sequelize";

export default (sequelize)=>{
    sequelize.define('User', {
        id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, allowNull: false, primaryKey: true },
        email: { type: DataTypes.STRING, allowNull: false, unique: true},
        password: {type:DataTypes.STRING, allowNull: false},
        nickname:{type: DataTypes.STRING, allowNull: true},
        name: { type: DataTypes.STRING, allowNull: true },
        surname: { type: DataTypes.STRING, allowNull: true },
        picture: { type: DataTypes.STRING, allowNull: true},
        role:{type: DataTypes.SMALLINT, allowNull: false,defaultValue: 1,
          validate: {
            isIn: [[9, 1, 2, 3]], // Por ejemplo, 9: admin, 1: user, 2: moderator
          },
                },
        country: {
            type: DataTypes.STRING,
            allowNull: true
        },
        enable: {
            type: DataTypes.BOOLEAN,
            allowNull: true,
            defaultValue: true
        },
        deletedAt:{
          type: DataTypes.DATE,
          allowNull: true,
      },
    },{
        defaultScope : {
            where: {deletedAt : null}
        },  
        scopes: {
            enabledOnly: {
                where: {
                    enable: true
                }
            },
            allRecords: {} // No aplica ningún filtro
        },
        timestamps: true,
       
    })
}
EOL
# Crear el modelo landing (solo para tests)
cat > "$PROJECT_DIR/src/Models/landing.js" <<EOL
import { DataTypes } from 'sequelize'

export default (sequelize) => {
  sequelize.define('Landing', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING,
      allownull: false
    },
    title: {
      type: DataTypes.STRING,
      allowNull: true
    },
  
    picture: {
      type: DataTypes.STRING, // URL del logo de la marca
      allowNull: true
    },
    enable: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    },
    deletedAt: {
      type: DataTypes.DATE,
      allowNull: true
    }
  },
  {

    defaultScope: {
      where: {
        deletedAt: null
      }
    },
    scopes: {
      enabledOnly: {
        where: {
          enable: true
        }
      },
      allRecords: {
        // No aplica ningún filtro
      }
    },
    paranoid: true,
    timestamps: true
  }
  )
}
EOL
# Crear el index
cat > "$PROJECT_DIR/src/Models/index.js" <<EOL
import User from './user.js'
import Landing from './landing.js'

export default {
User,
Landing,
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
      const existingRecord = await this.Model.findOne({ where: whereClause })

      if (existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} \${uniqueField || 'entry'} already exists\`, 400)
      }
      const newRecord = await this.Model.create( data )

      return newRecord
    } catch (error) {
      throw error
    }
  }

  async getAll(searchField = '', search = null, order, sortBy, page = 1, limit = 10, isAdmin = false) {
    const offset = (page - 1) * limit;
  
    // Construimos el filtro de búsqueda
    let whereClause = {};
    if (search && searchField) {
      whereClause[searchField] = {
        [Op.iLike]: \`%\${search}%\`
      };
    }
  
    // Construimos el ordenamiento
    const orderClause = [];
    if (sortBy && order) {
      orderClause.push([sortBy, order.toUpperCase()]);
    }
  
    const { rows: resModel, count: totalCount } = await this.Model
      .scope(isAdmin ? 'allRecords' : 'enabledOnly')
      .findAndCountAll({
        limit,
        offset,
        where: whereClause,
        order: orderClause,
        distinct: true,
      });
  
    if (resModel.length === 0) {
      if (this.dataEmpty) {
        resModel.push(this.dataEmpty);
      } else {
        throwError(\`This \${this.Model.name.toLowerCase()} \${searchField || 'entry'} does not exist\`, 404);
      }
    }
  
    return {
      info: {
        total: totalCount,
        page,
        totalPages: Math.ceil(totalCount / limit)
      },
      data: resModel
    };
  }
  

  async getOne (data, uniqueField, isAdmin=false) {
    try {
      const whereClause = {}
      if (uniqueField) {
        whereClause[uniqueField] = data
      }
      const existingRecord = await this.Model.scope(isAdmin ? 'allRecords' : 'enabledOnly').findOne({ where: whereClause })
      if (!existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} name do not exists\`, 404)
      }
      return existingRecord
    } catch (error) {
      throw error
    }
  };

  async getById (id, isAdmin=false) {
    try {
      const existingRecord = await this.Model.scope(isAdmin ? 'allRecords' : 'enabledOnly').findByPk(id)
      if (!existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} name do not exists\`, 404)
      }
      return existingRecord
    } catch (error) {
      throw error
    }
  };

  async update (id, data) {
    const dataFound = await this.Model.findByPk(id)
    if (!dataFound) {
      throwError(\`\${this.Model.name} not found\`, 404)
    }
    const upData = await dataFound.update(data)
    return upData
  };

  async delete (id) {
    const dataFound = await this.Model.findByPk(id)
    if (!dataFound) {
      throwError(\`\${this.Model} not found\`, 404)
    }
    await dataFound.destroy(id)
    return \`\${this.Model.name} deleted successfully\`
  };
}

export default BaseRepository
EOL
# Crear el Servicio 
cat > "$PROJECT_DIR/src/Services/GeneralService.js" <<EOL
import eh from '../Configs/errorHandlers.js'
const throwError = eh.throwError


class GeneralService {
  constructor (Repository, fieldName,  parserFunction = null, useImage = false, deleteImages = null) {
    this.Repository = Repository
    this.fieldName = fieldName
    this.useImage = useImage
    this.deleteImages = deleteImages
    this.parserFunction = parserFunction
  }

  // clearCache () {
  //   cache.del(\`\${this.Repository.name.toLowerCase()}\`)
  // }

  async handleImageDeletion (imageUrl) {
    if (this.useImage && imageUrl) {
      await this.deleteImages(imageUrl)
    }
  }

  async create (data, uniqueField = null) {
    try {
      const newRecord = await this.Repository.create(data, uniqueField)

      //if (this.useCache) this.clearCache()
      return newRecord
    } catch (error) {
      throw error
    }
  }

  //searchField = '', search = null, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10

  async getAll (queryObject, isAdmin = false,) {
  
    const response = await this.Repository.getAll(queryObject)
    const dataParsed = isAdmin ? response.data : response.data.map(dat => this.parserFunction(dat))
    return {
     info: response.info,
    data: dataParsed,
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

    /*if (this.useCache) this.clearCache()*/
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

     /* if (this.useCache) this.clearCache()*/
      return { message: \`\${this.fieldName} deleted successfully\`, data: null}
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
import {sequelize} from '../src/Configs/database.js'

// Esta función inicializa la base de datos
async function initializeDatabase() {
  try {
    await sequelize.authenticate();
    await sequelize.sync({ force: true }); // Esto limpia y sincroniza la base de datos
    //console.log('Base de datos sincronizada exitosamente ✔️')
  } catch (error) {
    console.error('Error sincronizando DB ❌ ',error)
  }
}

//Esta función resetea la base de datos antes de cada prueba si es necesario
export async function resetDatabase() {
    await sequelize.sync({ force: true });
}

beforeAll(async () => {
  await initializeDatabase();
});

// beforeEach(async () => {
//   await resetDatabase();
// });

afterAll(async () => {
    await resetDatabase();
    await sequelize.close();
    //console.log('DB cerrada')
    await sequelize.close().catch((err) => {
      console.error('Error closing sequelize:', err);
    });
  
});
EOL
# Crear archivo de test de entorno y db
cat > "$PROJECT_DIR/test/EnvDb.test.js" <<EOL
import env from '../src/Configs/envConfig.js'
import {User, Landing, sequelize} from '../src/Configs/database.js'

describe('Iniciando tests, probando variables de entorno del archivo "envConfig.js" y existencia de tablas en DB.', () => {
  afterAll(() => {
    console.log('Finalizando todas las pruebas...')
  })

  it('Deberia retornar el estado y la variable de base de datos correcta', () => {
    const formatEnvInfo = \`Servidor corriendo en: \${env.Status}\n\` +
                   \`Base de datos de testing: \${env.DatabaseUrl}\`
    expect(formatEnvInfo).toBe('Servidor corriendo en: test\n' +
        'Base de datos de testing: postgres://postgres:antonio@localhost:5432/testing')
  })
  it('Debería hacer una consulta básica en cada tabla sin errores', async () => {
    const models = [
     User,
     Landing
    ]
    for (const model of models) {
      const records = await model.findAll()
      expect(Array.isArray(records)).toBe(true)
      expect(records.length).toBe(0)
    }
  })
  it('Debería verificar la existencia de tablas en la base de datos', async () => {
    const result = await sequelize.query(\`
            SELECT tablename 
            FROM pg_catalog.pg_tables 
            WHERE schemaname = 'public';
        \`, { type: sequelize.QueryTypes.SELECT })

    const tableNames = result.map(row => row.tablename)

    const expectedTables = [
      'Users','Landings' //A modo de ejemplo
    ]

    expectedTables.forEach(table => {
      expect(tableNames).toContain(table)
    })
  })
})
describe('Probando la estructura de las tablas en la base de datos', () => {
  const tables = {
    //Estas tablas están a modo de ejemplo
    Users: ['id', 'email', 'password', 'nickname', 'name', 'surname', 'picture', 'role', 'country', 'createdAt', 'updatedAt'],
    Landings: ['id', 'name', 'title', 'picture', 'enable', 'deletedAt']
  }

  Object.entries(tables).forEach(([tableName, expectedColumns]) => {
    it(\`\${tableName} debería tener las columnas correctas\`, async () => {
      const result = await sequelize.query(\`
                SELECT column_name FROM information_schema.columns 
                WHERE table_name = '\${tableName}'
            \`, { type: sequelize.QueryTypes.SELECT })

      const columns = result.map(row => row.column_name)

      expectedColumns.forEach(col => {
        expect(columns).toContain(col)
      })
    })
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

serverTest.get(
  '/test/param/:id', 
  MiddlewareHandle.middUuid('id'), 
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
# Crear archivo de test para Repositories
cat > "$PROJECT_DIR/test/Repositories/RepBase.test.js" <<EOL
import BaseRepository from '../../src/Repositories/BaseRepository.js'
import {Landing, User} from '../../src/Configs/database.js'
import * as info from './helpers/baseRep.js'

class TestClass extends BaseRepository {
  constructor (Model, dataEmpty) {
    super(Model, dataEmpty)
  }
}
const tests = new TestClass(Landing) //Se necesita tener al menos una tabla declarada en la DB
const failed = new TestClass(User, info.dataEmpty) //Debe ser una tabla diferente 

describe('BaseRepository tests (abstract class)', () => {
  describe('Test de extension e instancias', () => {
    it('Deberia arrojar un error al intentar instanciar la clase BaseRepository.', () => {
      expect(() => new BaseRepository(Landing)).toThrow(Error)
      expect(() => new BaseRepository(Landing)).toThrow('No se puede instanciar una clase abstracta.')
    })
    it('debería heredar e instanciar correctamente la clase sin lanzar error', () => {
      const instance = new TestClass(Landing)
      // Verifica que la instancia sea de TestClass y de BaseRepository
      expect(instance).toBeInstanceOf(TestClass)
      expect(instance).toBeInstanceOf(BaseRepository)
      // Verifica que la propiedad Model se asignó correctamente
      expect(instance.Model).toBe(Landing)
    })
  })
  describe('Tests unitarios. Metodos de BaseRepository', () => {
    describe('Metodo create.', () => {
      it('Deberia crear un elemento con los parametros correctos.', async () => {
        const element = info.createData
        const uniqueField = 'name'
        const response = await tests.create(element, uniqueField)
        const responseCleaned = info.cleanData(response)
        expect(responseCleaned).toEqual(info.responseData)
      })
      it('Deberia arrojar un error al intentar crear el mismo elemento dos veces (mismo nombre).', async () => {
        const element = info.createData
        const uniqueField = 'name'
        try {
          await tests.create(element, uniqueField)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.message).toBe('This landing name already exists')
          expect(error.status).toBe(400)
        }
      })
    })
    describe('Metodos GET, retornando un arreglo de elementos o un elemento.', () => {
      it('Metodo "getAll": deberia retornar un arreglo de elementos.', async () => {
        //, { search, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10 }
        const response = await tests.getAll('name')
       // console.log('A ver el get', response)
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
          expect(error.message).toBe('This landing name do not exists')
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
        const newData = {name: 'landing3', enable: true }
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
cat > "$PROJECT_DIR/test/Repositories/helpers/baseRep.js" <<EOL
export const createData = {
  name: 'landing1',
  title: 'Titulo de la landing',
  picture: 'https://metalogo.com.ar'
}
export const createSecondData = {
  name: 'landing2',
  title: 'Titulo de la landing',
  picture: 'https://picture.com.ar'
}

export const cleanData = (data) => {
  return {
    id: data.id,
    name: data.name,
    title: data.title,
    picture: data.picture,
    enable: data.enable
  }
}
export const responseData = {
  id: 1,
  name: 'landing1',
  title: 'Titulo de la landing',
  picture: 'https://metalogo.com.ar',
  enable: true
}
export const responseData2 = [{
  id: 1,
  name: 'landing1',
  title: 'Titulo de la landing',
  picture: 'https://metalogo.com.ar',
  enable: true
},
{
  id: 2,
  name: 'landing2',
  title: 'Titulo de la landing',
  picture: 'https://metalogo.com.ar',
  enable: false
}]
export const responseData3 = {
  id: 2,
  name: 'landing2',
  title: 'Titulo de la landing',
  picture: 'https://metalogo.com.ar',
  enable: false
}
export const responseDataImg = {
  id: 1,
  name: 'landing1',
  title: 'Titulo de la landing',
  picture: 'https://imagen.com.ar',
  enable: true
}
export const responseUpdData = {
  id: 1,
  name: 'landing3',
  title: 'Titulo de la landing',
  picture: 'https://metalogo.com.ar',
  enable: true
}
export const dataEmpty = {
  id: false,
  name: 'landing1',
  title: 'Titulo de la landing',
  picture: 'https://metalogo.com.ar',
  enable: true
}
EOL
# Crear archivo de serverMock para services
cat > "$PROJECT_DIR/test/Services/ServGeneral.test.js" <<EOL
import BaseRepository from '../../src/Repositories/BaseRepository.js'
import GeneralService from '../../src/Services/GeneralService.js'
import { Landing } from '../../src/Configs/database.js'
import * as info from '../Repositories/helpers/baseRep.js'
import * as fns from '../helperTest/generalFunctions.js'

class TestClass extends BaseRepository {
  constructor (Model) {
    super(Model)
  }
}
const testing = new TestClass(Landing)

// repository, fieldName(string), cache(boolean), parserFunction(function), useImage(boolean), deleteImages(function)
const serv = new GeneralService(testing, 'Landing', null, true, fns.deletFunctionFalse)
const servCache = new GeneralService(testing, 'Landing', info.cleanData, false, fns.deletFunctionTrue)
const servParse = new GeneralService(testing, 'Landing', info.cleanData, true, fns.deletFunctionTrue)

describe('Test unitarios de la clase GeneralService: CRUD.', () => {
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
  describe('Metodos "GET". Retornar servicios o un servicio.', () => {
    it('Metodo "getAll": deberia retornar un arreglo con los servicios', async () => {
      const response = await servParse.getAll()
      //console.log('A ver el get', response)
      expect(response.data).toEqual([info.responseData])
      
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
      const element = info.createSecondData
      await serv.create(element, 'name')
      const id = 1
      const response = await servParse.delete(id)
      expect(response.message).toBe('Landing deleted successfully')
    })
    it('deberia arrojar un error si falla la eliminacion de imagenes', async () => {
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
  setupFilesAfterEnv: ['./test/jest.setup.js']
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
cat > "$PROJECT_DIR/.env.example" <<EOL
PORT=8080
DATABASE_URL=postgres://dbuser:dbpassword@localhost:5432/dbname
EOL
# Crear README.md
cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express

Base para el proyecto $PROYECTO_VALIDO de Express.js con entornos de ejecución y manejo de errores.

## Sobre la API:

Esta API fue construida de manera híbrida. Es decir, la parte de Repositories, Services y Controllers está desarrollada bajo el paradigma OOP (Programación Orientada a Objetos). Sin embargo, los routers y la aplicación en sí no lo están. Los middlewares, si bien forman parte de una clase, esta es una clase de métodos estáticos. De esta forma, se aprovecha la escalabilidad y el orden de la POO, pero al mismo tiempo se minimiza el consumo de recursos utilizando funciones puras siempre que sea posible (las clases en JavaScript tienen un costo, aunque no muy elevado).

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

La aplicación puede ejecutarse con \`npm run dev\` (modo desarrollo) o \`npm start\` (producción). Los tests pueden ejecutarse solo una vez que se hayan definido los modelos y conectado la base de datos.

Se requieren dos bases de datos: una para desarrollo y otra para test. Una vez configurado todo, debe descomentar la línea correspondiente en \`jest.config.js\` y en el archivo \`jest.setup.js\` dentro de la carpeta \`test\`. Luego, ajuste los tests según su caso de uso.

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
npm install cross-env@latest cors@latest dotenv@latest express@latest helmet@latest morgan@latest sequelize sequelize-cli uuid@latest pg pg-hstore
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install @babel/core @babel/preset-env babel-jest nodemon@latest standard@latest supertest@latest jest@latest swagger-jsdoc swagger-ui-express inquirer -D
  
echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."
