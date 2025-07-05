#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el servicio

# Crear el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.js" <<EOL
import eh from '../../Configs/errorHandlers.js'
const throwError = eh.throwError


export class BaseService {
  constructor (Repository, fieldName,  parserFunction = null, useImage = false, deleteImages = null) {
    this.Repository = Repository
    this.fieldName = fieldName
    this.useImage = useImage
    this.deleteImages = deleteImages
    this.parserFunction = parserFunction
  }

  // clearCache () {
  //   cache.del(\`\${this.Repository.name.toLowerCase()}\`)
  // }

  async handleImageDeletion (imageUrl) {
    if (this.useImage && imageUrl) {
      await this.deleteImages(imageUrl)
    }
  }

  async create (data, uniqueField = null) {
    try {
      const newRecord = await this.Repository.create(data, uniqueField)

      //if (this.useCache) this.clearCache()
      return newRecord
    } catch (error) {
      throw error
    }
  }

  //searchField = '', search = null, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10

  async getAll (queryObject, isAdmin = false,) {
  
    const response = await this.Repository.getAll(queryObject)
    const dataParsed = isAdmin ? response.data : response.data.map(dat => this.parserFunction(dat))
    return {
     info: response.info,
    data: dataParsed,
    }
  }

  async getById (id, isAdmin = false) {
    const data = await this.Repository.getById(id, isAdmin)

    return isAdmin ? data : this.parserFunction(data)
  }

  async update (id, newData) {
    // console.log('soy el id en el service : ', id)
    // console.log('soy newData en el service : ', newData)

    let imageUrl = ''
    let deleteImg = false

    const dataFound = await this.Repository.getById(id, newData)

    if (this.useImage && dataFound.picture && dataFound.picture !== newData.picture) {
      imageUrl = dataFound.picture
      deleteImg = true
    }

    const upData = await this.Repository.update(id, newData)

    if (deleteImg) {
      await this.handleImageDeletion(imageUrl)
    }

    /*if (this.useCache) this.clearCache()*/
    return {
      message: \`\${this.fieldName} updated successfully\`,
      data: upData
    }
  }

  async delete (id) {
    let imageUrl = ''
    try {
      const dataFound = await this.Repository.getById(id)
      const dataReg = dataFound[this.fieldName]
      this.useImage ? imageUrl = dataFound.picture : ''

      await this.Repository.delete(id)

      await this.handleImageDeletion(imageUrl)

     /* if (this.useCache) this.clearCache()*/
      return { message: \`\${this.fieldName} deleted successfully\`, data: null}
    } catch (error) {
      throw error
    }
  }
}
EOL
# Crear el  test para el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.test.js" <<EOL
import {BaseRepository} from '../Repositories/BaseRepository.js'
import {BaseService} from './BaseService.js'
import { Landing } from '../../src/Configs/database.js'
import * as info from '../Repositories/helpers/baseRep.js'
import * as fns from '../helperTest/generalFunctions.js'

class TestClass extends BaseRepository {
  constructor (Model) {
    super(Model)
  }
}
const testing = new TestClass(Landing)

// repository, fieldName(string), cache(boolean), parserFunction(function), useImage(boolean), deleteImages(function)
const serv = new GeneralService(testing, 'Landing', null, true, fns.deletFunctionFalse)
const servCache = new GeneralService(testing, 'Landing', info.cleanData, false, fns.deletFunctionTrue)
const servParse = new GeneralService(testing, 'Landing', info.cleanData, true, fns.deletFunctionTrue)

describe('Test unitarios de la clase GeneralService: CRUD.', () => {
  describe('El metodo "create" para crear un servicio', () => {
    it('deberia crear un elemento con los parametros correctos', async () => {
      const element = info.createData // data, uniqueField=null, parserFunction=null, isAdmin = false
      const response = await servParse.create(element, 'name')
      expect(response).toMatchObject(info.responseData)
    })
    it('deberia arrojar un error al intentar crear dos veces el mismo elemento (manejo de errores)', async () => {
      const element = { name: 'Landing1' }
      try {
        await servParse.create(element)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.message).toBe('This landing entry already exists')
        expect(error.status).toBe(400)
      }
    })
  })
  describe('Metodos "GET". Retornar servicios o un servicio.', () => {
    it('Metodo "getAll": deberia retornar un arreglo con los servicios', async () => {
      const response = await servParse.getAll()
      //console.log('A ver el get', response)
      expect(response.data).toEqual([info.responseData])
      
    })
   
  })
  describe('Metodo "update". Eliminacion de imagenes viejas del storage.', () => {
    it('deberia actualizar los elementos y no eliminar imagenes', async () => {
      const id = 1
      const newData = info.responseData
      const response = await servParse.update(id, newData)
      expect(response.message).toBe('Landing updated successfully')
      expect(response.data).toMatchObject(info.responseData)
    })
    it('deberia actualizar los elementos y gestionar eliminacion de imagenes', async () => {
      const id = 1
      const newData = { picture: 'https://imagen.com.ar' }
      const response = await servParse.update(id, newData)
      expect(response.message).toBe('Landing updated successfully')
      expect(response.data).toMatchObject(info.responseDataImg)
    })
    it('deberia arrojar un error si falla la eliminacion de imagenes', async () => {
      const id = 1
      const newData = info.responseData
      try {
        await serv.update(id, newData)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error processing ImageUrl: https://imagen.com.ar')
      }
    })
  })
  describe('Metodo "delete".', () => {
    it('deberia borrar un elemento', async () => {
      const element = info.createSecondData
      await serv.create(element, 'name')
      const id = 1
      const response = await servParse.delete(id)
      expect(response.message).toBe('Landing deleted successfully')
    })
    it('deberia arrojar un error si falla la eliminacion de imagenes', async () => {
      const id = 2
      try {
        await serv.delete(id)
      } catch (error) {
        expect(error).toBeInstanceOf(Error)
        expect(error.status).toBe(500)
        expect(error.message).toBe('Error processing ImageUrl: https://picture.com.ar')
      }
    })
  })
})
EOL