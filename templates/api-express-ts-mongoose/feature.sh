#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivo UserService.ts
cat > "$PROJECT_DIR/src/Features/user/UserService.ts" <<EOL
import bcrypt from 'bcrypt'
import { BaseService } from '../../Shared/Services/BaseService.js'
import { throwError } from '../../Configs/errorHandlers.js'
import { Auth } from '../../Shared/Auth/auth.js'
import { User, IUser } from '../../Shared/Models/userModel.js'
import { UserDto } from './userDto.js'
import envConfig from '../../Configs/envConfig.js'
import { BaseRepository } from '../../Shared/Repositories/BaseRepository.js'

interface loginResponse { user: any, token: string }

const userRepository = new BaseRepository<IUser>(User, 'User', 'email')

export class UserService extends BaseService<IUser> {
  constructor () {
    super(
      userRepository,
      false, // useImages
      undefined, // deleteImages
      UserDto.infoClean // parserFunction
    )
  }

  async create (data: { email: string, password: string, role?: number, isRoot?: boolean }): Promise<{ message: string, results: any }> {
    // Verifica unicidad usando el repositorio
    const exists = await this.repository.getOne(data.email, 'email').catch(() => null)
    if ((exists != null) && exists.results) {
      throwError('This email already exists', 400)
    }

    const newData: Partial<IUser> = {
      email: data.email,
      password: await bcrypt.hash(data.password, 12),
      nickname: data.email.split('@')[0],
      picture: envConfig.UserImg,
      role: data.role || 1,
      isRoot: data.isRoot || false
    }
    const res = await this.repository.create(newData)
    return {
      ...res,
      results: (this.parserFunction != null) ? this.parserFunction(res.results) : res.results
    }
  }

  async login (data: { email: string, password: string }): Promise<{ message: string, results: loginResponse }> {
    // Busca el usuario usando el repositorio
    const userRes = await this.repository.getOne(data.email, 'email').catch(() => null)
    const userFound = userRes?.results
    if (userFound == null) { throwError('User not found', 404) }
    const hash: string | null = userFound!.password
    const passwordMatch = await bcrypt.compare(data.password, hash)
    if (!passwordMatch) { throwError('Invalid password', 400) }
    if (!userFound!.enabled) { throwError('User is blocked', 400) }
    const token = Auth.generateToken({
      id: userFound!._id.toString(),
      email: userFound!.email,
      role: userFound!.role
    })
    return {
      message: 'Login successfully',
      results: {
        user: (this.parserFunction != null) ? this.parserFunction(userFound!) : userFound,
        token
      }
    }
  }
}
EOL
# Crear el archivo userService.test.ts
cat > "$PROJECT_DIR/src/Features/user/UserService.test.ts" <<EOL
import { UserService } from './UserService.js'
import { resetDatabase } from '../../../test/jest.setup.js'
import { userCreated, userRootCreated } from './testHelpers/user.helperTest.help.js'
import { setStringId, getStringId } from '../../../test/testHelpers/testStore.help.js'

const test = new UserService()

describe('Unit tests for the BaseService class: CRUD operations.', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('The create method for creating a user', () => {
    it('should create an user with the correct parameters', async () => {
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      const response = await test.create(dataUser)
      setStringId(response.results.id)
      expect(response.message).toBe('User created successfully')
      expect(response.results).toMatchObject(userCreated)
    })
    it('should throw an error when attempting to create the same user twice (error handling)', async () => {
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      try {
        await test.create(dataUser)
        throw new Error('❌ Expected a duplication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('This email already exists')
        } else {
          throw error
        }
      }
    })
    it('should create an root user with the correct parameters (super user)', async () => {
      const dataUser = { email: 'usuarioroot@ejemplo.com', password: 'L1234567', role: 3, isRoot: true }
      const response = await test.create(dataUser)
      expect(response.message).toBe('User created successfully')
      expect(response.results).toMatchObject(userRootCreated)
    })
  })
  describe('Login method for authenticate a user.', () => {
    it('should authenticate the user and return a message, user data, and a token', async () => {
      const data = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      const response = await test.login(data)
      expect(response.message).toBe('Login successfully')
      expect(response.results.user).toMatchObject(userCreated)
      expect(response.results.token).toBeDefined()
      expect(typeof response.results.token).toBe('string')
      expect(response.results.token).not.toBe('')
    })
    it('"should throw an error if the password is incorrect"', async () => {
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567dididi' }
      try {
        await test.login(dataUser)
        throw new Error('❌ Expected a authentication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('Invalid password')
        } else {
          throw error
        }
      }
    })
    it('"should throw an error if the user is blocked"', async () => {
      const data = { enabled: false }
      await test.update(getStringId(), data)
      const dataUser = { email: 'usuario@ejemplo.com', password: 'L1234567' }
      try {
        await test.login(dataUser)
        throw new Error('❌ Expected a authentication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('User is blocked')
        } else {
          throw error
        }
      }
    })
  })
})
EOL
# Crear el archivo UserController.ts
cat > "$PROJECT_DIR/src/Features/user/UserController.ts" <<EOL
import { Request, Response } from 'express'
import { BaseController } from '../../Shared/Controllers/BaseController.js'
import { UserService } from './UserService.js'
import { IUser } from '../../Shared/Models/userModel.js'
import { catchController } from '../../Configs/errorHandlers.js'

export class UserController extends BaseController<IUser> {
  private readonly userService: UserService

  constructor (userService: UserService) {
    super(userService)
    this.userService = userService
  }

  login = catchController(async (req: Request, res: Response) => {
    const data = req.body
    const response = await this.userService.login(data)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })
}
EOL
# Crear el archivo UserDto.ts
cat > "$PROJECT_DIR/src/Features/user/userDto.ts" <<EOL
import { Request, Response, NextFunction } from 'express'
import { IUser } from '../../Shared/Models/userModel.js'
import { Types } from 'mongoose'

