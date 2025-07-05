#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo user.routes.js en src
cat > "$PROJECT_DIR/src/Features/user/user.routes.js" <<EOL
import express from 'express'
import { userController, userCreate, userUpdate, regexEmail } from './mainUser.js'
import MiddlewareHandler from '../../Shared/Middlewares/MiddlewareHandler.js'
const userRouter = express.Router()

userRouter.post(
  '/',
  MiddlewareHandler.validateFields(userCreate),
  MiddlewareHandler.validateRegex(regexEmail, 'email'),
  userController.create
)
userRouter.get('/',
  userController.getAll
)
userRouter.get('/:id',
  MiddlewareHandler.middIntId('id'),
  userController.getById
)
userRouter.put(
  '/:id',
  MiddlewareHandler.middIntId('id'),
  MiddlewareHandler.validateFields(userUpdate),
  MiddlewareHandler.validateRegex(regexEmail, 'email'),
  userController.update
)
userRouter.delete(
  '/:id',
  MiddlewareHandler.middIntId('id'),
  userController.delete
)

export default userRouter
EOL
# Crear el archivo mainUser en users
cat > "$PROJECT_DIR/src/Features/user/mainUser.js" <<EOL
import { UserService } from './UserService.js'
import { BaseController} from '../../Shared/Controllers/BaseController.js'
import { users } from './users.js'

const userService = new UserService(users)
export const userController = new BaseController(userService)

export const userCreate = [{ name: 'name', type: 'string' }, { name: 'username', type: 'string' }, { name: 'email', type: 'string' }]
export const userUpdate = [{ name: 'name', type: 'string' }, { name: 'username', type: 'string' }, { name: 'email', type: 'string' }, { name: 'enable', type: 'boolean' }, { name: 'phone', type: 'int' }]
export const regexEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
EOL
# Crear el Servicio de muestra
cat > "$PROJECT_DIR/src/Features/user/UserService.js" <<EOL
import eh from '../../Configs/errorHandlers.js'

export class UserService {
  constructor (Model) {
    this.Model = Model
  }

  // Crear un nuevo usuario
  create (data) {
     const newId = this.Model.length ? Math.max(...this.Model.map(user => user.id)) + 1 : 1
    const randomSevenDigit =()=> Math.floor(1000000 + Math.random() * 9000000)
   
    const newUser = {
      id: newId,
      name: data.name,
      username: data.username,
      email: data.email,
      enable: true,
      phone: randomSevenDigit()
    }
    this.Model.push(newUser)
    return {
      message: 'User created successfully',
      results: newUser
    }
  }

  // Obtener todos los usuarios
  getAll () {
    return {
      message: 'Users found',
      results: this.Model
    }
  }

  // Obtener un usuario por ID
  getById (id) {
    const response = this.Model.find(user => user.id === Number(id))
    if (!response) { eh.throwError('User not found', 404) }
    return {
      message: 'Users found',
      results: response
    }
  }

  // Actualizar un usuario por ID
  update (id, newData) {
    const index = this.Model.findIndex(user => user.id === Number(id))
    if (index === -1) { eh.throwError('This user do not exists', 404) };

    this.Model[index] = { ...this.Model[index], ...newData }
    return {
      message: 'Users updated successfully',
      results: this.Model[index]
    }
  }

  // Eliminar un usuario por ID
  delete (id) {
    const index = this.Model.findIndex(user => user.id === Number(id))
    if (index === -1) { eh.throwError('User not found', 404) }
    return {
      message: 'User deleted successfully',
      results: this.Model.splice(index, 1)[0] // Elimina y devuelve el usuario eliminado
    }
  }
}
EOL
# Crear el array de datos:
cat > "$PROJECT_DIR/src/Features/user/users.js" <<EOL
export const users = [
  {
    id: 1,
    name: 'Leanne Graham',
    username: 'Bret',
    email: 'Sincere@april.biz',
    enable:true,
    phone: 5578896
  },
  {
    id: 2,
    name: 'Ervin Howell',
    username: 'Antonette',
    email: 'Shanna@melissa.tv',
    enable:true,
    phone: 3420219
  },
  {
    id: 3,
    name: 'Clementine Bauch',
    username: 'Samantha',
    email: 'Nathan@yesenia.net',
    enable:true,
    phone: 7101901
  },
  {
    id: 4,
    name: 'Patricia Lebsack',
    username: 'Karianne',
    email: 'Julianne.OConner@kory.org',
    enable:true,
    phone: 3623102
  },
  {
    id: 5,
    name: 'Chelsey Dietrich',
    username: 'Kamren',
    email: 'Lucio_Hettinger@annie.ca',
    enable:true,
    phone: 1051203
  },
  {
    id: 6,
    name: 'Mrs. Dennis Schulist',
    username: 'Leopoldo_Corkery',
    email: 'Karley_Dach@jasper.info',
    enable:true,
    phone: 5862081
  },
  {
    id: 7,
    name: 'Kurtis Weissnat',
    username: 'Elwyn.Skiles',
    email: 'Telly.Hoeger@billy.biz',
    enable:true,
    phone: 7452263
  },
  {
    id: 8,
    name: 'Nicholas Runolfsdottir V',
    username: 'Maxime_Nienow',
    email: 'Sherwood@rosamond.me',
    enable:true,
    phone: 9235392
  },
  {
    id: 9,
    name: 'Glenna Reichert',
    username: 'Delphine',
    email: 'Chaim_McDermott@dana.io',
    enable:true,
    phone: 2582826
  },
  {
    id: 10,
    name: 'Clementina DuBuque',
    username: 'Moriah.Stanton',
    email: 'Rey.Padberg@karina.biz',
    enable:true,
    phone: 8987275
  }
]
EOL