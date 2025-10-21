#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

#Crear archivo de integration test para user

cat > "$PROJECT_DIR/test/User.int.test.ts" <<EOL
import app from '../src/app.js'
import session from 'supertest'
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { startUp, closeDatabase } from '../src/Configs/database.js'
import { setTokens } from './testHelpers/validationHelper.help.js'
import * as store from './testHelpers/testStore.help.js'
const agent = session(app)

describe('INTEGRATION TEST - "/api/v1/user"', () => {
  beforeAll(async () => {
    await startUp(true, true)
  })
  afterAll(async () => {
    await closeDatabase()
  })
  describe('POST /create', () => {
    it('should create an user with the correct parameters', async () => {
      const data = { email: 'josenomeacuerdo@gmail.com', password: 'L1234567' }
      const response = await agent
        .post('/api/v1/user/create')
        .send(data)
        .set('Authorization', \`Bearer \${store.getAdminToken()}\`)
        .expect('Content-Type', /json/)
        .expect(201)
      expect(response.body.message).toBe('User josenomeacuerdo@gmail.com created successfully')
      expect(response.body.results).toMatchObject({
        id: expect.any(String),
        email: 'josenomeacuerdo@gmail.com',
        nickname: 'josenomeacuerdo',
        picture: 'https://urlimageprueba.net',
        name: null,
        enabled: true
      })
      store.setStringId(response.body.results.id)
    })
    it('should throw an error when attempting to create the same user twice (error handling)', async () => {
      const data = { email: 'josenomeacuerdo@gmail.com', password: 'L1234567' }
      const response = await agent
        .post('/api/v1/user/create')
        .send(data)
        .set('Authorization', \`Bearer \${store.getAdminToken()}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toEqual({ data: null, message: 'User with email josenomeacuerdo@gmail.com already exists', success: false })
    })
  })
  describe('GET /', () => {
    it('should retrieve an array with users', async () => {
      const response = await agent
        .get('/api/v1/user')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('User records retrieved successfully')
      expect(response.body.results).toEqual([{
        id: expect.any(String),
        email: 'josenomeacuerdo@gmail.com',
        name: null,
        nickname: 'josenomeacuerdo',
        picture: 'https://urlimageprueba.net',
        enabled: true
      }])
    })
  })
  describe('GET /:id', () => {
    it('should retrieve an user', async () => {
      const response = await agent
        .get(\`/api/v1/user/\${store.getStringId()}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('User record retrieved successfully')
      expect(response.body.results).toEqual({
        id: expect.any(String),
        email: 'josenomeacuerdo@gmail.com',
        name: null,
        nickname: 'josenomeacuerdo',
        picture: 'https://urlimageprueba.net',
        enabled: true
      })
    })
  })
  describe('GET /pages', () => {
    it('should retrieve an array with users and pagination info', async () => {
      const response = await agent
        .get('/api/v1/user/pages')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('Total records: 1. Users retrieved successfully')
      expect(response.body.info).toEqual({
        limit: 10,
        page: 1,
        total: 1,
        totalPages: 1
      })
      expect(response.body.results).toEqual([{
        id: expect.any(String),
        email: 'josenomeacuerdo@gmail.com',
        name: null,
        nickname: 'josenomeacuerdo',
        picture: 'https://urlimageprueba.net',
        enabled: true
      }])
    })
  })
})
EOL
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

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