#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear la funcion de queries:
cat > "$PROJECT_DIR/src/Shared/Controllers/queryHelper.js" <<EOL
// const {searchField = '', search = null, filters = {}, sortBy = 'id', order = 'DESC', page = 1, limit = 10
export function queryHelper (queries) {
  const { page, limit, orderBy, order, searchField, search } = queries
  // Este es un ejemplo generico a fin de levantar la app.
  const parseSearch = (str) => {
    if (str === 'null' || str === '') return null
    return str
  }

  return {
    searchField,
    search: parseSearch(search),
    sortBy: orderBy,
    order,
    page,
    limit
  }
}
EOL
cat > "$PROJECT_DIR/test/User.spec.js" <<EOL
import session from 'supertest'
import app from '../src/app.js'
import { User, startApp, closeDatabase } from '../src/Configs/database.js'
import * as store from './testHelpers/testStore.help.js'
import { users } from './testHelpers/User-helpers/users.js'
const agent = session(app)

describe('User, Integration test', () => {
  beforeAll(async () => {
    await startApp(true, true)
  })
  describe('Route "/api/v1/user/create" POST', () => {
    it('should create one user', async () => {
      const data = {
        email: 'usuario@gmail.com',
        password: 'L1234567',
        picture: 'https://picture.com'
      }
      const test = await agent
        .post('/api/v1/user/create')
        .send(data)
        .expect(201)
      expect(test.body.success).toBe(true)
      expect(test.body.message).toBe('User usuario@gmail.com created successfully')
      expect(test.body.results).toEqual({
        id: expect.any(String),
        email: 'usuario@gmail.com',
        role: 'User',
        picture: 'https://picture.com',
        username: null,
        enabled: true,
        createdAt: expect.any(String)
      })
      store.setStringId(test.body.results.id)
    })
  })
  describe('Route "/api/v1/user/"GET', () => {
    it('should retrieve an array of users "getAll"', async () => {
      const response = await agent
        .get('/api/v1/user')
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('Users found successfully')
      expect(response.body.results).toEqual([
        {
          id: expect.any(String),
          email: 'usuario@gmail.com',
          role: 'User',
          picture: 'https://picture.com',
          username: null,
          enabled: true,
          createdAt: expect.any(String)
        }
      ])
    })
    it('should retrieve an array of users "getWithPagination" by filter', async () => {
      const usersCreated = await User.bulkCreate(users)
      console.log(usersCreated.length)
      const response = await agent
        .get('/api/v1/user/pages?page=1&limit=4&sortBy=email&order=asc&searchField=email&search=Sincere@april.biz')
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('Users found successfully')
      expect(response.body.results.info).toEqual({ total: 1, page: 1, totalPages: 1 })
      expect(response.body.results.data.length).toBe(1)
      expect(response.body.results.data).toEqual([
        {
          id: expect.any(String),
          email: 'Sincere@april.biz',
          role: 'User',
          picture: 'abs@gmail.com',
          username: 'Bret',
          enabled: true,
          createdAt: expect.any(String)
        }
      ])
    })
    it('should retrieve an array of users "getWithPagination" without filter', async () => {
      const response = await agent
        .get('/api/v1/user/pages?page=1&limit=10')
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('Users found successfully')
      expect(response.body.results.info).toEqual({ total: 11, page: 1, totalPages: 2 })
      expect(response.body.results.data.length).toBe(10)
    })
    it('should retrieve an user "getById"', async () => {
      const response = await agent
        .get(\`/api/v1/user/\${store.getStringId()}\`)
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('User found successfully')
      expect(response.body.results).toEqual({
        id: expect.any(String),
        email: 'usuario@gmail.com',
        role: 'User',
        picture: 'https://picture.com',
        username: null,
        enabled: true,
        createdAt: expect.any(String)
      })
    })
  })
  describe('Route "/api/v1/user/:id" PUT', () => {
    it('should update an user', async () => {
      const newData = {
        email: 'usuario@gmail.com',
        password: 'L1234567',
        picture: 'https://picture.com',
        username: 'usuario actualizado',
        enabled: true
      }
      const response = await agent
        .put(\`/api/v1/user/\${store.getStringId()}\`)
        .send(newData)
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('User updated successfully')
      expect(response.body.results).toEqual({
        id: expect.any(String),
        email: 'usuario@gmail.com',
        role: 'User',
        picture: 'https://picture.com',
        username: 'usuario actualizado',
        enabled: true,
        createdAt: expect.any(String)
      })
    })
    it('should throw an error if parameters are incorrect', async () => {
      const newData = {
        email: 'usuario@gmail.com',
        password: 'L1234567',
        picture: 'https://picture.com',
        username: 'usuario actualizado',
        enable: true
      }
      const response = await agent
        .put(\`/api/v1/user/\${store.getStringId()}\`)
        .send(newData)
        .expect(400)
      expect(response.body.success).toBe(false)
      expect(response.body.message).toBe('Missing field: enabled at enabled')
      expect(response.body.results).toBe(null)
    })
  })
  describe('Route "/api/v1/user/create" DELETE', () => {
    it('should delete an user', async () => {
      const response = await agent
        .delete(\`/api/v1/user/\${store.getStringId()}\`)
        .expect(200)
      expect(response.body.success).toBe(true)
      expect(response.body.message).toBe('User deleted successfully')
      expect(response.body.results).toBe('User deleted: usuario@gmail.com')
    })
  })
  afterAll(async () => {
    await closeDatabase()
  })
})
EOL