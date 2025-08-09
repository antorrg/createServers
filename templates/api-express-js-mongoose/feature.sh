#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo user.routes.js en src
cat > "$PROJECT_DIR/src/Features/user/user.routes.js" <<EOL
import express from 'express'
import  User from '../../../models/user.js'
import { GeneralRepository } from '../../Shared/Repositories/GeneralRepository.js'
import { BaseService } from '../../Shared/Services/BaseService.js'
import { BaseController } from '../../Shared/Controllers/BaseController.js'
import vld from './validHelpers/index.js'
import { UserDTO, dataEmpty } from './UserDTO.js'
import MiddlewareHandler from '../../Shared/Middlewares/MiddlewareHandler.js'

const userRep = new GeneralRepository(User, dataEmpty)
const userService = new BaseService(userRep, 'User', 'email', UserDTO.parser, false, null)
const userController = new BaseController(userService)

const regexEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const userRouter = express.Router()

userRouter.post(
  '/create',
  MiddlewareHandler.validateFields(vld.userCreate),
  MiddlewareHandler.validateRegex(regexEmail, 'email'),
  userController.create
)
userRouter.get('/',
  userController.getAll
)
userRouter.get(
  '/pages',
  MiddlewareHandler.validateQuery(vld.userQueries),
  userController.getWithPagination
)
userRouter.get('/:id',
  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.OBJECT_ID),
  userController.getById
)
userRouter.put(
  '/:id',
  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.OBJECT_ID),
  MiddlewareHandler.validateFields(vld.userUpdate),
  MiddlewareHandler.validateRegex(regexEmail, 'email'),
  userController.update
)
userRouter.delete(
  '/:id',
  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.OBJECT_ID),
  userController.delete
)

export default userRouter
EOL
# Crear el archivo mainUser en users
cat > "$PROJECT_DIR/src/Features/user/UserDTO.js" <<EOL
export class UserDTO {
  static parser (d) {
    return {
      id: d._id.toString(),
      email: d.email,
      role: scope(d.role),
      picture: d.picture,
      username: d.username || null,
      enabled: d.enabled,
      createdAt: d.createdAt.toString()
    }
  }
}
export const dataEmpty = {
  id: 'none',
  email: 'no data yet',
  username: 'no data yet',
  password: 'no data yet',
  role: 'no data yet',
  picture: 'no data yet',
  enabled: true,
  createdAt: 'no data yet'
}

function scope (role) {
  switch (role) {
    case 1:
      return 'User'
    case 2:
      return 'Moderator'
    case 3:
      return 'Admin'
    case 9:
      return 'SuperAdmin'
    default:
      return 'User'
  }
}
EOL
mkdir -p $PROJECT_DIR/src/Features/user/validHelpers
# Crear el Servicio de muestra
cat > "$PROJECT_DIR/src/Features/user/validHelpers/index.js" <<EOL
import userCreate from './usercreate.js'
import userUpdate from './userupdate.js'
import userQueries from './userqueries.js'

export default {
  userCreate,
  userUpdate,
  userQueries
}
EOL
# Crear el array de datos:
cat > "$PROJECT_DIR/src/Features/user/validHelpers/usercreate.js" <<EOL
export default {
  email: {
    type: 'string'
  },
  password: {
    type: 'string'
  },
  picture: {
    type: 'string'
  }
}
EOL
cat > "$PROJECT_DIR/src/Features/user/validHelpers/userqueries.js" <<EOL
export default {
  page: {
    type: 'int',
    default: 1,
    optional: false
  },
  limit: {
    type: 'int',
    default: 10,
    optional: false
  },
  orderBy: {
    type: 'string',
    default: 'email',
    optional: false,
    sanitize: {
      trim: true,
      escape: true,
      lowercase: true
    }
  },
  order: {
    type: 'string',
    default: 'DESC',
    optional: false,
    sanitize: {
      trim: true,
      escape: true,
      uppercase: true
    }
  },
  searchField: {
    type: 'string',
    default: 'id',
    optional: false,
    sanitize: {
      trim: true,
      escape: true,
      lowercase: true
    }
  },
  search: {
    type: 'string',
    default: 'null',
    optional: false,
    sanitize: {
      trim: true,
      escape: true,
      lowercase: true
    }
  }
}
EOL

cat > "$PROJECT_DIR/src/Features/user/validHelpers/userupdate.js" <<EOL
export default {
  email: {
    type: 'string'
  },
  password: {
    type: 'string'
  },
  username: {
    type: 'string'
  },
  picture: {
    type: 'string'
  },
  enabled: {
    type: 'boolean'
  }
}
EOL