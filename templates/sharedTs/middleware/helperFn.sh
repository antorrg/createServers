#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
cat > "$PROJECT_DIR/src/Shared/Middlewares/helpers/HelperFn.ts" <<EOL
export type FieldType = 'boolean' | 'int' | 'float' | 'string' | 'array'

export type MiddError = Error & { status?: number }

export class HelperFn {
  static MiddError = (message: string, status: number): MiddError => {
    const error = new Error(message) as MiddError
    error.status = status
    return error
  }

  static getDefaultValue = (type: FieldType): any => {
    switch (type) {
      case 'boolean':
        return false
      case 'int':
        return 1
      case 'float':
        return 1.0
      case 'string':
        return ''
      case 'array':
        return []
      default:
        return null
    }
  }

  static validateBoolean = (value: any): boolean => {
    if (typeof value === 'boolean') return value
    if (value === 'true') return true
    if (value === 'false') return false
    throw new Error('Invalid boolean value')
  }

  static validateInt = (value: any): number => {
    const intValue = Number(value)
    if (isNaN(intValue) || !Number.isInteger(intValue)) {
      throw new Error('Invalid integer value')
    }
    return intValue
  }

  static validateFloat = (value: any): number => {
    const floatValue = parseFloat(value)
    if (isNaN(floatValue)) {
      throw new Error('Invalid float value')
    }
    return floatValue
  }

  static validateValue = (
    value: any,
    fieldType: FieldType,
    fieldName: string,
    itemIndex: number | null = null
  ): any => {
    const indexInfo = itemIndex !== null ? \` in item[\${itemIndex}]\` : ''
    switch (fieldType) {
      case 'boolean':
        return HelperFn.validateBoolean(value)
      case 'int':
        return HelperFn.validateInt(value)
      case 'float':
        return HelperFn.validateFloat(value)
      case 'array':
        if (!Array.isArray(value)) {
          throw new Error(
            \`Invalid array value for field \${fieldName}\${indexInfo}\`
          )
        }
        return value
      case 'string':
      default:
        if (typeof value !== 'string') {
          throw new Error(
            \`Invalid string value for field \${fieldName}\${indexInfo}\`
          )
        }
        return value
    }
  }
}
EOL