export type UserInfo = Pick<IUser, '_id' | 'email' | 'nickname' | 'picture' | 'name' | 'surname' | 'country' | 'role' | 'isVerify' | 'isRoot' | 'enabled'> & {
  _id: Types.ObjectId
}

interface FieldItem { name: string, type: 'string' | 'int' | 'float' | 'boolean' | 'array' }

export interface ParsedUserInfo {
  id: string
  email: string
  nickname: string
  picture: string
  name?: string
  surname?: string
  country?: string
  isVerify: boolean
  role: string
  isRoot: boolean
  enabled: boolean
}

export class UserDto {
  static infoClean (data: UserInfo): ParsedUserInfo {
    return {
      id: data._id.toString(),
      email: data.email,
      nickname: data.nickname,
      picture: data.picture,
      name: data.name || '',
      surname: data.surname || '',
      country: data.country || '',
      role: roleScope(data.role),
      isVerify: data.isVerify,
      isRoot: data.isRoot,
      enabled: data.enabled
    }
  }

  static parsedUser (req: Request, res: Response, next: NextFunction) {
    const newNickname = req.body.email.split('@')[0]
    const numberRole = revertScope(req.body.role)
    req.body.nickname = newNickname
    req.body.role = numberRole
    next()
  }
}
export const create: FieldItem[] = [
  { name: 'email', type: 'string' },
  { name: 'password', type: 'string' }
]
export const update: FieldItem[] = [
  { name: 'email', type: 'string' },
  { name: 'password', type: 'string' },
  { name: 'picture', type: 'string' },
  { name: 'name', type: 'string' },
  { name: 'surname', type: 'string' },
  { name: 'country', type: 'string' },
  { name: 'role', type: 'string' },
  { name: 'enabled', type: 'boolean' }
]
function roleScope (data: number): string {
  const cases: Record<number, string> = {
    1: 'User',
    2: 'Moderator',
    3: 'Admin'
  }
  return cases[data] || 'User'
}
export function revertScope (data: string): number {
  const cases: Record<string, number> = {
    User: 1,
    Moderator: 2,
    Admin: 3
  }
  return cases[data] || 1
}
EOL
# Crear el archivo user.route.ts
cat > "$PROJECT_DIR/src/Features/user/user.route.ts" <<EOL
import { Router } from 'express'
import { UserService } from './UserService.js'
import { UserController } from './UserController.js'
import { MiddlewareHandler } from '../../Shared/Middlewares/MiddlewareHandler.js'
import { UserDto, create, update } from './userDto.js'
import { Auth } from '../../Shared/Auth/auth.js'

export const userService = new UserService()
const user = new UserController(userService)

const password: RegExp = /^(?=.*[A-Z]).{8,}$/
const email: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const userRouter = Router()

userRouter.get(
  '/',
  Auth.verifyToken,
  user.getAll
)

userRouter.get(
  '/:id',
  Auth.verifyToken,
  MiddlewareHandler.middObjectId('id'),
  user.getOne
)

userRouter.post(
  '/create',
  Auth.verifyToken,
  MiddlewareHandler.validateFields(create),
  MiddlewareHandler.validateRegex(
    email,
    'email',
    'Enter a valid email'
  ),
  MiddlewareHandler.validateRegex(
    password,
    'password',
    'Enter a valid password'
  ),
  user.create
)

userRouter.post(
  '/login',
  MiddlewareHandler.validateFields(create),
  MiddlewareHandler.validateRegex(
    email,
    'email',
    'Enter a valid email'
  ),
  MiddlewareHandler.validateRegex(
    password,
    'password',
    'Enter a valid password'
  ),
  user.login
)

userRouter.put(
  '/:id',
  Auth.verifyToken,
  MiddlewareHandler.middObjectId('id'),
  MiddlewareHandler.validateFields(update),
  UserDto.parsedUser,
  user.update
)

userRouter.delete(
  '/:id',
  Auth.verifyToken,
  MiddlewareHandler.middObjectId('id'),
  user.delete
)

export default userRouter
EOL
# Crear el archivo user.helperTest.help.ts
cat > "$PROJECT_DIR/src/Features/user/testHelpers/user.helperTest.help.ts" <<EOL
export const userCreated = {

  id: expect.any(String),
  email: 'usuario@ejemplo.com',
  nickname: 'usuario',
  picture: 'https://urlimageprueba.net',
  name: '',
  surname: '',
  country: '',
  isVerify: false,
  role: 'User',
  isRoot: false,
  enabled: true
}

export const userRootCreated = {
  id: expect.any(String),
  email: 'usuarioroot@ejemplo.com',
  nickname: 'usuarioroot',
  picture: 'https://urlimageprueba.net',
  name: '',
  surname: '',
  country: '',
  isVerify: false,
  role: 'Admin',
  isRoot: true,
  enabled: true
}
EOL
# Crear el seed de Usuarios
cat > "$PROJECT_DIR/src/Features/userSeed/userSeed.ts" <<EOL
import { userService } from "../user/user.route.js";

export const admin = {email:'usuarioadmin@hotmail.com', password:'L1234567', role: 9, isRoot: true, }

export const user = {email:'bartolomiau@gmail.com', password:'L1234567', role: 1, isRoot: false}

export const userSeed = async () => {
    try {
        // Crear los usuarios si no existen
        const seed  = await userService.getAll()
        if(seed.results.length > 0){
            console.log('Users already exists')
            return
        }
        await Promise.all([userService.create(admin), userService.create(user)]);
        console.log('Users created successfully!')
    } catch (error) {
        console.error('Error creating users: ', error);
        throw error;
    }
};
EOL