#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo app.ts en src
cat > "$PROJECT_DIR/src/app.js" <<EOL
import express from 'express'
import morgan from 'morgan'
import cors from 'cors'
import eh from './Configs/errorHandlers.js'
import mainRouter from './routes.js'
import swaggerUi from 'swagger-ui-express'
import swaggerJsDoc from 'swagger-jsdoc'
import swaggerOptions from './Shared/Swagger/swaggerOptions.js'
import envConfig from './Configs/envConfig.js'


const swaggerDocs = swaggerJsDoc(swaggerOptions)
const swaggerUiOptions = {
  swaggerOptions: {
    docExpansion: 'none' // 👈 Oculta todas las rutas al cargar
  }
}
const app = express()
app.use(morgan('dev'))
app.use(cors())
app.use(express.json())
app.use(eh.jsonFormat)
if (envConfig.Status === 'development') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocs, swaggerUiOptions))
}
app.use(mainRouter)
app.use(eh.notFoundRoute)
app.use(eh.errorEndWare)

export default app
EOL

# Crear el archivo routes.s en src
cat > "$PROJECT_DIR/src/routes.js" <<EOL
import { Router } from 'express'
import userRouter from './Features/user/user.routes.js'

const mainRouter = Router()

mainRouter.use('/api/v1/user', userRouter)

export default mainRouter
EOL