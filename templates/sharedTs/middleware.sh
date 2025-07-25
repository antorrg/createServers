#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

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
declare module 'express-serve-static-core' {
  interface Request {
    context?: {
      query?: Record<string, any>
    }
  }
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

       req.context = req.context || {}
              req.context.query = validatedQuery
              next()
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
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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