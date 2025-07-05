#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
mkdir -p $PROJECT_DIR/src/Shared/Middlewares/second
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddlewareHandler.js" <<EOL
import { validate as uuidValidate } from 'uuid'
import { AuxValid } from './second/auxValid.js'
import { ValidateComplexFields } from './second/validateComplexFields.js'

export default class MiddlewareHandler {
  static validateFieldsWithItems = (requiredFields, secondFields, arrayFieldName) => ValidateComplexFields.validateFieldsWithItems(requiredFields, secondFields, arrayFieldName)

  static validateFields (requiredFields = []) {
    return (req, res, next) => {
      const newData = req.body
      if (!newData || Object.keys(newData).length === 0) {
        return next(AuxValid.middError('Invalid parameters', 400))
      }
      const missingFields = requiredFields.filter(field => !(field.name in newData))
      if (missingFields.length > 0) {
        return next(AuxValid.middError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400))
      }
      try {
        requiredFields.forEach(field => {
          const value = newData[field.name]
          newData[field.name] = AuxValid.validateValue(value, field.type, field.name)
        })

        Object.keys(newData).forEach(key => {
          if (!requiredFields.some(field => field.name === key)) {
            delete newData[key]
          }
        })
      } catch (error) {
        return next(AuxValid.middError(error.message, 400))
      }
      req.body = newData
      next()
    }
  }

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
        // req.validatedQuery = validatedQuery // Nuevo objeto tipado en lugar de modificar req.query
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

  static middUuid (fieldName) {
    return (req, res, next) => {
      const id = req.params[fieldName]
      if (!id) return next(AuxValid.middError('Falta el id', 400))
      if (!uuidValidate(id)) return next(AuxValid.middError('Parametros no permitidos', 400))
      next()
    }
  }

  static middIntId (fieldName) {
    return (req, res, next) => {
      const id = req.params[fieldName]
      if (!id) return next(AuxValid.middError('Falta el id', 400))
      if (!Number.isInteger(Number(id))) return next(AuxValid.middError('Parametros no permitidos', 400))
      next()
    }
  }
}
EOL
cat > "$PROJECT_DIR/src/Shared/Middlewares/second/auxValid.js" <<EOL
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
cat > "$PROJECT_DIR/src/Shared/Middlewares/second/validateComplexFields.js" <<EOL
import { AuxValid } from './auxValid.js'

export class ValidateComplexFields {
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
          return next(AuxValid.middError('Invalid parameters', 400))
        }

        // Verificar campos faltantes en 'firstData'
        const missingFields = requiredFields.filter((field) => !(field.name in firstData))
        if (missingFields.length > 0) {
          return next(AuxValid.middError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400))
        }

        try {
          requiredFields.forEach(field => {
            const value = firstData[field.name]
            firstData[field.name] = AuxValid.validateValue(value, field.type, field.name)
          })

          // Filtrar campos adicionales no permitidos en \`firstData\`
          Object.keys(firstData).forEach(key => {
            if (!requiredFields.some(field => field.name === key)) {
              delete firstData[key]
            }
          })
        } catch (error) {
          return next(AuxValid.middError(error.message, 400))
        }

        // Validar existencia y estructura de \`secondData\`
        if (!secondData || secondData.length === 0) {
          return next(AuxValid.middError(\`Missing \${arrayFieldName} array or empty array\`, 400))
        }

        // Validar contenido de 'secondData' (no debe contener strings)
        const invalidStringItems = secondData.filter((item) => typeof item === 'string')
        if (invalidStringItems.length > 0) {
          return next(
            AuxValid.middError(
              \`Invalid "\${arrayFieldName}" content: expected objects but found strings (e.g., \${invalidStringItems[0]})\`,
              400
            )
          )
        }

        // Validar cada objeto dentro de 'secondData'
        const validatedSecondData = secondData.map((item, index) => {
          const missingItemFields = secondFields.filter((field) => !(field.name in item))
          if (missingItemFields.length > 0) {
            return next(AuxValid.middError(
              \`Missing parameters in \${arrayFieldName}[\${index}]: \${missingItemFields.map(f => f.name).join(', ')}\`,
              400
            ))
          }

          // Validar tipos de campos en cada \`item\` usando la función aislada
          secondFields.forEach(field => {
            const value = item[field.name]
            item[field.name] = AuxValid.validateValue(value, field.type, field.name, index)
          })

          // Filtrar campos adicionales en cada \`item\`
          return secondFields.reduce((acc, field) => {
            acc[field.name] = item[field.name]
            return acc
          }, {})
        })

        // Actualizar 'req.body' con datos validados
        req.body = {
          ...firstData,
          [arrayFieldName]: validatedSecondData // Asignar dinámicamente
        }

        // Continuar al siguiente middleware
        next()
      } catch (err) {
        return next(AuxValid.middError(err.message, 400)) // Manejar errores
      }
    }
  }
}
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#Crear test para MiddlewareHandler
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddHandler.test.js" <<EOL
import session from 'supertest'
import serverTest from './testHelpers/serverTest.js'
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
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#Crear helperTest para MiddlewareHandler

cat > "$PROJECT_DIR/src/Shared/Middlewares/testHelpers/serverTest.help.js" <<EOL
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