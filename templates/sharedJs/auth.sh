#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo de validacion
cat > "$PROJECT_DIR/src/Shared/Auth/Auth.js" <<EOL
import pkg from 'jsonwebtoken'
import crypto from 'crypto'
import eh from '../../Configs/errorHandlers.js'
import envConfig from '../../Configs/envConfig.js'


export class Auth {
  static generateToken (user, expiresIn){
    const intData = disguiseRole(user.role, 5)
    const jwtExpiresIn = expiresIn ?? Math.ceil(envConfig.ExpiresIn * 60 * 60)
    const secret = envConfig.Secret;
    return pkg.sign(
      { userId: user.id, email: user.email, internalData: intData },
      secret,
      { expiresIn }
    )
  }
    static generateEmailVerificationToken (user, expiresIn?) {
        const userId = user.id
        const secret = envConfig.Secret;
        const jwtExpiresIn = expiresIn ?? '8h'
      return pkg.sign(
        { userId, type: 'emailVerification' },
        secret,
        { expiresIn }
      )
    }

  static async verifyToken (req, res, next){
    try {
      let token = req.headers['x-access-token']  || req.headers.authorization
      if (!token) {
        return next(eh.middError('Unauthorized access. Token not provided', 401))
      }
      if (token.startsWith('Bearer')) {
        token = token.slice(6).trim()
      }
      if (token === '' || token === 'null' || token === 'undefined') {
        return next(eh.middError('Missing token!', 401));
      }

      const decoded = pkg.verify(token, envConfig.Secret)

      //req.user = decoded
      const userId = decoded.userId
      const userRole = recoveryRole(decoded.internalData, 5)
      req.userInfo = { userId, userRole }

      next()
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return next(eh.middError('Expired token', 401))
      }
      return next(eh.middError('Invalid token', 401))
    }
  }

    static async verifyEmailToken (req, res, next){
        let token = req.query.token;
        token= token.trim()
         if (token === '' || token === 'null' || token === 'undefined') {
        return next(eh.middError('Verification token missing!', 400));
        }
      try {
        const decoded = pkg.verify(token, envConfig.Secret);
        if (decoded.type !== 'emailVerification') {
          return next(eh.middError('Invalid token type', 400));
        }
        // Adjunta el userId al request para el siguiente handler/service
        req.userInfo = { userId: decoded.userId }
        next();
      } catch (error) {
        return next(eh.middError('Invalid or expired token', 400));
      }
  }
  static checkRole (allowedRoles) {
    return (req, res, next) => {
      const { userRole } = req.userInfo || {}
      if (typeof userRole === 'number' && allowedRoles.includes(userRole)) {
        next()
      } else {
        return next(eh.middError('Access forbidden!', 403))
      }
    }
  }

}

// Funciones auxiliares (pueden ir fuera de la clase)
function disguiseRole (role, position) {
  const generateSecret = () => crypto.randomBytes(10).toString('hex')
  const str = generateSecret()
  if (position < 0 || position >= str.length) throw new Error('Posición fuera de los límites de la cadena')
  const replacementStr = role.toString()
  return str.slice(0, position) + replacementStr + str.slice(position + 1)
}

function recoveryRole (str, position) {
  if (position < 0 || position >= str.length) throw new Error('Posición fuera de los límites de la cadena')
  const recover = str.charAt(position)
  return parseInt(recover)
}

// En recoveryRole str es el dato entrante (string)
// Este es un modelo de como recibe el parámetro checkRole:
// todo   app.get('/ruta-protegida', checkRole([3]),
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Crear el archivo de test
cat > "$PROJECT_DIR/src/Shared/Auth/Auth.test.js" <<EOL
import session from 'supertest'
import serverTest from './testHelpers/serverTest.help.js'
const agent = session(serverTest)
import { Auth } from './Auth.js'
import {setUserToken, getUserToken, setAdminToken, getAdminToken } from '../../../test/testHelpers/testStore.help.js'

