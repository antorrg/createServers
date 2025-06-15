#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo index.ts en src
cat > "$PROJECT_DIR/index.ts" <<EOL
import app from './src/app.js'
import connectDB from './src/Configs/database.js'
import envConfig from './src/Configs/envConfig.js'
import { userSeed } from './src/Features/userSeed/userSeed.js'

app.listen(envConfig.Port, async () => {
  try {
    await connectDB()
    await userSeed()
    console.log(\`Server is listening on port \${envConfig.Port}\nServer in \${envConfig.Status}\`)
    if(envConfig.Status === 'development'){
      console.log(\`Swagger: Vea y pruebe los endpoints en http://localhost:\${envConfig.Port}/api-docs\`)
    }
  } catch (error) {
    console.error('Error conecting database: ',error)
  }
})
EOL
# Crear el archivo app.ts en src
cat > "$PROJECT_DIR/src/app.ts" <<EOL
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
# Crear el archivo @types en src
cat > "$PROJECT_DIR/src/@types/index.d.ts" <<EOL
import { JwtPayload } from '../Shared/Auth/auth.ts'

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload
      userInfo?: { userId?: string, userRole?: number }
    }
  }
}
EOL
# Crear el archivo routes.ts en src
cat > "$PROJECT_DIR/src/routes.ts" <<EOL
import { Router } from 'express'
import userRouter from './Features/user/user.route.js'

const mainRouter = Router()

mainRouter.use('/api/v1/user', userRouter)

export default mainRouter
EOL