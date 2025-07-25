#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddlewareHandler.ts" <<EOL
import { validate as uuidValidate } from 'uuid'
import { Request, Response, NextFunction } from 'express'
import { HelperFn, type FieldType,} from './helpers/HelperFn.js'
import { ValidateFields } from './helpers/ValidateFields.js'
import { ValidateComplexFields } from './helpers/ValidateComplexFields.js'

export interface FieldDefinition {
  name: string
  type: FieldType
  default?: any
}

export class MiddlewareHandler {
  static validateFields = ValidateFields.validateFields

  static validateFieldsWithItems = ValidateComplexFields.validateFieldsWithItems

  static validateQuery (requiredFields: FieldDefinition[]) {
    return (req: Request, res: Response, next: NextFunction) => {
      try {
        const validatedQuery: Record<string, any> = {}

        requiredFields.forEach(({ name, type, default: defaultValue }) => {
          let value = req.query[name]

          if (value === undefined) {
            value = defaultValue !== undefined ? defaultValue : HelperFn.getDefaultValue(type)
          } else {
            value = HelperFn.validateValue(value, type, name)
          }

          validatedQuery[name] = value
        })

        req.context = req.context || {};
        req.context.query = validatedQuery;
        next()
      } catch (error: any) {
        next(HelperFn.MiddError(error.message, 400))
      }
    }
  }

  static validateRegex (validRegex: RegExp, nameOfField: string, message: string | null = null) {
    return (req: Request, res: Response, next: NextFunction) => {
      if (!validRegex || !nameOfField || nameOfField.trim() === '') {
        next(HelperFn.MiddError('Missing parameters in function!', 400)); return
      }
      const field = req.body[nameOfField]
      const personalizedMessage = message ? ' ' + message : ''
      if (!field || typeof field !== 'string' || field.trim() === '') {
        next(HelperFn.MiddError(\`Missing \${nameOfField}\`, 400)); return
      }
      if (!validRegex.test(field)) {
        next(HelperFn.MiddError(\`Invalid \${nameOfField} format!\${personalizedMessage}\`, 400)); return
      }
      next()
    }
  }

  static paramId (fieldName: string, validator: RegExp | ((val: string) => boolean)) {
    return (req: Request, res: Response, next: NextFunction) => {
      const id = req.params[fieldName]
      if (!id) {
        next(HelperFn.MiddError('Falta el id', 400)); return
      }
      const isValid = typeof validator === 'function' ? validator(id) : validator.test(id)
      if (!isValid) {
        next(HelperFn.MiddError('Parametros no permitidos', 400)); return
      }
      next()
    }
  }

  static logRequestBody (req: Request, res: Response, next: NextFunction) {
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