describe('"Auth" class. Jsonwebtoken middlewares. Unit tests.', () => {
    describe('Auth.generateToken, Auth.verifyToken. ', () => {
    it('should generate a JWT and allow access through the verifyToken middleware and set the userInfo object (req.useInfo)', async() => {
        const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
        const token = Auth.generateToken(user)
        setUserToken(token)
        const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer \${token}\`)
                .expect(200);
                expect(test.body.success).toBe(true)
                expect(test.body.message).toBe('Passed middleware')
                expect(test.body.data).toEqual({user})
                expect(test.body.userInfo).toEqual({userId: "123", userRole: 1})// through decoded
    })
    it('should return 401 if no token is provided', async() =>{
         const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
         const token = getUserToken()
         const test = await agent
                .post('/')
                .send({user})
                //.set('Authorization', \`Bearer \${token}\`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Unauthorized access. Token not provided')
                expect(test.body.data).toBe(null)
    })
        it('should return 401 if token is missing after Bearer', async() =>{
         const user = { id: "123"}
         const token = getUserToken()
         const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer \`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Missing token!')
                expect(test.body.data).toBe(null)
    })
         it('should return 401 if token is invalid', async() =>{
         const user = { id: "123"}
         const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer ñasdijfasdfjoasdiieieiehoifdoiidoioslsleoiudoisosdfhoi\`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid token')
                expect(test.body.data).toBe(null)
    })
          it('should return 401 if token is expired', async() =>{
         const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
         const expiredToken = Auth.generateToken(user, 1);
            // Esperamos 2 segundos para asegurarnos de que expire
        await new Promise(resolve => setTimeout(resolve, 3000));
         const test = await agent
                .post('/')
                .send({user})
                .set('Authorization', \`Bearer \${expiredToken}\`)
                .expect(401);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Expired token')
                expect(test.body.data).toBe(null)
    })
  })
  describe('Auth.checkRole', () => {
    it('should allow access if user has an allowed role', async() => {
        const user = { id: "123", email: "userexample@test.com", role:1, otherField: 'other'}
        const token = Auth.generateToken(user)
        setUserToken(token)
        const test = await agent
                .post('/roleUser')
                .send({user})
                .set('Authorization', \`Bearer \${token}\`)
                .expect(200);
                expect(test.body.success).toBe(true)
                expect(test.body.message).toBe('Passed middleware')
                expect(test.body.data).toEqual({user})
                expect(test.body.userInfo).toEqual({userId: "123", userRole: 1})
    })
     it('should return 403 and deny access if user does not have an allowed role', async() => {
        const user = { id: "123", email: "userexample@test.com", role:3, otherField: 'other'}
        const token = Auth.generateToken(user)
        setUserToken(token)
        const test = await agent
                .post('/roleUser')
                .send({user})
                .set('Authorization', \`Bearer \${token}\`)
                .expect(403);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Access forbidden!')
                expect(test.body.data).toBe(null)
                expect(test.body.userInfo).toBe(undefined)
    })
  })
  describe('Auth.generateEmailVerificationToken and Auth.verifyEmailToken methods. Email verification.', () => {
    it('should verify email token and return userId in userInfo', async() => {
       const user = { id: "123", email: "userexample@test.com", }
        const token = Auth.generateEmailVerificationToken(user)
        setAdminToken(token)
        const test = await agent
                .get(\`/emailVerify?token=\${token}\`)
                .expect(200);
                expect(test.body.success).toBe(true)
                expect(test.body.message).toBe('Passed middleware')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual({userId: "123"})// through decoded
    })
    it('should return 400 if token is missing', async() => {
        const test = await agent
                .get(\`/emailVerify?token=''\`)
                .expect(400);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid or expired token')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual(undefined)
    })
    it('should return 400 if token type is invalid', async() => {
       const user = { id: "123", email: "userexample@test.com", }
        const token = getUserToken()
        const test = await agent
                .get(\`/emailVerify?token=\${token}\`)
                .expect(400);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid token type')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual(undefined)
    })
     it('should return 400 if verification token is expired', async() => {
       const user = { id: "123", email: "userexample@test.com", }
        const expiredToken = Auth.generateEmailVerificationToken(user, 1);
            // Esperamos 2 segundos para asegurarnos de que expire
        await new Promise(resolve => setTimeout(resolve, 3000));
        const test = await agent
                .get(\`/emailVerify?token=\${expiredToken }\`)
                .expect(400);
                expect(test.body.success).toBe(false)
                expect(test.body.message).toBe('Invalid or expired token')
                expect(test.body.data).toEqual(null)
                expect(test.body.userInfo).toEqual(undefined)
    })
  })
})
EOL
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Crear archivo de server para test
cat > "$PROJECT_DIR/src/Shared/Auth/testHelpers/serverTest.help.js" <<EOL
import eh from '../../../Configs/errorHandlers.js'
import {Auth} from '../Auth.js'



const serverTest = express()
serverTest.use(express.json())

serverTest.post('/', Auth.verifyToken, eh.catchController(async(req, res,) => {
    const data = req.body
    const decoResponse =  req.userInfo
    res.status(200).json({ success: true, message: 'Passed middleware', data:data, userInfo: decoResponse })
}))

serverTest.post('/roleUser', Auth.verifyToken, Auth.checkRole([1]), eh.catchController(async(req, res,) => {
    const data = req.body
    const decoResponse =  req.userInfo
    res.status(200).json({ success: true, message: 'Passed middleware', data:data, userInfo: decoResponse  })
}))

serverTest.get('/emailVerify', Auth.verifyEmailToken, eh.catchController(async(req, res) => {
    const decoResponse =  req.userInfo
    res.status(200).json({ success: true, message: 'Passed middleware', data:null, userInfo: decoResponse })
}))

serverTest.use((err, req, res, next) => {
  const status = err.status || 500
  const message = err.message || 'Internal server error'
  res.status(status).json({
    success: false,
    message,
    data: null
  })})
export default serverTest
EOL