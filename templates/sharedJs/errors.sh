#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivo de manejo de errores de Express
cat > "$PROJECT_DIR/src/Configs/errorHandlers.js" <<EOL
import envConfig from './envConfig.js'


class CustomError extends Error {
  constructor (log = false) {
    super()
    this.log = log
    Object.setPrototypeOf(this, CustomError.prototype)
  }

  throwError (message, status, err) {
    const error = new Error(message)
    error.status = Number(status) || 500
    if (this.log && (err != null)) {
      console.error('Error: ', err)
    }
    throw error
  }

  processError (err, contextMessage){
    const defaultStatus = 500
    const status = err.status || defaultStatus

    const message = err.message
      ? \`\${contextMessage}: \${err.message}\`
      : contextMessage

    // Creamos un nuevo error con la información combinada
    const error = new Error(message)
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

export const catchController = (controller) => {
  return (req, res, next) => {
    return controller(req, res, next).catch(next)
  }
}

export const middError = (message, status) => {
  const error = new Error(message)
  error.status = status || 500
  return error
}
export const throwError = errorHandler.throwError.bind(errorHandler)

export const processError = errorHandler.processError.bind(errorHandler)

export const errorEndWare = (err, req, res, next) => {
  const status = err.status || 500
  const message = err.message || 'Internal server error'
  res.status(status).json({
    success: false,
    message,
    data: null
  })
}

export const jsonFormat = (err, req, res, next)=> {
  if (err instanceof SyntaxError && 'status' in err && err.status === 400 && 'body' in err) {
    return next(middError('Invalid JSON format', 400))
  } else {
    next()
  }
}

export const notFoundRoute = (req, res, next)=> {
  return next(middError('Not Found', 404))
}

export default {
  errorEndWare,
  catchController,
  throwError,
  processError,
  middError,
  jsonFormat,
  notFoundRoute
}
EOL