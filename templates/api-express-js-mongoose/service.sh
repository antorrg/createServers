#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el servicio

# Crear el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.js" <<EOL
import eh from '../../Configs/errorHandlers.js'

export class BaseService {
  constructor (Repository, fieldName, uniqueField = '', parserFunction = null, useImage = false, deleteImages = null) {
    this.Repository = Repository
    this.fieldName = fieldName
    this.uniqueField = uniqueField
    this.useImage = useImage
    this.deleteImages = deleteImages
    this.parserFunction = parserFunction
  }

  async handleImageDeletion (imageUrl) {
    if (this.useImage && imageUrl) {
      await this.deleteImages(imageUrl)
    }
  }

  async create (data) {
    try {
      const newRecord = await this.Repository.create(data, this.uniqueField)
      return {
        message: \`\${this.fieldName} \${data[this.uniqueField]} created successfully\`,
        results: this.parserFunction ? this.parserFunction(newRecord) : newRecord
      }
    } catch (error) {
      eh.processError(error, \`Create Service: \${this.fieldName} error\`)
    }
  }

  async getAll (isAdmin = false) {
    try {
      const response = await this.Repository.getAll(isAdmin)

      const dataParsed = this.parserFunction ? response.map(dat => this.parserFunction(dat)) : response
      return {
        message: \`\${this.fieldName}s found successfully\`,
        results: dataParsed
      }
    } catch (error) {
      eh.processError(error, \`Get Service: \${this.fieldName} error\`)
    }
  }

  // searchField = '', search = null, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10

  async getWithPagination (queryObject, isAdmin = false) {
    try {
      const response = await this.Repository.getWithPagination(queryObject, isAdmin)
      const dataParsed = this.parserFunction ? response.data.map(dat => this.parserFunction(dat)) : response.data
      return {
        message: \`\${this.fieldName}s found successfully\`,
        results: {
          info: response.info,
          data: dataParsed
        }
      }
    } catch (error) {
      eh.processError(error, \`Get Service: \${this.fieldName} error\`)
    }
  }

  async getById (id) {
    try {
      const response = await this.Repository.getById(id)
      const dataParsed = this.parserFunction ? this.parserFunction(response) : response
      return {
        message: \`\${this.fieldName} found successfully\`,
        results: dataParsed
      }
    } catch (error) {
      eh.processError(error, \`Get Service: \${this.fieldName} error\`)
    }
  }

  async update (id, newData) {
    try {
      let imageUrl = ''
      let deleteImg = false
      const dataFound = await this.Repository.getById(id)

      if (this.useImage && dataFound.picture && dataFound.picture !== newData.picture) {
        imageUrl = dataFound.picture
        deleteImg = true
      }

      const upData = await this.Repository.update(id, newData)

      if (deleteImg) {
        await this.handleImageDeletion(imageUrl)
      }

      return {
        message: \`\${this.fieldName} updated successfully\`,
        results: this.parserFunction ? this.parserFunction(upData) : upData
      }
    } catch (error) {
      eh.processError(error, \`Update Service: \${this.fieldName} error\`)
    }
  }

  async delete (id) {
    let imageUrl = ''
    try {
      const dataFound = await this.Repository.getById(id)
      const dataReg = dataFound[this.uniqueField]
      this.useImage ? imageUrl = dataFound.picture : ''

      await this.Repository.delete(id)

      await this.handleImageDeletion(imageUrl)

      return { message: \`\${this.fieldName} deleted successfully\`, results: \`\${this.fieldName} deleted: \${dataReg}\` }
    } catch (error) {
      eh.processError(error, \`Delete Service: \${this.fieldName} error\`)
    }
  }
}
EOL
# Crear el  test para el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.test.js" <<EOL
import BaseRepository from '../Repositories/BaseRepository.js'
import { startApp, closeDatabase } from '../../Configs/database.js'
import User from '../../../models/user.js'
import { BaseService } from './BaseService.js'
import * as fns from '../../../test/generalFunctions.js'
import * as store from '../../../test/testHelpers/testStore.help.js'

const dataEmptyExample = {
  id: 'none',
  email: 'no data yet',
  username: 'no data yet',
  password: 'no data yet',
  role: 'no data yet',
  picture: 'no data yet',
  enabled: true,
  createdAt: 'no data yet'
}
class TestClass extends BaseRepository {
  constructor (Model, dataEmpty) {
    super(Model, dataEmpty)
  }
}

describe('Unit tests for the GeneralService class: CRUD.', () => {
  beforeAll(async () => {
    await startApp(true)
  })

  const testing = new TestClass(User, dataEmptyExample)

  // repository, fieldName(string), uniqueField(string), parserFunction(function), useImage(boolean), deleteImages(function)
  const serv = new BaseService(testing, 'User', 'email', null, true, fns.deletFunctionFalse)
  const servParse = new BaseService(testing, 'User', 'email', cleanData, true, fns.deletFunctionTrue)
  describe('The "create" method to create a service', () => {
    it('should create an element with the correct parameters', async () => {
      const element = {
        email: 'usuario@gmail.com',
        password: 'L1234567',
        picture: 'https://picture.com'
      }
      const response = await servParse.create(element)
      store.setStringId(response.results.id)
      expect(response.results).toMatchObject({
        id: expect.any(String),
        email: 'usuario@gmail.com',
        role: 'User',
        picture: 'https://picture.com',
        username: null,
        enabled: true,
        createdAt: expect.any(Date)
      })
    })
    it('should throw an error when trying to create the same element twice (error handling)', async () => {
      const element = {
        email: 'usuario@gmail.com',
        password: 'L1234567',
        picture: 'https://picture.com'
      }
      try {
        await servParse.create(element)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.message).toBe('This user email already exist')
        expect(error.status).toBe(400)
      }
    })
  })
  describe('"GET" methods. Return services or a single service.', () => {
    it('"getAll" method: should return an array with the services', async () => {
      const response = await servParse.getAll()
      // console.log('response get: ', [response])
      expect(response.message).toBe('Users found successfully')
      expect(response.results).toEqual([{
        id: expect.any(String),
        email: 'usuario@gmail.com',
        role: 'User',
        picture: 'https://picture.com',
        username: null,
        enabled: true,
        createdAt: expect.any(Date)
      }])
    })
  })
  describe('"update" method. Removal of old images from storage.', () => {
    it('should update the elements and not delete images', async () => {
      const id = store.getStringId()
      const newData = { username: 'perico de los palotes' }
      const response = await servParse.update(id, newData)
      expect(response.message).toBe('User updated successfully')
      expect(response.results).toMatchObject({
        id: expect.any(String),
        email: 'usuario@gmail.com',
        role: 'User',
        picture: 'https://picture.com',
        username: 'perico de los palotes',
        enabled: true,
        createdAt: expect.any(Date)
      })
    })
    it('should update the elements and handle image deletion', async () => {
      const id = store.getStringId()
      const newData = { picture: 'https://imagen.com.ar' }
      const response = await servParse.update(id, newData)
      expect(response.message).toBe('User updated successfully')
      expect(response.results).toMatchObject({
        id: expect.any(String),
        email: 'usuario@gmail.com',
        role: 'User',
        picture: 'https://imagen.com.ar',
        username: 'perico de los palotes',
        enabled: true,
        createdAt: expect.any(Date)
      })
    })
    it('should throw an error if image deletion fails', async () => {
      const id = store.getStringId()
      const newData = { picture: 'https://imagen22.com.ar' }
      try {
        await serv.update(id, newData)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error processing ImageUrl: https://imagen.com.ar')
      }
    })
  })
  describe('"delete" method.', () => {
    it('should delete an element', async () => {
      const element = { email: 'segundo@gmail.com', password: 'L1234567', picture: 'https://picture.com' }
      const secondElement = await serv.create(element)
      store.setNumberId(secondElement.results.id)
      const id = store.getStringId()
      const response = await servParse.delete(id)
      expect(response.message).toBe('User deleted successfully')
      expect(response.results).toBe('User deleted: usuario@gmail.com')
    })
    it('should throw an error if image deletion fails', async () => {
      const id = store.getNumberId()
      try {
        await serv.delete(id)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error processing ImageUrl: https://picture.com')
      }
    })
  })
})
afterAll(async () => {
  await closeDatabase()
})
function cleanData(d) {
  return {
    id: d._id.toString(),
    email: d.email,
    role: scope(d.role),
    picture: d.picture,
    username: d.username ||null,
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