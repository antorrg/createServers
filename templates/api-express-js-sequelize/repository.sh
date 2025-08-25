#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el repositorio
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.js" <<EOL
import eh from '../../Configs/errorHandlers.js'
import {Op} from 'sequelize'

const throwError = eh.throwError
// Esto es lo mas parecido a una clase abstracta, no se puede instanciar, solo se puede extender.

export default class BaseRepository {
  constructor (Model, dataEmpty = null) {
    if (new.target === BaseRepository) {
      throw new Error('Cannot instantiate an abstract class')
    }
    this.Model = Model
    this.dataEmpty = dataEmpty
  }

  async create (data, uniqueField) {
    try {
      const whereClause = {}
      if (uniqueField) {
        whereClause[uniqueField] = data[uniqueField]
      }
      const existingRecord = await this.Model.findOne({ where: whereClause })

      if (existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} \${uniqueField || 'entry'} already exists\`, 400)
      }
      const newRecord = await this.Model.create( data )

      return newRecord
    } catch (error) {
      throw error
    }
  }

  async getAll (isAdmin = false) {
    const response = await this.Model.scope(isAdmin ? 'allRecords' : 'enabledOnly').findAll()
    return response
  }
  
  async getWithPagination (queryObject, isAdmin = false) {
    const { searchField = '', search = null, sortBy = 'id', order = 'DESC', page = 1, limit = 10, filters={} } = queryObject
    const offset = (page - 1) * limit
    const searchFilter = search && searchField ? { [searchField]: { [Op.iLike]: \`%\${search}%\`} } : {}
    // Combinamos filtros personalizados con búsqueda
    const whereClause = { ...filters, ...searchFilter}
    const {rows: existingRecords, count: total} = await this.Model.scope(isAdmin ? 'allRecords' : 'enabledOnly').findAndCountAll({
      limit: limit,
      offset: offset,
      where: whereClause,
      distinct:true,
      order: [[sortBy, order]]
    })
    if (existingRecords.length === 0) {
      if (this.dataEmpty) {
        existingRecords.push(this.dataEmpty)
      } else { throwError(\`This \${this.Model.name.toLowerCase()} \${searchField || 'entry'} do not exists\`, 404) }
    }

    return {
      info: {
        total,
        page,
        totalPages: Math.ceil(total / limit)
      },
      data: existingRecords
    }
  }

  async getOne (data, uniqueField, isAdmin=true) {
    try {
      const whereClause = {}
      if (uniqueField) {
        whereClause[uniqueField] = data
      }
      const existingRecord = await this.Model.scope(isAdmin ? 'allRecords' : 'enabledOnly').findOne({ where: whereClause })
      if (!existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} name do not exists\`, 404)
      }
      return existingRecord
    } catch (error) {
      throw error
    }
  };

  async getById (id) {
    try {
      const existingRecord = await this.Model.findByPk(id)
      if (!existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} name do not exists\`, 404)
      }
      return existingRecord
    } catch (error) {
      throw error
    }
  };

  async update (id, data) {
    const dataFound = await this.Model.findByPk(id)
    if (!dataFound) {
      throwError(\`\${this.Model.name} not found\`, 404)
    }
    const upData = await dataFound.update(data)
    return upData
  };

  async delete (id) {
    const dataFound = await this.Model.findByPk(id)
    if (!dataFound) {
      throwError(\`\${this.Model} not found\`, 404)
    }
    await dataFound.destroy()
    return \`\${this.Model.name} deleted successfully\`
  };
}
EOL

# Crear archivo de test para Repositories
cat > "$PROJECT_DIR/test/Shared/Repositories/BaseRepository.test.js" <<EOL
import BaseRepository from "../../../src/Shared/Repositories/BaseRepository.js";
import { User, startApp, closeDatabase } from "../../../src/Configs/database.js";
import * as info from "./helperTest.help.js";
import * as store from "../../testHelpers/testStore.help.js";

class TestClass extends BaseRepository {
  constructor (Model, dataEmpty) {
    super(Model, dataEmpty)
  }
}
// const tests = new TestClass(prisma.example) Se necesita tener al menos una tabla declarada en la DB
// const failed = new TestClass(prisma.example, info.dataEmpty)

describe('BaseRepository tests (abstract class)', () => {
  describe('Extension and instance tests', () => {
    it('should throw an error when attempting to instantiate the BaseRepository class directly.', () => {
      expect(() => new BaseRepository(User)).toThrow(Error)
      expect(() => new BaseRepository(User)).toThrow('Cannot instantiate an abstract class')
    })
    it('should inherit and instantiate the class correctly without throwing an error', () => {
      const instance = new TestClass(User)
      // Verify that the instance is of both TestClass and BaseRepository
      expect(instance).toBeInstanceOf(TestClass)
      expect(instance).toBeInstanceOf(BaseRepository)
      // Verify that the Model property was correctly assigned
      expect(instance.Model).toBe(User)
    })
  })
  describe('Unit tests for BaseRepository methods', () => {
    beforeAll(async () => {
      await startApp(true, true)
    })

    const tests = new TestClass(User)
    const failed = new TestClass(User, info.dataEmpty)

    describe('Metodo create.', () => {
      it('should create an element with the correct parameters.', async () => {
        const element = info.createData
        const uniqueField = 'email'
        const resp = await tests.create(element, uniqueField)
        const response = info.cleanData(resp)
        store.setStringId(response.id)
        expect(response).toEqual({
          id: expect.any(String),
          email: 'usuario@gmail.com',
          role: 'User',
          picture: 'https://picture.com',
          username: null,
          enabled: true,
          createdAt: expect.any(Date)
        })
      })
      it('should throw an error when trying to create the same element twice (same unique field).', async () => {
        const element = info.createData
        const uniqueField = 'email'
        try {
          await tests.create(element, uniqueField)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.message).toBe('This user email already exists')
          expect(error.status).toBe(400)
        }
      })
    })
    describe('"GET" methods: returning an array of elements or a single element', () => {
      it('"getAll" should return an array of elements', async () => {
        const resp = await tests.getAll()
        const response = resp.map(data => info.cleanData(data))
        expect(response).toEqual([
          {
            id: expect.any(String),
          email: 'usuario@gmail.com',
          role: 'User',
          picture: 'https://picture.com',
          username: null,
          enabled: true,
          createdAt: expect.any(Date)
          }
        ])
      })
      it('"getWithPagination" should return an array of elements with pagination info.', async () => {
        // const {searchField = '', search = null, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10
        const queryObject = { searchField: '', search: null, filters: {}, sortBy: 'id', order: 'desc', page: 1, limit: 10 }
        const isAdmin = false
        const resp = await tests.getWithPagination(queryObject, isAdmin)
        const response = resp.data.map(data=> info.cleanData(data))
        expect(response).toEqual([{
           id: expect.any(String),
          email: 'usuario@gmail.com',
          role: 'User',
          picture: 'https://picture.com',
          username: null,
          enabled: true,
          createdAt: expect.any(Date)
        }])
        expect(resp.info).toEqual({ page: 1, total: 1, totalPages: 1 })
      })
      it('"getById" should return an object with a single element.', async () => {
        const resp = await tests.getById(store.getStringId())
        const response = info.cleanData(resp)
        expect(response).toEqual({
             id: expect.any(String),
          email: 'usuario@gmail.com',
          role: 'User',
          picture: 'https://picture.com',
          username: null,
          enabled: true,
          createdAt: expect.any(Date)
        })
      })
      it('"getById" should throw an error if the ID is incorrect or the object is not enabled when admin is false.', async () => {
        try {
          const id = 'beb3a2a0-d0db-4b6b-966d-47f035ce5670'
          await tests.getById(id)
          throw new Error('Expect an error but nothing happened')
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.status).toBe(404)
          expect(error.message).toBe('This user name do not exists')
        }
      })
      it('"getOne" should return an object with a single element', async () => {
        const uniqueField = 'email'
        const data = 'usuario@gmail.com'
        const resp = await tests.getOne(data, uniqueField)
        const response = info.cleanData(resp)
        expect(response).toEqual({
            id: expect.any(String),
          email: 'usuario@gmail.com',
          role: 'User',
          picture: 'https://picture.com',
          username: null,
          enabled: true,
          createdAt: expect.any(Date)
        })
      })
      it('getOne" should throw an error if the search field is incorrect', async () => {
        const uniqueField = 'email'
        const data = 'landing2'
        try {
          await tests.getOne(data, uniqueField)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.status).toBe(404)
          expect(error.message).toBe('This user name do not exists')
        }
      })
    })
    describe('"update" method', () => {
      it('should update the element if parameters are correct', async () => {
        const id = store.getStringId()
        const newData = { email: 'perico@gmail.com', username: 'Perico de los palotes', enabled: false }
        const resp = await tests.update(id, newData)
        console.log(resp)
        const response = info.cleanData(resp)
        expect(response).toMatchObject(info.responseUpdData)
      })
    })
    describe('"delete" method.', () => {
      it('should delete an element', async () => {
        const id = store.getStringId()
        const response = await tests.delete(id)
        expect(response).toBe('User deleted successfully')
      })
    })
  })
})
afterAll(async () => {
  await closeDatabase()
})
EOL

cat > "$PROJECT_DIR/src/Shared/Repositories/GeneralRepository.js" <<EOL
import BaseRepository from './BaseRepository.js'

export class GeneralRepository extends BaseRepository {
  constructor (Model, dataEmpty = null) {
    super(Model, dataEmpty)
  }
}
EOL

cat > "$PROJECT_DIR/test/Shared/Repositories/helperTest.help.js" <<EOL
export const createData = {
  email: 'usuario@gmail.com',
  password: 'L1234567',
  picture: 'https://picture.com'
}
export const responseData = {
  id: expect.any(String),
  email: 'usuario@gmail.com',
  role: 'User',
  picture: 'https://picture.com',
  username: null,
  enabled: true,
  createdAt: expect.any(Date)
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

export const responseUpdData = {
  id: expect.any(String),
  email: 'perico@gmail.com',
  role: 'User',
  picture: 'https://picture.com',
  username: 'Perico de los palotes',
  enabled: false,
  createdAt: expect.any(Date)
}
export function cleanData(d) {
  return {
    id: d.id,
    email: d.email,
    role: scope(d.role),
    picture: d.picture,
    username: d.username,
    enabled: d.enabled,
    createdAt: d.createdAt
  }
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