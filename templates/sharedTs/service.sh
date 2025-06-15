#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el servicio
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.ts" <<EOL
import { Document } from 'mongoose'
import { BaseRepository } from '../Repositories/BaseRepository.js'
import { deletFunctionTrue } from '../../../test/generalFunctions.js'

type ParserFunction<T> = (doc: T) => any

export class BaseService<T extends Document> {
  protected readonly repository: BaseRepository<T>
  protected readonly useImages: boolean
  protected readonly deleteImages?: typeof deletFunctionTrue
  protected readonly parserFunction?: ParserFunction<T>

  constructor (
    repository: BaseRepository<T>,
    useImages = false,
    deleteImages?: typeof deletFunctionTrue,
    parserFunction?: ParserFunction<T>
  ) {
    this.repository = repository
    this.useImages = useImages
    this.deleteImages = deleteImages
    this.parserFunction = parserFunction
  }

  async getAll () {
    const res = await this.repository.getAll()
    return {
      ...res,
      results: (this.parserFunction != null) ? res.results.map(this.parserFunction) : res.results
    }
  }

  async findWithPagination (query: any) {
    const res = await this.repository.findWithPagination(query)
    return {
      ...res,
      results: (this.parserFunction != null) ? res.results.map(this.parserFunction) : res.results
    }
  }

  async getById (id: string) {
    const res = await this.repository.getById(id)
    return {
      ...res,
      results: (this.parserFunction != null) ? this.parserFunction(res.results) : res.results
    }
  }

  async getOne<K extends keyof T>(value: T[K], field: K) {
    const res = await this.repository.getOne(value, field)
    return {
      ...res,
      results: (this.parserFunction != null) ? this.parserFunction(res.results) : res.results
    }
  }

  async create (data: Partial<T>) {
    const res = await this.repository.create(data)
    return {
      ...res,
      results: (this.parserFunction != null) ? this.parserFunction(res.results) : res.results
    }
  }

  async update (id: string, data: Partial<T>) {
    // Si usas imágenes, puedes obtener el doc anterior para borrar la imagen si es necesario
    if (this.useImages && (this.deleteImages != null)) {
      const prev = await this.repository.getById(id)
      if ((prev.results as any).picture && (data as any).picture && (prev.results as any).picture !== (data as any).picture) {
        await this.deleteImages((prev.results as any).picture)
      }
    }
    const res = await this.repository.update(id, data)
    return {
      ...res,
      results: (this.parserFunction != null) ? this.parserFunction(res.results) : res.results
    }
  }

  async delete (id: string) {
    if (this.useImages && (this.deleteImages != null)) {
      const prev = await this.repository.getById(id)
      if ((prev.results as any).picture) {
        await this.deleteImages((prev.results as any).picture)
      }
    }
    return await this.repository.delete(id)
  }
}
EOL
# Crear el  test para el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.test.ts" <<EOL
import {BaseRepository} from '../Repositories/BaseRepository.js'
import { BaseService } from './BaseService.js'
import Test, {ITest} from '../../../test/testHelpers/modelTest.help.js'
import { infoClean, resultParsedCreate, newData } from '../Repositories/testHelpers/testHelp.help.js'
import { setStringId, getStringId } from '../../../test/testHelpers/testStore.help.js'
import mongoose from 'mongoose'
import { deletFunctionTrue, deletFunctionFalse } from '../../../test/generalFunctions.js'
import { testSeeds } from '../Repositories/testHelpers/seeds.help.js'
import { resetDatabase } from '../../../test/jest.setup.js'

/* 
    constructor(
      repository: BaseRepository<T>,
      useImages = false,
      deleteImages?: typeof deletFunctionTrue,
      parserFunction?: ParserFunction<T>
  ) */

const repository = new BaseRepository<ITest>(Test, 'Test', 'title')
const testImsSuccess = new BaseService<ITest>(repository, true, deletFunctionTrue, infoClean)
const testImgFailed = new BaseService<ITest>(repository, true, deletFunctionFalse, infoClean)
const testParsed = new BaseService<ITest>(repository, false, deletFunctionFalse, infoClean)

