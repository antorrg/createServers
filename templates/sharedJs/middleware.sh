#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
# Dependencias: validator uuid (para pruebas express, jest supertest)
mkdir -p $PROJECT_DIR/src/Shared/Middlewares/helpers
mkdir -p $PROJECT_DIR/src/Shared/Middlewares/helpers/createSchema
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddlewareHandler.js" <<EOL
import { validate as uuidValidate } from 'uuid'
import { AuxValid } from './helpers/auxValid.js'
import {ValidateSchema} from './helpers/ValidateSchema.js'


export default class MiddlewareHandler {

  static validateFields = (schema) => ValidateSchema.validateBody(schema)
  static validateQuery = (schema)=> ValidateSchema.validateQuery(schema)
  static validateHeaders= (schema) => ValidateSchema.validateHeaders(schema)

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
import validator from 'validator'
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
  static validateValue (value, fieldType, fieldName, itemIndex = null, sanitize={}) {
    const indexInfo = itemIndex !== null ? \` in item[\${itemIndex}]\` : ''
    
     if (typeof value === 'object') {
    if (value instanceof String || value instanceof Number || value instanceof Boolean) {
      value = value.valueOf()
    }
  }


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
        if (sanitize) {
        if (sanitize.trim) value = validator.trim(value)
        if (sanitize.escape) value = validator.escape(value)
        if (sanitize.lowercase) value = value.toLowerCase()
        if (sanitize.uppercase) value = value.toUpperCase()
      }
        return value
    }
  }
}
EOL
cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/ValidateSchema.js" <<EOL
import { AuxValid } from './auxValid.js'


export class ValidateSchema {
  static validateBody(schema) {
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
    static validateQuery(schema) {
    return (req, res, next) => {
      try {
        const validated = ValidateSchema.#validateStructure(req.query, schema)
        req.context = req.context || {}
        req.context.query = validated
        next()
      } catch (err) {
        return next(AuxValid.middError(err.message, 400))
      }
    }
  }
static validateHeaders(schema) {
  return (req, res, next) => {
    try {
      const headers = req.headers || {}
      // 1. Validar existencia y valor de content-type
      const contentType = headers['content-type']
      if (!contentType) {
        throw new Error('Missing required header: content-type')
      }
      const lowerContentType = contentType.toLowerCase()
      if (
        lowerContentType !== 'application/json' &&
        !lowerContentType.startsWith('multipart/form-data')
      ) {
        throw new Error('Invalid Content-Type header')
      }

      // 2. Validar resto del esquema si existe
      if (schema) {
        const validated = ValidateSchema.#validateStructure(headers, schema, 'headers')
        req.context = req.context || {}
        req.context.headers = validated
      } else {
        // Si no hay esquema, solo guardamos el header validado
        req.context = req.context || {}
        req.context.headers = { 'content-type': contentType }
      }
      
      next()
    } catch (err) {
      return next(AuxValid.middError(err.message, 400))
    }
  }
}
static #validateStructure(data, schema, path = '') {
  if (Array.isArray(schema)) {
    if (!Array.isArray(data)) {
      throw new Error(\`Expected array at \${path || 'root'}\`)
    }
    return data.map((item, i) =>
      ValidateSchema.#validateStructure(item, schema[0], \`\${path}[\${i}]\`)
    )
  }

  if (typeof schema === 'object' && schema !== null) {
    // Si es un esquema de campo escalar con opciones
    if ('type' in schema) {
      return ValidateSchema.#validateField(data, schema, path)
    }

    // Si es un objeto complejo con múltiples claves
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
          continue
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

  // Si es un tipo simple, como string directamente
  if (typeof schema === 'string') {
    return ValidateSchema.#validateField(data, { type: schema }, path)
  }

  throw new Error(\`Invalid schema at \${path || 'root'}\`)
}

  static #validateField(value, fieldSchema, path) {
    const type = typeof fieldSchema === 'string' ? fieldSchema : fieldSchema.type
    const sanitize = typeof fieldSchema === 'object' ? fieldSchema.sanitize : false

    if (value === undefined || value === null) {
      if (typeof fieldSchema === 'object' && 'default' in fieldSchema) {
        return fieldSchema.default
      }
      throw new Error(\`Missing required field at \${path}\`)
    }

    return AuxValid.validateValue(value, type, path, null, sanitize)
  }
}
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#Crear test para MiddlewareHandler
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddHandler.test.js" <<EOL
import session from 'supertest'
import serverTest from './testHelpers/serverTest.help.js'
const agent = session(serverTest)

describe('Class "MiddlewareHandler". Static class for middleware. Data validation and type checking', () => {
  describe('Method "ValidateFields". Validation and typing of body data (POST and PUT) - Flat object', () => {
    it('should validate, typecast the parameters, and allow the request to proceed if they are correct...', async () => {
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
    it('should validate, typecast, and return an error if a required parameter is missing.', async () => {
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
    it('should validate, attempt typecast, and return an error if a parameter cannot be typecast.', async () => {
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
    it('should validate, typecast the parameters, and strip out any undeclared fields.', async () => {
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
  describe('Method "ValidateFields". Validation and typing of body data (POST and PUT) - Nested object', () => {
    it('should validate, typecast the parameters, and allow the request to proceed if they are correct.', async () => {
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
    it('should validate, typecast, and return an error if a required parameter is missing.', async () => {
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
    it('should validate, attempt typecast, and return an error if a parameter cannot be typecast.', async () => {
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
    it('should validate, typecast the parameters, and strip out any undeclared fields.', async () =>{     const data = {
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
  describe('Method "ValidateFields". Validation and typing of body data (POST and PUT) - Deeply nested object', () => {
    it('should validate, typecast the parameters, and allow the request to proceed if they are correct.', async () => {
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
    it('should validate, typecast, and return an error if a required parameter is missing.', async () => {
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
    it('should validate, attempt typecast, and return an error if a parameter cannot be typecast.', async () => {
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
    it('should validate, typecast the parameters, and strip out any undeclared fields.', async () => {
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
   describe('Method "validateHeaders". Validation and persistence of headers (default: "Content-Type")', () => {
    it('should fail if Content-Type is incorrect.', async () => {
      const res = await agent
        .post('/sanitize-headers')
        .set('Authorization', 'Bearer token')
        .set('Content-Type', 'text/html')
      expect(res.status).toBe(400)
      expect(res.body).toBe('Invalid Content-Type header')
    })
     it('should pass with valid application/json Content-Type.', async () => {
      const res = await agent
        .post('/sanitize-headers')
        .set('Authorization', 'Bearer token')
        .set('Content-Type', 'application/json')
      expect(res.status).toBe(200)
    })

    it('should pass with multipart/form-data', async () => {
      const res = await agent
        .post('/sanitize-headers-form')
        .set('Authorization', 'Bearer token')
          .set('Content-Type', 'multipart/form-data')//; boundary=----WebKitFormBoundary')
         .field('name', 'test value')
      expect(res.status).toBe(200)
      expect(res.body.success).toBe(true)
    })
  })
  describe('Method "validateQuery". Validation and typing of query parameters in GET requests', () => {
    it('should validate, typecast query parameters, and allow the request to proceed if correct.', async () => {
      const response = await agent
        .get('/test/param?page=2&size=2.5&fields=PEPE&truthy=true')
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
    it('should populate the query with default values if it is empty.', async () => {
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
    it('should return an error if any query parameter cannot be typecast.', async () => {
      const response = await agent
        .get('/test/param?page=pepe&size=2.5')
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid integer value')
    })
    it('should escape potentially dangerous characters.', async () => {
      const response = await agent
        .get('/test/param?page=2&size=2.5&fields=<p>pepe</p>&truthy=true&demas=pepito')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.validData).toEqual({
        page: 2,
        size: 2.5,
        fields: '&lt;p&gt;pepe&lt;&#x2f;p&gt;',
        truthy: true
      })
    })
    it('should remove any undeclared query parameters.', async () => {
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
  describe('Method "validateRegex". Specific field validation using regular expressions.', () => {
    it('should allow the request if the parameter matches the regex.', async () => {
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
    it('should return an error if the parameter does not match the regex.', async () => {
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
  describe('Method "paramId". Validation of "param" ID as UUID v4', () => {
    it('should allow the request if the ID is a valid UUID.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76-191f905a2edd'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })
    it('should return an error if the ID is not a valid UUID.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })
  describe('Method "paramId". Validation of "param" ID as INTEGER.', () => {
    it('should allow the request if the ID is a valid integer.', async () => {
      const id = 1
      const response = await agent
        .get(\`/test/param/int/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })
    it('should return an error if the ID is not a valid integer.', async () => {
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
const headerSchema = {
  'content-type': {
    type: 'string',
    sanitize: { trim: true, lowercase: true },
  }
}
const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

const queries = 
{
 page: {type: 'int', default: 1},
 size: {type: 'float', default: 1},
 fields: {type: 'string', default: '', sanitize:{trim: true, escape: true, lowercase: true}},
 truthy: {type: 'boolean', default: false}
}
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

serverTest.post(
  '/sanitize-headers', 
  MiddlewareHandle.validateHeaders(headerSchema), 
  (req, res) => {
  res.status(200).json({ success: true, headers: req.headers })
})
serverTest.post(
  '/sanitize-headers-form', 
  MiddlewareHandle.validateHeaders(headerSchema), 
  (req, res) => {
  res.status(200).json({ success: true, headers: req.headers, result: req.context.headers})
})
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

# Creacion de generadores de esquemas
cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/createSchema/generate.js" <<EOL
import inquirer from "inquirer";

export default async function promptForField() {
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

      fieldConfig.default =
        kind === 'int' ? parseInt(defaultValue) :
        kind === 'float' ? parseFloat(defaultValue) :
        kind === 'boolean' ? defaultValue === 'true' :
        defaultValue
    }

    if (isOptional) {
      fieldConfig.optional = true
    }

    // 🔽 Si es tipo string, preguntamos por sanitizers
    if (kind === 'string') {
      const { sanitizers } = await inquirer.prompt({
        type: 'checkbox',
        name: 'sanitizers',
        message: '¿Qué sanitizadores querés aplicar?',
        choices: [
          { name: 'trim', value: 'trim' },
          { name: 'escape', value: 'escape' },
          { name: 'toLowerCase', value: 'lowercase' },
          { name: 'toUpperCase', value: 'uppercase' }
        ]
      })

      if (sanitizers.length > 0) {
        fieldConfig.sanitize = {}
        for (const s of sanitizers) {
          fieldConfig.sanitize[s] = true
        }
      }
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
      const itemSchema = { type: itemType }

      // 🔽 Si los elementos son strings, preguntar por sanitizadores
      if (itemType === 'string') {
        const { sanitizers } = await inquirer.prompt({
          type: 'checkbox',
          name: 'sanitizers',
          message: '¿Qué sanitizadores querés aplicar a los elementos del array?',
          choices: [
            { name: 'trim', value: 'trim' },
            { name: 'escape', value: 'escape' },
            { name: 'toLowerCase', value: 'lowercase' },
            { name: 'toUpperCase', value: 'uppercase' }
          ]
        })

        if (sanitizers.length > 0) {
          itemSchema.sanitize = {}
          for (const s of sanitizers) {
            itemSchema.sanitize[s] = true
          }
        }
      }

      field[name] = [itemSchema]
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
