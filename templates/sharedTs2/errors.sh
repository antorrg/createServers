#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivo de manejo de errores de Express
cat > "$PROJECT_DIR/src/Configs/errorHandlers.ts" <<EOL
import { Request, Response, NextFunction } from 'express'
import envConfig from './envConfig.js'

type Controller = (req: Request, res: Response, next: NextFunction) => Promise<any>

class CustomError extends Error {
  public log: boolean
  constructor (log: boolean = false) {
    super()
    this.log = log
    Object.setPrototypeOf(this, CustomError.prototype)
  }

  throwError (message: string, status: number, err: Error | null = null): never {
    const error = new Error(message) as Error & { status?: number }
    error.status = Number(status) || 500
    if (this.log && (err != null)) {
      console.error('Error: ', err)
    }
    throw error
  }

  processError (err: Error & { status?: number, [key: string]: any }, contextMessage: string): never {
    const defaultStatus = 500
    const status = err.status || defaultStatus

    const message = err.message
      ? \`\${contextMessage}: \${err.message}\`
      : contextMessage

    // Creamos un nuevo error con la información combinada
    const error = new Error(message) as Error & { status?: number, originalError?: Error }
    error.status = status
    error.originalError = err // Guardamos el error original para referencia

    // Log en desarrollo si es necesario
    if (this.log) {
      console.error('Error procesado:', {
        context: contextMessage,
        originalMessage: err.message,
        status,
        originalError: err
      })
    }

    throw error
  }
}
const environment = envConfig.Status
const errorHandler = new CustomError(environment === 'development' || environment === 'test')

export const middError = (message: string, status: number): Error & { statusCode?: number } => {
  const error = new Error(message) as Error & { status?: number }
  error.status = status
  return error
}
export const throwError = errorHandler.throwError.bind(errorHandler)

export const processError = errorHandler.processError.bind(errorHandler)

export const errorEndWare = (err: Error & { status?: number }, req: Request, res: Response, next: NextFunction) => {
  const status = err.status || 500
  const message = err.message || 'Internal server error'
  res.status(status).json({
    success: false,
    message,
    data: null
  })
}

export const jsonFormat = (err: Error & { status?: number }, req: Request, res: Response, next: NextFunction): void => {
  if (err instanceof SyntaxError && 'status' in err && err.status === 400 && 'body' in err) {
    res.status(400).json({ error: 'Invalid JSON format' })
  } else {
    next()
  }
}

export const notFoundRoute = (req: Request, res: Response, next: NextFunction): void => {
  return next(middError('Not Found', 404))
}

export default {
  errorEndWare,
  throwError,
  processError,
  middError,
  jsonFormat,
  notFoundRoute
}
EOL