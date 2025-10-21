#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

mkdir -p $PROJECT_DIR/src/Features/user
mkdir -p $PROJECT_DIR/src/Features/product
# Crear archivo UserService.ts
cat > "$PROJECT_DIR/src/Features/user/UserMappers.ts" <<EOL
import { type User } from '../../Configs/database.js'
export interface IUserSeq {
  id: string
  email: string
  password?: string
  nickname?: string | null
  name: string
  picture?: string | null
  enabled: boolean
}
export interface CreateUserInput {
  email: string
  password?: string
  nickname?: string | null
  name: string
  picture?: string | null
  enabled: boolean
}
export type UpdateUserInput = Partial<CreateUserInput>

export const userParser = (
  u: InstanceType<typeof User>
): IUserSeq => {
  const raw = u.get({ plain: true })
  return {
    id: raw.id,
    email: raw.email,
    nickname: raw.nickname,
    name: raw.name,
    picture: raw.picture,
    enabled: raw.enabled
  }
}
EOL

cat > "$PROJECT_DIR/src/Features/user/UserMidd.ts" <<EOL
import { type Request, type Response, type NextFunction } from 'express'
import envConfig from '../../Configs/envConfig.js'
import bcrypt from 'bcrypt'

export class UserMidd {
  static createUser = async (req: Request, res: Response, next: NextFunction) => {
    const { email, password } = req.body
    req.body = {
      email,
      password: await bcrypt.hash(password, 12),
      nickname: email.split('@')[0],
      picture: envConfig.UserImg,
      enabled: true
    }
    next()
  }
}
EOL

cat > "$PROJECT_DIR/src/Features/user/schemas.ts" <<EOL
import type { Schema } from 'req-valid-express'

export const update: Schema = {
  email: {
    type: 'string',
    sanitize: {
      trim: true
    }
  },
  password: {
    type: 'string',
    sanitize: {
      trim: true
    }
  },
  nickname: {
    type: 'string',
    sanitize: {
      trim: true
    }
  },
  name: {
    type: 'string',
    sanitize: {
      trim: true
    }
  },
  picture: {
    type: 'string',
    sanitize: {
      trim: true
    }
  },
  enabled: {
    type: 'boolean',
    default: true
  }
}

export const create: Schema = {
  email: {
    type: 'string',
    sanitize: {
      trim: true
    }
  },
  password: {
    type: 'string',
    sanitize: {
      trim: true
    }
  }
}
EOL

# Crear el archivo user.route.ts
cat > "$PROJECT_DIR/src/Features/user/user.route.ts" <<EOL
import { Router } from 'express'
import { User } from '../../Configs/database.js'
import { BaseRepository } from '../../Shared/Repositories/BaseRepository.js'
import { BaseService } from '../../Shared/Services/BaseService.js'
import ImgsService from '../../Shared/Services/ImgsService.js'
import { BaseController } from '../../Shared/Controllers/BaseController.js'
import { userParser } from './UserMappers.js'
import { Validator } from 'req-valid-express'
import { Auth } from '../../Shared/Auth/auth.js'
import { create, update } from './schemas.js'
import { UserMidd } from './UserMidd.js'

const userRepository = new BaseRepository(User, userParser, 'User', 'email')
export const userService = new BaseService(userRepository, ImgsService, false, 'picture')
const user = new BaseController(userService)

const password: RegExp = /^(?=.*[A-Z]).{8,}$/
const email: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const userRouter = Router()

userRouter.get(
  '/',
  user.getAll
)
userRouter.get(
  '/pages',
  user.getWithPages
)
userRouter.get(
  '/:id',
  Validator.paramId('id', Validator.ValidReg.UUIDv4),
  user.getById
)

userRouter.post(
  '/create',
  Validator.validateBody(create),
  Validator.validateRegex(
    email,
    'email',
    'Enter a valid email'
  ),
  Validator.validateRegex(
    password,
    'password',
    'Enter a valid password'
  ),
  UserMidd.createUser,
  user.create
)

userRouter.put(
  '/:id',
  Validator.paramId('id', Validator.ValidReg.UUIDv4),
  Validator.validateBody(update),
  user.update
)

userRouter.delete(
  '/:id',
  Auth.verifyToken,
  Validator.paramId('id', Validator.ValidReg.UUIDv4),
  user.delete
)

export default userRouter
EOL