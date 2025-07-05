#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el repositorio
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.js" <<EOL
import eh from '../../Configs/errorHandlers.js'

const throwError = eh.throwError
// Esto es lo mas parecido a una clase abstracta, no se puede instanciar, solo se puede extender.

export default class BaseRepository {
  constructor (Model, dataEmpty = null) {
    if (new.target === BaseRepository) {
      throw new Error('No se puede instanciar una clase abstracta.')
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
      const existingRecord = await this.Model.findUnique({ where: whereClause })

      if (existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} \${uniqueField || 'entry'} already exists\`, 400)
      }
      const newRecord = await this.Model.create({ data })

      return newRecord
    } catch (error) {
      throw error
    }
  }

  async getAll (searchField = '', search = null, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10) {
    const offset = (page - 1) * limit
    // Construimos el filtro de búsqueda
    const searchFilter = search ? { [searchField]: { contains: search, mode: 'insensitive' } } : {}
    // Combinamos filtros personalizados con búsqueda
    const where = { ...searchFilter, ...filters }
    const existingRecords = await this.Model.findMany({
      where,
      orderBy: { [sortBy]: order },
      skip: offset,
      take: limit
    })
    if (existingRecords.length === 0) {
      if (this.dataEmpty) {
        existingRecords.push(this.dataEmpty)
      } else { throwError(\`This \${this.Model.name.toLowerCase()} \${searchField || 'entry'} do not exists\`, 404) }
    }

    // Contamos el total de registros
    const total = await this.Model.count({ where })

    return {
      info: {
        total,
        page,
        totalPages: Math.ceil(total / limit)
      },
      data: existingRecords
    }
  }

  async getOne (data, uniqueField) {
    try {
      const whereClause = {}
      if (uniqueField) {
        whereClause[uniqueField] = data
      }
      const existingRecord = await this.Model.findUnique({ where: whereClause })
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
      const existingRecord = await this.Model.findUnique({ where: { id } })
      if (!existingRecord) {
        throwError(\`This \${this.Model.name.toLowerCase()} name do not exists\`, 404)
      }
      return existingRecord
    } catch (error) {
      throw error
    }
  };

  async update (id, data) {
    const dataFound = await this.Model.findUnique({ where: { id } })
    if (!dataFound) {
      throwError(\`\${this.Model.name} not found\`, 404)
    }
    const upData = await this.Model.update({
      where: { id: parseInt(id) },
      data
    })
    return upData
  };

  async delete (id) {
    const dataFound = await this.Model.findUnique({ where: { id } })
    if (!dataFound) {
      throwError(\`\${this.Model} not found\`, 404)
    }
    await this.Model.delete({
      where: { id: parseInt(id) }
    })
    return \`\${this.Model.name} deleted successfully\`
  };
}
EOL

# Crear archivo de test para Repositories
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.test.js" <<EOL
import BaseRepository from './BaseRepository.js'
import { prisma } from '../../src/Configs/database.js'
import * as info from './helpers/baseRep.js'

class TestClass extends BaseRepository {
  constructor (Model, dataEmpty) {
    super(Model, dataEmpty)
  }
}
//const tests = new TestClass(prisma.example) Se necesita tener al menos una tabla declarada en la DB
//const failed = new TestClass(prisma.example, info.dataEmpty)

describe('BaseRepository tests (abstract class)', () => {
  describe('Test de extension e instancias', () => {
    it('Deberia arrojar un error al intentar instanciar la clase BaseRepository.', () => {
      expect(() => new BaseRepository(prisma.landing)).toThrow(Error)
      expect(() => new BaseRepository(prisma.landing)).toThrow('No se puede instanciar una clase abstracta.')
    })
    it('debería heredar e instanciar correctamente la clase sin lanzar error', () => {
      const instance = new TestClass(prisma.landing)
      // Verifica que la instancia sea de TestClass y de BaseRepository
      expect(instance).toBeInstanceOf(TestClass)
      expect(instance).toBeInstanceOf(BaseRepository)
      // Verifica que la propiedad Model se asignó correctamente
      expect(instance.Model).toBe(prisma.landing)
    })
  })
  xdescribe('Tests unitarios. Metodos de BaseRepository', () => {
    describe('Metodo create.', () => {
      it('Deberia crear un elemento con los parametros correctos.', async () => {
        const element = info.createData
        const uniqueField = 'title'
        const response = await tests.create(element, uniqueField)
        const responseCleaned = info.cleanData(response)
        expect(responseCleaned).toEqual(info.responseData)
      })
      it('Deberia arrojar un error al intentar crear el mismo elemento dos veces (mismo nombre).', async () => {
        const element = info.createData
        const uniqueField = 'title'
        try {
          await tests.create(element, uniqueField)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.message).toBe('This landing title already exists')
          expect(error.status).toBe(400)
        }
      })
    })
    describe('Metodos GET, retornando un arreglo de elementos o un elemento.', () => {
      it('Metodo "getAll": deberia retornar un arreglo de elementos.', async () => {
        //, { search, filters = {}, sortBy = 'id', order = 'desc', page = 1, limit = 10 }
        const response = await tests.getAll('title')
        console.log('A ver el get', response)
        const finalRes = response.data.map(info.cleanData)
        expect(finalRes).toEqual([info.responseData])
        expect(response.info).toEqual({ page: 1, total: 1, totalPages: 1 })
      })
      it('Metodo "getAll": deberia retornar un arreglo simbólico si no hubiera elementos en la base de datos.', async () => {
        const response = await failed.getAll('name')
        const finalRes = response.data.map(info.cleanData)
        expect(finalRes).toEqual([info.dataEmpty])
      })
      it('Metodo "getAll": deberia arrojar un error si no existe el objeto simbolico.', async () => {
        try {
          await failed.getAll('name')
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.message).toBe('This genre name do not exists')
          expect(error.status).toBe(404)
        }
      })
      it('Metodo "getById": deberia retornar un objeto con un elemento.', async () => {
        const id = 1
        const response = await tests.getById(id)
        const finalRes = info.cleanData(response)
        expect(finalRes).toEqual(info.responseData)
      })
      it('Metodo "getById": deberia arrojar un error si el id es incorrecto o el objeto no es enable true con admin en false.', async () => {
        const id = 2
        try {
          await tests.getById(id)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.status).toBe(404)
          expect(error.message).toBe('This landing name do not exists')
        }
      })
      it('Metodo "getOne": deberia retornar un objeto con un elemento.', async () => {
        const uniqueField = 'title'
        const data = 'Titulo de la landing'
        const response = await tests.getOne(data, uniqueField)
        const finalRes = info.cleanData(response)
        expect(finalRes).toEqual(info.responseData)
      })
      it('Metodo "getOne": deberia arrojar un error si el campo de busqueda es incorrecto o el objeto no es enable true con admin en false.', async () => {
        const uniqueField = 'title'
        const data = 'landing2'
        try {
          await tests.getOne(data, uniqueField)
        } catch (error) {
          expect(error).toBeInstanceOf(Error)
          expect(error.status).toBe(404)
          expect(error.message).toBe('This landing name do not exists')
        }
      })
    })
    describe('Metodo "update', () => {
      it('Deberia actualizar el elemento si los parametros son correctos.', async () => {
        const id = 1
        const newData = { id, title: 'landing3', enable: true }
        const response = await tests.update(id, newData)
        const responseJs = info.cleanData(response)
        expect(responseJs).toMatchObject(info.responseUpdData)
      })
    })
    describe('Metodo "delete".', () => {
      it('Deberia borrar un elemento', async () => {
        const id = 1
        const response = await tests.delete(id)
        expect(response).toBe('Landing deleted successfully')
      })
    })
  })
})
EOL