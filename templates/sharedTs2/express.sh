#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

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
#Crear carpeta y archivo de tipos genericos de repository 
cat > "$PROJECT_DIR/src/Shared/Interfaces/base.interface.ts" <<EOL
export interface IRepositoryResponse<T> {
  message: string
  results: T
}
export type Direction = 1 | -1 | 'ASC' | 'DESC'
export interface Order<TDTO> {
  field: keyof TDTO
  direction: Direction
}

export interface IPaginatedOptions<TDTO> {
  query?: Partial<Record<keyof TDTO, unknown>>
  page?: number
  limit?: number
  order?: Partial<Record<keyof TDTO, Direction>>
}

export interface IPaginatedResults<TDTO> {
  message: string
  info: { total: number, page: number, limit: number, totalPages: number }
  data: TDTO[]
}
export type TUpdate<T> = Partial<Omit<T, 'id'>>
export interface IBaseRepository<TDTO, TCreate, TUpdate> {
  getAll: (field?: unknown, whereField?: keyof TDTO | string) => Promise<IRepositoryResponse<TDTO[]>>
  getById: (id: string | number) => Promise<IRepositoryResponse<TDTO>>
  getByField: (field: unknown, whereField: keyof TDTO | string) => Promise<IRepositoryResponse<TDTO>>
  getWithPages: (options?: IPaginatedOptions<TDTO>) => Promise<IPaginatedResults<TDTO>>
  create: (data: TCreate) => Promise<IRepositoryResponse<TDTO>>
  update: (id: string | number, data: TUpdate) => Promise<IRepositoryResponse<TDTO>>
  delete: (id: string | number) => Promise<IRepositoryResponse<string>>
}
export interface IExternalImageDeleteService<T> {
  deleteImage: (imageInfo: T) => Promise<boolean>
}
export const mockImageDeleteService: IExternalImageDeleteService<any> = {
  deleteImage: async (_imageInfo: any) => await Promise.resolve(true)
}
EOL

# Crear el archivo routes.ts en src
cat > "$PROJECT_DIR/src/routes.ts" <<EOL
import express from 'express'
import userRouter from './Features/user/user.route.js'

const mainRouter = express.Router()

mainRouter.use('/api/v1/user', userRouter)

export default mainRouter
EOL