#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
mkdir -p $PROJECT_DIR/src/Shared/Middlewares/helpers
mkdir -p $PROJECT_DIR/src/Shared/Middlewares/sanitize
mkdir -p $PROJECT_DIR/src/Shared/Middlewares/helpers/createSchema
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddlewareHandler.js" <<EOL
import { validate as uuidValidate } from 'uuid'
import { AuxValid } from './helpers/auxValid.js'
import {ValidateSchema} from './helpers/ValidateSchema.js'


export default class MiddlewareHandler {

  static validateFields = (schema) => ValidateSchema.validate(schema)

  // MiddlewareHandler.validateQuery([{name: 'authorId', type: 'int', required: true}]),
 static validateQuery (requiredFields = []) {
    return (req, res, next) => {
      try {
        const validatedQuery = {}
        requiredFields.forEach(({ name, type, default: defaultValue }) => {
          let value = req.query[name]

          if (value === undefined) {
            value = defaultValue !== undefined ? defaultValue : AuxValid.getDefaultValue(type)
          } else {
            value = AuxValid.validateValue(value, type, name)
          }

          validatedQuery[name] = value
        })
        //req.validatedQuery = validatedQuery // Nuevo objeto tipado en lugar de modificar req.query
        req.context = req.context || {}
        req.context.query = validatedQuery
        next()
      } catch (error) {
        return next(AuxValid.middError(error.message, 400))
      }
    }
  }

