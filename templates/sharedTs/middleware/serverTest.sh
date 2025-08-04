#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
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
    async (req: Request, res: Response) => {
      res.status(200).json({ message: 'Passed middleware', data: req.body })
    }
  ))

serverTest.post(
  '/test/body/extra/create',
  MiddlewareHandler.validateFieldsWithItems(firstItems, secondItem, 'items'),
  eh.catchController(
    async (req: Request, res: Response) => {
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
    async (req: Request, res: Response) => {
      res.status(200).json({ message: 'Passed middleware', data: req.body })
    }
  ))

serverTest.get(
  '/test/param',
  MiddlewareHandler.validateQuery(queries),
  eh.catchController(
    async (req: Request, res: Response) => {
      res.status(200).json({
        message: 'Passed middleware',
        data: req.query,
        validData: (req as any).validatedQuery // si se agrega en el middleware, se puede extender \`Request\`
      })
    }
  ))

serverTest.get(
  '/test/param/:id',
  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.UUIDv4),
  eh.catchController(
    async (req: Request, res: Response) => {
      res.status(200).json({ message: 'Passed middleware' })
    }
  ))
serverTest.get(
  '/test/param/int/:id',
  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.INT),
  eh.catchController(
    async (req: Request, res: Response) => {
      res.status(200).json({ message: 'Passed middleware' })
    }
  ))

serverTest.get(
  '/test/param/uuidFn/:id',
  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.UUIDFn),
  eh.catchController(
    async (req: Request, res: Response) => {
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