describe('Unit tests for the BaseService class: CRUD operations.', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('The "create" method for creating a service', () => {
    it('should create an item with the correct parameters', async () => {
      const element = { title: 'page', count: 5, picture: 'https//pepe.com' }
      const response = await testParsed.create(element)
      setStringId(response.results.id)
      expect(response.message).toBe('Test created successfully')
      expect(response.results).toEqual(resultParsedCreate)
    })
    it('should throw an error when attempting to create the same item twice (error handling)', async () => {
      const element = { title: 'page', count: 5, picture: 'https//pepe.com' }
      try {
        await testParsed.create(element)
        throw new Error('❌ Expected a duplication error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(400)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('This Test already exists')
        } else {
          throw error // Re-lanza si no es el tipo esperado
        }
      }
    })
  })
  describe('"GET" methods. Return one or multiple services..', () => {
    beforeAll(async () => {
      await Test.insertMany(testSeeds)
    })
    it('"getAll" method: should return an array of services', async () => {
      const response = await testParsed.getAll()
      expect(response.message).toBe('Test retrieved')
      expect(response.results.length).toBe(26)
    })
    it('"findWithPagination" method: should return an array of services', async () => {
      const queryObject = { page: 1, limit: 10, filters: {}, sort: {} }
      const response = await testParsed.findWithPagination(queryObject)
      expect(response.message).toBe('Test list retrieved')
      expect(response.info).toEqual({ page: 1, limit: 10, totalPages: 3, count: 10, total: 26 })
      expect(response.results.length).toBe(10)
    })
    it('"findWithPagination" method should return page 2 of results', async () => {
      const queryObject = { page: 2, limit: 10, filters: {}, sort: {} }
      const response = await testParsed.findWithPagination(queryObject)
      expect(response.results.length).toBeLessThanOrEqual(10)
      expect(response.info.page).toBe(2)
    })
    it('"findWithPagination" method should return sorted results (by title desc)', async () => {
      const queryObject = { page: 1, limit: 5, sort: { title: -1 } as Record<string, 1 | -1> }
      const response = await testParsed.findWithPagination(queryObject)
      const titles = response.results.map(r => r.title)
      const sortedTitles = [...titles].sort().reverse()
      expect(titles).toEqual(sortedTitles)
    })

    it('"getOne" method: should return an service', async () => {
      const id = getStringId()
      const response = await testParsed.getById(id)
      expect(response.results).toEqual(resultParsedCreate)
    })
    it('"getOne" should throw an error if service not exists', async () => {
      try {
        const invalidId = new mongoose.Types.ObjectId().toString()
        await testParsed.getById(invalidId)
        throw new Error('❌ Expected a "Not found" error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect((error as { status: number }).status).toBe(404)
          expect(error).toBeInstanceOf(Error)
          expect((error as { message: string }).message).toBe('Test not found')
        } else {
          throw error
        }
      }
    })
  })
  describe('The "update" method - Handles removal of old images from storage.', () => {
    it('should update the document without removing any images', async () => {
      const id = getStringId()
      const data = newData
      const response = await testParsed.update(id, data)
      expect(response.message).toBe('Test updated successfully')
      expect(response.results).toMatchObject({
        id: expect.any(String) as string,
        title: 'page',
        picture: 'https://donJose.com',
        count: 5,
        enabled: true
      })
    })
    it('should update the document and remove the previous image', async () => {
      const id = getStringId()
      const newData = { picture: 'https://imagen.com.ar' }
      const response = await testImsSuccess.update(id, newData)
      expect(response.message).toBe('Test updated successfully')
    })
    it('should throw an error if image deletion fails during update', async () => {
      const id = getStringId()
      const newData = { picture: 'https://imagen44.com.ar' }
      try {
        const resp = await testImgFailed.update(id, newData)
        throw new Error('❌ Expected a update error, but none was thrown')
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect(error).toBeInstanceOf(Error)
          expect((error as { status: number }).status).toBe(500)
          expect((error as { message: string }).message).toBe('Error processing ImageUrl: https://imagen.com.ar')
        } else {
          throw error
        }
      }
    })
  })
  describe('The "delete" method.', () => {
    it('should delete a document successfully (soft delete)', async () => {
      const id = getStringId()
      const response = await testImsSuccess.delete(id)
      expect(response.message).toBe('Test deleted successfully')
    })
    it('should throw an error if document do not exist', async () => {
      const id = getStringId()
      try {
        await testImgFailed.delete(id)
      } catch (error: unknown) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'status' in error &&
          'message' in error
        ) {
          expect(error).toBeInstanceOf(Error)
          expect((error as { status: number }).status).toBe(404)
          expect((error as { message: string }).message).toBe('Test not found')
        } else {
          throw error
        }
      }
    })
  })
})
EOL