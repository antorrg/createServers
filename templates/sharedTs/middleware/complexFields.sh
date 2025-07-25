#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/ValidateFields.ts" <<EOL
import { type Request, type Response, type NextFunction } from 'express'
import { HelperFn } from './HelperFn.js'
import { type FieldDefinition } from '../MiddlewareHandler.js'

export class ValidateFields {
  static validateFields = (requiredFields: FieldDefinition[]) => {
    return (req: Request, res: Response, next: NextFunction) => {
      const newData = req.body
      if (!newData || Object.keys(newData).length === 0) {
        next(HelperFn.MiddError('Invalid parameters', 400)); return
      }

      const missingFields = requiredFields.filter(field => !(field.name in newData))
      if (missingFields.length > 0) {
        next(HelperFn.MiddError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400)); return
      }

      try {
        requiredFields.forEach(field => {
          const value = newData[field.name]
          newData[field.name] = HelperFn.validateValue(value, field.type, field.name)
        })

        Object.keys(newData).forEach(key => {
          if (!requiredFields.some(field => field.name === key)) {
            delete newData[key]
          }
        })
      } catch (error: any) {
        next(HelperFn.MiddError(error.message, 400)); return
      }

      req.body = newData
      next()
    }
  }
}
EOL

cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/ValidateComplexFields.ts" <<EOL
import { type Request, type Response, type NextFunction } from 'express'
import { HelperFn } from './HelperFn.js'
import { type FieldDefinition } from '../MiddlewareHandler.js'

export class ValidateComplexFields {
  static validateFieldsWithItems = (
    requiredFields: FieldDefinition[],
    secondFields: FieldDefinition[],
    arrayFieldName: string
  ) => {
    return (req: Request, res: Response, next: NextFunction) => {
      try {
        const firstData = { ...req.body }
        const secondData = Array.isArray(req.body[arrayFieldName])
          ? [...req.body[arrayFieldName]]
          : null

        if (!firstData || Object.keys(firstData).length === 0) {
          next(HelperFn.MiddError('Invalid parameters', 400)); return
        }

        const missingFields = requiredFields.filter((field) => !(field.name in firstData))
        if (missingFields.length > 0) {
          next(HelperFn.MiddError(\`Missing parameters: \${missingFields.map(f => f.name).join(', ')}\`, 400)); return
        }

        requiredFields.forEach(field => {
          const value = firstData[field.name]
          firstData[field.name] = HelperFn.validateValue(value, field.type, field.name)
        })

        Object.keys(firstData).forEach(key => {
          if (!requiredFields.some(field => field.name === key)) {
            delete firstData[key]
          }
        })

        if ((secondData == null) || secondData.length === 0) {
          next(HelperFn.MiddError(\`Missing \${arrayFieldName} array or empty array\`, 400)); return
        }

        const invalidStringItems = secondData.filter((item) => typeof item === 'string')
        if (invalidStringItems.length > 0) {
          next(
            HelperFn.MiddError(
              \`Invalid "\${arrayFieldName}" content: expected objects but found strings (e.g., \${invalidStringItems[0]})\`,
              400
            )
          ); return
        }

        const validatedSecondData = secondData.map((item, index) => {
          const missingItemFields = secondFields.filter((field) => !(field.name in item))
          if (missingItemFields.length > 0) {
            throw HelperFn.MiddError(
              \`Missing parameters in \${arrayFieldName}[\${index}]: \${missingItemFields.map(f => f.name).join(', ')}\`,
              400
            )
          }

          secondFields.forEach(field => {
            const value = item[field.name]
            item[field.name] = HelperFn.validateValue(value, field.type, field.name, index)
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
        next(HelperFn.MiddError(err.message, 400))
      }
    }
  }
}
EOL