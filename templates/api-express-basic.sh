#!/bin/bash

# Verificar si se pasó un nombre de PROJECT_DIR
#if [ -z "$1" ]; then
#  echo "Error: No se especificó el directorio de destino"
#  exit 1
#fi

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"   #"$1"

# Crear la estructura del proyecto
mkdir -p "$PROJECT_DIR"

# Crear la estructura de carpetas
mkdir -p $PROJECT_DIR/src/{Configs,Middlewares,Controllers,Services,Modules,Modules/users}

# Crear el archivo index.js en src
cat > "$PROJECT_DIR/index.js" <<EOL
import app from './src/app.js'
import env from './src/Configs/envConfig.js'

app.listen(env.Port, () => {
  console.log(\`Servidor corriendo en http://localhost:\${env.Port}\nServer in \${env.Status}\`)
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

const app = express()
app.use(morgan('dev'))
app.use(cors())
app.use(helmet())
app.use(express.json())
app.use(eh.validJson)

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

const envFile = configEnv[process.env.NODE_ENV] || '.env.production'
dotenv.config({ path: envFile })

const { PORT, NODE_ENV } = process.env
const Status = NODE_ENV

export default {
  Port: parseInt(PORT) || 3000,
  Status
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
# Crear el Servicio 
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
    "test": "cross-env NODE_ENV=test echo \"Error: no test specified\" && exit 1",
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

Esta api fue construida de manera hibrida, es decir: la parte de Repositories, Services y Controllers está construida bajo el paradigma OOP (o POO en español, Programacion Orientada a Objetos), sin embargo los routers y la aplicacion en si misma no lo está, los Middlewares sin bien forman parte de una clase, esta es una clase de metodos estaticos, de manera que aproveche la escalabilidad y orden de la POO pero al mismo tiempo minimize el consumo de recursos utilizando funciones puras en todo lugar en el que se pueda (las clases en javascript tienen siempre un costo, no muy elevado pero costo al fin), de manera que en esta plantilla va a encontar los dos paradigmas funcionando codo a codo, usted puede a partir de aqui darle la forma que desee. Si bien está construida de una manera muy básica, esta funciona, por lo que al revisar el codigo podrá ver (si desea mantener este sistema de trabajo) como seguir ya sea con un ORM, ODM, etc. ¡Buena suerte y buen codigo!

## Cómo comenzar:

En la aplicacion hay un servicio hecho a modo de ejemplo para mostrar la funcionalidad de la api, en la carpeta Services se encuentra un archivo \`users.js\` que contiene un arreglo con un grupo de usuarios, estos junto con los controladores y servicios son llamados y utilizados en el archivo \`mainUser.js\` que se encuentra dentro del directorio Modules en la carpeta users, aqui tambien se declaran los tipos de datos que van a ingresar, y por medio del archivo \`user.routes.js\` la funcion userRouter conecta todo esto con la app en mainRouter (\`routes.js\`). La aplicacion se puede ejecutar tanto con el comando \`npm run dev\` (en desarrollo) o \`npm start\` (produccion). Los test aun no se encuentran configurados. 

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
npm install cross-env@latest cors@latest dotenv@latest express helmet@latest morgan@latest uuid@latest
echo "Instalando dependencias de desarrollo, aguarde un momento..."
npm install @babel/core @babel/preset-env babel-jest nodemon@latest standard@latest supertest@latest jest@latest -D
  

echo "¡Tu aplicación Express está lista! 🚀"
echo "Ejecuta 'cd $PROJECT_DIR && npm start o npm run dev' para iniciar el servidor."