  static validateRegex (validRegex, nameOfField, message = null) {
    return (req, res, next) => {
      if (!validRegex || !nameOfField || nameOfField.trim() === '') {
        return next(AuxValid.middError('Missing parameters in function!', 400))
      }
      const field = req.body[nameOfField]
      const personalizedMessage = message ? ' ' + message : ''
      if (!field || typeof field !== 'string' || field.trim() === '') {
        return next(AuxValid.middError(\`Missing \${nameOfField}\`, 400))
      }
      if (!validRegex.test(field)) {
        return next(AuxValid.middError(\`Invalid \${nameOfField} format!\${personalizedMessage}\`, 400))
      }
      next()
    }
  }

  static paramId (fieldName, validator) {
    return (req, res, next) => {
      const id = req.params[fieldName]
      if (!id) {
        next(AuxValid.middError('Falta el id', 400)); return
      }
      const isValid = typeof validator === 'function' ? validator(id) : validator.test(id)
      if (!isValid) {
        next(AuxValid.middError('Parametros no permitidos', 400)); return
      }
      next()
    }
  }

  static logRequestBody (req, res, next) {
    if (process.env.NODE_ENV !== 'test') {
      next(); return
    }
    const timestamp = new Date().toISOString()
    console.log(\`[\${timestamp}] Request Body:\`, req.body)
    next()
  }

  static ValidReg = {
    EMAIL: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    PASSWORD: /^(?=.*[A-Z]).{8,}$/,
    UUIDv4: /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    INT: /^\d+$/, // Solo enteros positivos
    OBJECT_ID: /^[0-9a-fA-F]{24}$/, // ObjectId de MongoDB
    FIREBASE_ID: /^[A-Za-z0-9_-]{20}$/, // Firebase push ID
    UUIDFn: uuidValidate
  }
}

EOL
cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/auxValid.js" <<EOL
export class AuxValid {
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
        return AuxValid.validateBoolean(value)
      case 'int':
        return AuxValid.validateInt(value)
      case 'float':
        return AuxValid.validateFloat(value)
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
}
EOL
cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/ValidateSchema.js" <<EOL
import { AuxValid } from './auxValid.js'


export class ValidateSchema {
  static validate(schema) {
    return (req, res, next) => {
      try {
        const validated = ValidateSchema.#validateStructure(req.body, schema)
        req.body = validated
        next()
      } catch (err) {
        return next(AuxValid.middError(err.message, 400))
      }
    }
  }

  static #validateStructure(data, schema, path = '') {
    if (typeof schema === 'string' || (typeof schema === 'object' && schema.type)) {
      return ValidateSchema.#validateField(data, schema, path)
    }

    if (Array.isArray(schema)) {
      if (!Array.isArray(data)) {
        throw new Error(\`Expected array at \${path || 'root'}\`)
      }
      return data.map((item, i) =>
        ValidateSchema.#validateStructure(item, schema[0], \`\${path}[\${i}]\`)
      )
    }

    if (typeof schema === 'object') {
      if (typeof data !== 'object' || data === null || Array.isArray(data)) {
        throw new Error(\`Expected object at \${path || 'root'}\`)
      }

      const result = {}
      for (const key in schema) {
        const fieldSchema = schema[key]
        const fullPath = path ? \`\${path}.\${key}\` : key
        const value = data[key]

        if (!(key in data)) {
          if (fieldSchema.optional) {
            continue // omitido si es opcional
          } else if ('default' in fieldSchema) {
            result[key] = fieldSchema.default
            continue
          } else {
            throw new Error(\`Missing field: \${key} at \${fullPath}\`)
          }
        }

        result[key] = ValidateSchema.#validateStructure(value, fieldSchema, fullPath)
      }
      return result
    }

    throw new Error(\`Invalid schema at \${path || 'root'}\`)
  }

  static #validateField(value, fieldSchema, path) {
    const type = typeof fieldSchema === 'string' ? fieldSchema : fieldSchema.type

    // Si está ausente y hay valor por defecto
    if (value === undefined || value === null) {
      if (typeof fieldSchema === 'object' && 'default' in fieldSchema) {
        return fieldSchema.default
      }
      throw new Error(\`Missing required field at \${path}\`)
    }

    // Validación real
    return AuxValid.validateValue(value, type, path)
  }
}
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#Crear test para MiddlewareHandler
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddHandler.test.js" <<EOL
import session from 'supertest'
import serverTest from './testHelpers/serverTest.help.js'
const agent = session(serverTest)

describe('Clase "MiddlewareHandler". Clase estatica de middlewares. Validacion y tipado de datos', () => {
  describe('Metodo "ValidateFields". Validacion y tipado datos en body (POST y PUT) Objeto simple', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        active: 'true',
        metadata: 'metadata',
    }

      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
         name: 'name',
         active: true,
        metadata: 'metadata',
        price: 2.0
      })
    })
    it('deberia validar, tipar y arrojar un error si faltara algun parametro.', async () => {
      const data = { 
        active: 'true',
        metadata: 'metadata',
       price: 2.0}
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing field: name at name')
    })
    it('deberia validar, tipar y arrojar un error si no fuera posible tipar un parametro.', async () => {
      const data = {
        name:'name',
       active: 'true',
        metadata: 'metadata',
       price: 'true'
      }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid float value')
    })
    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () => {
     const data = {
        name: 'name',
        active: 'true',
        metadata: 'metadata',
        enable:true,
        price: 2.0
    }
      
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
         name: 'name',
         active: true,
         metadata: 'metadata',
         price: 2.0
      })
    })
  })
  describe('Metodo "ValidateFields". Validacion y tipado datos en body (POST y PUT) Objeto anidado', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        active: 'true',
        profile: {
            age: '25',
            rating: 3.25
        },
        tags:['publico', 'privado'],
        metadata: 'metadata',
    }

      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
      name: 'name',
        active: true,
        profile: {
            age: 25,
            rating: 3.25
        },
        tags:['publico', 'privado'],
        metadata: 'metadata',
      })
    })
    it('deberia validar, tipar y arrojar un error si faltara algun parametro.', async () => {
      const data = { 
        active: 'true',
        profile: {
            age: 25,
            rating: 3.25
        },
        tags:['publico', 'privado'],
        metadata: 'metadata',
    }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing field: name at name')
    })
    it('deberia validar, tipar y arrojar un error si no fuera posible tipar un parametro.', async () => {
      const data = {
      name: 'name',
        active: 'true',
        profile: {
            age: 25,
            rating: 'cooole'
        },
        tags:['publico', 'privado'],
        metadata: 'metadata',
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid float value')
    })
    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () =>{     const data = {
        name: 'name',
        active: 'true',
        profile: {
            age: '25',
            rating: 3.25
        },
        tags:['publico', 'privado'],
        metadata: 'metadata',
        enable: true,
    }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
      name: 'name',
        active: true,
        profile: {
            age: 25,
            rating: 3.25
        },
        tags:['publico', 'privado'],
        metadata: 'metadata',
      })
    })
  })
  describe('Metodo "ValidateFields". Validacion y tipado datos en body (POST y PUT) Objeto doblemente anidado', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        active: 'true',
        profile: [{
            age: '25',
            rating: 3.25
        },{
            age: '33',
            rating: 4.0
        }],
        tags:['publico', 'privado'],
        metadata: 'metadata',
    }

      const response = await agent
        .post('/test/body/three/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
           name: 'name',
        active: true,
        profile: [{
            age: 25,
            rating: 3.25
        },{
            age: 33,
            rating: 4.0
        }],
        tags:['publico', 'privado'],
        metadata: 'metadata',
      })
    })
    it('deberia validar, tipar y arrojar un error si faltara algun parametro.', async () => {
      const data = { 
        active: 'true',
        metadata: 'metadata',
       price: 2.0}
      const response = await agent
        .post('/test/body/three/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing field: name at name')
    })
    it('deberia validar, tipar y arrojar un error si no fuera posible tipar un parametro.', async () => {
         const data = {
        name: 'name',
        active: 'true',
        profile: [{
            age: '25',
            rating: 3.25
        },{
            age: 'psps99dl',
            rating: 4.0
        }],
        tags:['publico', 'privado'],
        metadata: 'metadata',
    }
      const response = await agent
        .post('/test/body/three/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid integer value')
    })
    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () => {
     const data = {
        name: 'name',
        active: 'true',
        profile: [{
            age: '25',
            rating: 3.25
        },{
            age: '33',
            rating: 4.0
        }],
        tags:['publico', 'privado'],
        metadata: 'metadata',
        enable: true,
        deletedAt: null
    }
      
      const response = await agent
        .post('/test/body/three/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        name: 'name',
        active: true,
        profile: [{
            age: 25,
            rating: 3.25
        },{
            age: 33,
            rating: 4.0
        }],
        tags:['publico', 'privado'],
        metadata: 'metadata',
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
  describe('Metodo "paramId", validacion de id en "param". Tipo de dato UUID v4', () => {
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
  describe('Metodo "paramId", validacion de id en "param". Tipo de dato INTEGER.', () => {
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
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#Crear helperTest para MiddlewareHandler

cat > "$PROJECT_DIR/src/Shared/Middlewares/testHelpers/serverTest.help.js" <<EOL
import express from 'express'
import MiddlewareHandle from '../MiddlewareHandler.js'

const singleSchema = {  
  name: { type: 'string' },
  active: { type: 'boolean', default: false },
  metadata: { type: 'string', optional: true },
  price: {type: 'float', default : 2.0}
}

const doubleSchema = {
  name: { type: 'string' },
  active: { type: 'boolean', default: false },
  profile: {
    age: { type: 'int' },
    rating: { type: 'float', default: 0.0 }
  },
  tags: [{ type: 'string' }],
  metadata: { type: 'string', optional: true }
}
const threeSchema = {
  name: { type: 'string' },
  active: { type: 'boolean', default: false },
  profile: [{
    age: { type: 'int' },
    rating: { type: 'float', default: 0.0 }
  },],
  tags: [{ type: 'string' }],
  metadata: { type: 'string', optional: true }
}

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
  MiddlewareHandle.validateFields(singleSchema),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
)

serverTest.post(
  '/test/body/extra/create',
  MiddlewareHandle.validateFields(doubleSchema),
  (req, res) => {
    res.status(200).json({ message: 'Passed middleware', data: req.body })
  }
)
serverTest.post(
  '/test/body/three/create',
  MiddlewareHandle.validateFields(threeSchema),
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
    res.status(200).json({ message: 'Passed middleware', data: req.query, validData: req.context.query})
  }
)

serverTest.get(
  '/test/param/:id', 
  MiddlewareHandle.paramId('id', MiddlewareHandle.ValidReg.UUIDv4), 
  (req, res) => {
  res.status(200).json({ message: 'Passed middleware' })
})

serverTest.get(
  '/test/param/int/:id',
  MiddlewareHandle.paramId('id', MiddlewareHandle.ValidReg.INT),
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

cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/createSchema/generate.js" <<EOL
import inquirer from "inquirer";

export default async function promptForField(){
  const field = {}

  const { name } = await inquirer.prompt({
    type: 'input',
    name: 'name',
    message: 'Nombre del campo:'
  })

  const { kind } = await inquirer.prompt({
    type: 'list',
    name: 'kind',
    message: \`Tipo de campo "\${name}":\`,
    choices: ['string', 'int', 'float', 'boolean', 'object', 'array']
  })

  if (['string', 'int', 'float', 'boolean'].includes(kind)) {
    const fieldConfig = { type: kind }

    const { isOptional } = await inquirer.prompt({
      type: 'confirm',
      name: 'isOptional',
      message: '¿Es opcional?',
      default: false
    })

    const { hasDefault } = await inquirer.prompt({
      type: 'confirm',
      name: 'hasDefault',
      message: '¿Querés establecer un valor por defecto?',
      default: false
    })

    if (hasDefault) {
      const { defaultValue } = await inquirer.prompt({
        type: 'input',
        name: 'defaultValue',
        message: 'Valor por defecto:',
        validate: input => input.length > 0
      })

      // parsear según tipo
      fieldConfig.default =
        kind === 'int' ? parseInt(defaultValue) :
        kind === 'float' ? parseFloat(defaultValue) :
        kind === 'boolean' ? defaultValue === 'true' :
        defaultValue
    }

    if (isOptional) {
      fieldConfig.optional = true
    }

    field[name] = fieldConfig
    return field
  }

  if (kind === 'object') {
    const subfields = {}
    let addMore = true
    while (addMore) {
      const child = await promptForField()
      Object.assign(subfields, child)
      const { cont } = await inquirer.prompt({
        type: 'confirm',
        name: 'cont',
        message: '¿Agregar otro campo dentro del objeto?',
        default: true
      })
      addMore = cont
    }
    field[name] = subfields
    return field
  }

  if (kind === 'array') {
    const { itemType } = await inquirer.prompt({
      type: 'list',
      name: 'itemType',
      message: '¿Tipo de elementos del array?',
      choices: ['string', 'int', 'float', 'boolean', 'object']
    })

    if (itemType === 'object') {
      const subfields = {}
      let addMore = true
      while (addMore) {
        const child = await promptForField()
        Object.assign(subfields, child)
        const { cont } = await inquirer.prompt({
          type: 'confirm',
          name: 'cont',
          message: '¿Agregar otro campo al objeto dentro del array?',
          default: true
        })
        addMore = cont
      }
      field[name] = [subfields]
    } else {
      field[name] = [{ type: itemType }]
    }
    return field
  }
}
EOL
cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/createSchema/index.js" <<EOL
import promptForField from './generate.js'
import fs from 'fs/promises'
import inquirer from 'inquirer'
import path from 'path'


const buildSchema = async () => {
  const { pathName } = await inquirer.prompt({
    type: 'input',
    name: 'pathName',
    message: 'Donde quiere guardar el archivo?: (ej: src/Schemas)'
  })

  const { componentName } = await inquirer.prompt({
    type: 'input',
    name: 'componentName',
    message: 'Nombre del archivo:'
  })
  const schema = {}
  let more = true

  while (more) {
    const field = await promptForField()
    Object.assign(schema, field)
    const { cont } = await inquirer.prompt({
      type: 'confirm',
      name: 'cont',
      message: '¿Agregar otro campo al esquema?',
      default: true
    })
    more = cont
  }

  console.log('🧪 Esquema generado:')
  const outDirJs = path.resolve(process.cwd(), pathName)//'server/Schemas'
    const filePath = path.join(outDirJs, \`\${componentName.toLowerCase()}.js\`)
  const jsContent = \`export default \${toJsObjectString(schema)};\n\`
   await fs.writeFile(filePath, jsContent)
   console.log(\`\n📁 Archivo validador guardado en: \${filePath}\`)
  console.dir(schema, { depth: null, colors:true })
}

buildSchema()


function toJsObjectString(obj, indent = 2) {
  const space = ' '.repeat(indent)

  if (Array.isArray(obj)) {
    const items = obj.map(item => toJsObjectString(item, indent + 2)).join(',\n')
    return \`[\n\${items}\n\${' '.repeat(indent - 2)}]\`
  }

  if (typeof obj === 'object' && obj !== null) {
    const entries = Object.entries(obj).map(([key, value]) => {
      const keyStr = /^[a-zA-Z_]\w*$/.test(key) ? key : \`"\${key}"\`
      return \`\${space}\${keyStr}: \${toJsObjectString(value, indent + 2)}\`
    }).join(',\n')

    return \`{\n\${entries}\n\${' '.repeat(indent - 2)}}\`
  }

  return JSON.stringify(obj)
}
EOL

cat > "$PROJECT_DIR/src/Shared/Middlewares/sanitize/sanitize.js" <<EOL
console.log('todavia no')
EOL
cat > "$PROJECT_DIR/src/Shared/Middlewares/sanitize/sanitize.test.js" <<EOL
EOL