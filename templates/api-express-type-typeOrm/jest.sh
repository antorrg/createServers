#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo jest.setup.ts
cat > "$PROJECT_DIR/test/jest.setup.ts" <<EOL
import mongoose from 'mongoose'
import connectDB from '../src/Configs/database.js'
import { beforeAll, afterAll } from '@jest/globals'

import Test from './testHelpers/modelTest.help.js'

// Inicializa la base de datos de MongoDB antes de las pruebas
async function initializeDatabase () {
  try {
    await connectDB()
    // Asegurarse de empezar en una BD vacía
    await mongoose.connection.dropDatabase()
    // Asegura que se creen los índices
    // await Test.syncIndexes()
    console.log('Índices sincronizados')
    console.log('Base de datos MongoDB inicializada correctamente ✔️')
  } catch (error) {
    console.error('Error inicializando DB MongoDB ❌', error)
  }
}

// Resetea la base de datos antes de cada prueba si es necesario
export async function resetDatabase () {
  try {
    if (mongoose.connection.db == null) {
      throw new Error('La conexión a la base de datos no está lista')
    }
    const collections = await mongoose.connection.db.collections()
    for (const coll of collections) {
      const count = await coll.countDocuments()
      console.log(\`🗃️ antes del reset: \${coll.collectionName}: \${count || 0} documentos\`)
    }
    await mongoose.connection.dropDatabase()
    console.log(\`🔍 Total de colecciones después del drop: \${collections.length}\`)
    console.log('Base de datos MongoDB reseteada ✔️')
  } catch (error) {
    console.error('Error reseteando MongoDB ❌', error)
  }
}

beforeAll(async () => {
  await initializeDatabase()
})

// afterEach(async () => {
//   // Opcional: limpiar tras cada test unitario
//   await resetDatabase();
// });

afterAll(async () => {
  try {
    await mongoose.disconnect()
    console.log('Conexión MongoDB cerrada ✔️')
  } catch (error) {
    console.error('Error cerrando conexión MongoDB ❌', error)
  }
})
EOL

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

#Crear archivo de integration test para user
cat > "$PROJECT_DIR/test/User.int.test.ts" <<EOL
import app from '../src/app.js'
import session from 'supertest'
import { resetDatabase } from './jest.setup.js'
const agent = session(app)
import { setTokens } from './testHelpers/validationHelper.help.js'
import {getAdminToken, setAdminToken} from './testHelpers/testStore.help.js'

describe('Integration test. Route Tests: "User"', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('Login method', () => {
        it('should authenticate the user and return a message, user data, and a token', async () => {
          await setTokens()
          const data = { email:'josenomeacuerdo@hotmail.com', password:'L1234567'}
          const response = await agent
                  .post('/api/v1/user/login')
                  .send(data)
                  .expect('Content-Type', /json/)
                  .expect(200);
          expect(response.body.success).toBe(true)
          expect(response.body.message).toBe('Login successfully')
          expect(response.body.results.user).toMatchObject({
          id: expect.any(String) as string,
          email: 'josenomeacuerdo@hotmail.com',
          nickname: 'josenomeacuerdo',
          picture: 'https://urlimageprueba.net',
          name: '',
          surname: '',
          country: '',
          role: 'User',
          isVerify: false,
          isRoot: true,
          enabled: true
        })
          expect(response.body.results.token).toBeDefined()
          expect(typeof response.body.results.token).toBe('string')
          expect(response.body.results.token).not.toBe('')
          setAdminToken(response.body.results.token)
        })
        it('"should throw an error in correct format if the password is incorrect"', async () => {
    
          const data = { email:'josenomeacuerdo@hotmail.com', password:'L123458867'}
          const response = await agent
                  .post('/api/v1/user/login')
                  .send(data)
                  .expect('Content-Type', /json/)
                  .expect(400);
          expect(response.body.success).toBe(false)
          expect(response.body.message).toBe('Invalid password')
          expect(response.body.data).toBe(null)
    
        })
        it('"should throw an error in correct format if the password is invalid (error middleware)"', async () => {
    
          const data = { email:'josenomeacuerdo@hotmail.com', password:'L123'}
          const response = await agent
                  .post('/api/v1/user/login')
                  .send(data)
                  .expect('Content-Type', /json/)
                  .expect(400);
          expect(response.body.success).toBe(false)
          expect(response.body.message).toBe('Invalid password format! Enter a valid password')
          expect(response.body.data).toBe(null)
    
        })
  })
  describe('Create method', () => {
    it('should create an user with the correct parameters', async () => {
      const data = { email: 'josenomeacuerdo@gmail.com', password: 'L1234567' }
      const response = await agent
        .post('/api/v1/user/create')
        .send(data)
        .set('Authorization', \`Bearer \${getAdminToken()}\`)
        .expect('Content-Type', /json/)
        .expect(201)
      expect(response.body.message).toBe('User created successfully')
      expect(response.body.results).toMatchObject({
        id: expect.any(String),
        email: 'josenomeacuerdo@gmail.com',
        nickname: 'josenomeacuerdo',
        picture: 'https://urlimageprueba.net',
        name: '',
        surname: '',
        country: '',
        role: 'User',
        isVerify: false,
        isRoot: false,
        enabled: true
      })
    })
    it('should throw an error when attempting to create the same user twice (error handling)', async () => {
      const data = { email: 'josenomeacuerdo@gmail.com', password: 'L1234567' }
      const response = await agent
        .post('/api/v1/user/create')
        .send(data)
        .set('Authorization', \`Bearer \${getAdminToken()}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toEqual({ data: null, message: 'This email already exists', success: false })
    })
  })
})
EOL
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# Crear el archivo userIntHelp.help.ts
cat > "$PROJECT_DIR/test/testHelpers/userIntHelp.help.ts" <<EOL
export const userCreated = {
  id: expect.any(String),
  email: 'josenomeacuerdo@gmail.com',
  nickname: 'josenomeacuerdo',
  picture: 'https://urlimageprueba.net',
  name: '',
  surname: '',
  country: '',
  role: 'User',
  isVerify: false,
  isRoot: false,
  enabled: true
}
EOL

#crear validationHelp 
cat > "$PROJECT_DIR/test/testHelpers/validationHelper.help.ts" <<'EOL'
import {userService} from '../../src/Features/user/user.route.js'
import {setAdminToken, setUserToken,} from './testStore.help.js'

//* Por causa de los métodos de creación (con usuario preexistente) el usuario debe crearse antes.

export const admin = {email:'josenomeacuerdo@hotmail.com', password:'L1234567', role: 9, isRoot: true, }

export const user = {email:'juangarcia@gmail.com', password:'L1234567', role: 1, isRoot: false}


export const setTokens = async () => {
    try {
        // Crear los usuarios si no existen
        await Promise.all([userService.create(admin), userService.create(user)]);

        // Iniciar sesión y almacenar los tokens
        const [adminToken, userToken] = await Promise.all([
            userService.login(admin),
            userService.login(user)
        ]);

        // Guardar los tokens en el almacenamiento de pruebas
        setAdminToken(adminToken.results.token); // Asume que esto guarda el token admin
        setUserToken(userToken.results.token); // Asume que esto guarda el token user
        console.log('todo ok')
    } catch (error) {
        console.error('Error al configurar los tokens:', error);
        throw error;
    }
};
EOL