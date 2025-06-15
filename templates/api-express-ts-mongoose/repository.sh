#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear BaseRepositories.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.ts" <<EOL
import { Model, Document, FilterQuery } from 'mongoose'
import eh from '../../Configs/errorHandlers.js'

interface Pagination {
  page?: number
  limit?: number
  filters?: Record<string, any>
}
interface ResponseWithPagination<T> {
  message: string
  results: T[]
  info: {
    totalPages: number
    total: number
    page: number
    limit: number
    count: number
  }
}

export class BaseRepository <T extends Document> {
  protected readonly model: Model<T>
  protected readonly modelName?: string
  protected readonly whereField?: string
  constructor (
    model: Model<T>,
    modelName?: string,
    whereField?: string
  ) {
    this.model = model
    this.modelName = modelName
    this.whereField = whereField
  }

  async getAll (): Promise< { message: string, results: T[] } > {
    const docs = await this.model.find()
    if (docs == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: docs
    }
  }

  async findWithPagination (query: Pagination & { sort?: Record<string, 1 | -1> }): Promise<ResponseWithPagination<T>> {
    const page = query.page ?? 1
    const limit = query.limit ?? 10
    const skip = (page - 1) * limit

    // const filters = (query.filters != null) || {}
    const filters = (query.filters != null) && typeof query.filters === 'object' ? query.filters : {}
    const sort = (query.sort != null) && typeof query.sort === 'object' ? query.sort : {}
    const total = await this.model.countDocuments(filters)
    const docs = await this.model.find(filters).sort(sort).skip(skip).limit(limit)
    const totalPages = Math.ceil(total / limit)

    return {
      message: \`\${this.modelName} list retrieved\`,
      results: docs,
      info: {
        total,
        page,
        totalPages,
        limit,
        count: docs.length
      }
    }
  }

  async getById (id: string): Promise<{ message: string, results: T }> {
    const doc = await this.model.findById(id)
    if (doc == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: doc as T
    }
  }

  async getOne<K extends keyof T> (value: T[K], field?: K): Promise<{ message: string, results: T }> {
    const fieldSearch = field ?? this.whereField
    if (!fieldSearch) {
      throw new Error('No field specified for search')
    }
    const doc = await this.model.findOne({ [fieldSearch]: value } as FilterQuery<T>)
    if (doc == null) {
      eh.throwError(\`This \${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: doc as T
    }
  }

  async create (data: Partial<T>): Promise<{ message: string, results: T }> {
    if (!this.whereField) {
      throw new Error('No field specified for search')
    }
    if (!(this.whereField in data)) { // Permite valores falsy válidos (como 0 o '')
      throw new Error(\`Missing value for field "\${String(this.whereField)}" in data\`)
    }
    const fieldValue = data[this.whereField as keyof T]
    const doc = await this.model.findOne({ [this.whereField]: fieldValue } as FilterQuery<T>)
    if (doc != null) {
      eh.throwError(\`This \${this.modelName} already exists\`, 400)
    }

    const newDoc = await this.model.create(data)

    return {
      message: \`\${this.modelName} created successfully\`,
      results: newDoc as T
    }
  }

  async update (id: string, data: Partial<T>): Promise<{ message: string, results: T }> {
    const updated = await this.model.findByIdAndUpdate(id, data, { new: true })
    if (updated == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }

    return {
      message: \`\${this.modelName} updated successfully\`,
      results: updated as T
    }
  }

  async delete (id: string): Promise<{ message: string }> {
    await this.model.findByIdAndDelete(id)

    return {
      message: \`\${this.modelName} deleted successfully\`
    }
  }
}
EOL
# Crear BaseRepository.test.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.test.ts" <<EOL
import { BaseRepository } from './BaseRepository.js'
import Test, {ITest} from '../../../test/testHelpers/modelTest.help.js'
import { infoClean, resultParsedCreate, newData } from './testHelpers/testHelp.help.js'
import { setStringId, getStringId } from '../../../test/testHelpers/testStore.help.js'
import mongoose from 'mongoose'
import { testSeeds } from './testHelpers/seeds.help.js'
import { resetDatabase } from '../../../test/jest.setup.js'

/* constructor (
    model: Model<T>,
    useImages = false,
    deleteImages?: typeof mockDeleteFunction,
    parserFunction?: ParserFunction<T>,
    modelName?: string,
    whereField?: keyof T
  ) */

const test = new BaseRepository<ITest>(Test, 'Test', 'title')
describe('Unit tests for the BaseRepository class: CRUD operations.', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('The "create" method for creating a service', () => {
    it('should create an item with the correct parameters', async () => {
      const element = { title: 'page', count: 5, picture: 'https//pepe.com' }
      const response = await test.create(element)
      setStringId(response.results.id)
      expect(response.message).toBe('Test created successfully')
      // expect(response.results instanceof mongoose.Model).toBe(true);
      expect(infoClean(response.results)).toEqual(resultParsedCreate)
    })
  })
  describe('"GET" methods. Return one or multiple services..', () => {
    beforeAll(async () => {
      await Test.insertMany(testSeeds)
    })
    it('"getAll" method: should return an array of services', async () => {
      const response = await test.getAll()
      expect(response.message).toBe('Test retrieved')
      expect(response.results.length).toBe(26)
    })
    it('"findWithPagination" method: should return an array of services', async () => {
      const queryObject = { page: 1, limit: 10, filters: {}, sort: {} }
      const response = await test.findWithPagination(queryObject)
      expect(response.message).toBe('Test list retrieved')
      expect(response.info).toEqual({ page: 1, limit: 10, totalPages: 3, count: 10, total: 26 })
      expect(response.results.length).toBe(10)
    })
    it('"findWithPagination" method should return page 2 of results', async () => {
      const queryObject = { page: 2, limit: 10, filters: {}, sort: {} }
      const response = await test.findWithPagination(queryObject)
      expect(response.results.length).toBeLessThanOrEqual(10)
      expect(response.info.page).toBe(2)
    })
    it('"findWithPagination" method should return sorted results (by title desc)', async () => {
      const queryObject = { page: 1, limit: 5, sort: { title: -1 } as Record<string, 1 | -1> }
      const response = await test.findWithPagination(queryObject)
      const titles = response.results.map(r => r.title)
      const sortedTitles = [...titles].sort().reverse()
      expect(titles).toEqual(sortedTitles)
    })

    it('"getById" method: should return an service', async () => {
      const id = getStringId()
      const response = await test.getById(id)
      expect(infoClean(response.results)).toEqual(resultParsedCreate)
    })
    it('"getOne" method: should return an service', async () => {
       const title= 'page'
      const response = await test.getOne(title)
      expect(infoClean(response.results)).toMatchObject(resultParsedCreate)
    })
  })
  describe('The "update" method - Handles removal of old images from storage.', () => {
    it('should update the document without removing any images', async () => {
      const id = getStringId()
      const data = newData
      const response = await test.update(id, data)
      expect(response.message).toBe('Test updated successfully')
      expect(response.results).toMatchObject({
        id: expect.any(String) as string,
        title: 'page',
        picture: 'https://donJose.com',
        count: 5,
        enabled: true
      })
    })
    
  })
  describe('The "delete" method.', () => {
    it('should delete a document successfully (soft delete)', async () => {
      const id = getStringId()
      const response = await test.delete(id)
      expect(response.message).toBe('Test deleted successfully')
    })
    it('should throw an error if document do not exist', async () => {
      const id = getStringId()
      try {
        await test.delete(id)
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
# Crear testHelp.help.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/testHelpers/testHelp.help.ts" <<EOL
import { Types } from 'mongoose'
import { ITest } from '../../../../test/testHelpers/modelTest.help.js'

export type Info = Pick<ITest, '_id' | 'title' | 'count' | 'picture' | 'enabled'> & {
  _id: Types.ObjectId }
// { _id:Types.ObjectId, title: string, count: number, picture: string, enabled: boolean}

export interface ParsedInfo {
  id: string
  title: string
  count: number
  picture: string
  enabled: boolean
}

export const infoClean = (data: Info): ParsedInfo => {
  return {
    id: data._id.toString(),
    title: data.title,
    count: data.count,
    picture: data.picture,
    enabled: data.enabled
  }
}

export const resultParsedCreate: ParsedInfo = {
  id: expect.any(String) as string,
  title: 'page',
  count: 5,
  picture: 'https//pepe.com',
  enabled: true
}

export const newData: Omit<ParsedInfo, 'id'> = {
  title: 'page',
  count: 5,
  picture: 'https://donJose.com',
  enabled: true
}

export const responseNewData: ParsedInfo = {
  id: expect.any(String) as string,
  title: 'page',
  count: 5,
  picture: 'https://donJose.com',
  enabled: true
}
EOL
# Crear testHelp.help.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/testHelpers/seeds.help.ts" <<EOL
export interface Seeds {
  title: string
  count: number
  picture: string
  enabled: boolean
}

export const testSeeds: Seeds[] = [
  { title: 'donJose', count: 5, picture: 'https://donJose.com', enabled: true },
  { title: 'about', count: 2, picture: 'https://about.com/img1', enabled: true },
  { title: 'contact', count: 7, picture: 'https://contact.com/img2', enabled: false },
  { title: 'services', count: 1, picture: 'https://services.com/img3', enabled: true },
  { title: 'portfolio', count: 9, picture: 'https://portfolio.com/img4', enabled: false },
  { title: 'home', count: 3, picture: 'https://home.com/img5', enabled: true },
  { title: 'products', count: 12, picture: 'https://products.com/img6', enabled: true },
  { title: 'team', count: 6, picture: 'https://team.com/img7', enabled: false },
  { title: 'careers', count: 0, picture: 'https://careers.com/img8', enabled: true },
  { title: 'blog', count: 4, picture: 'https://blog.com/img9', enabled: true },
  { title: 'faq', count: 10, picture: 'https://faq.com/img10', enabled: false },
  { title: 'support', count: 8, picture: 'https://support.com/img11', enabled: true },
  { title: 'terms', count: 15, picture: 'https://terms.com/img12', enabled: false },
  { title: 'privacy', count: 11, picture: 'https://privacy.com/img13', enabled: true },
  { title: 'login', count: 14, picture: 'https://login.com/img14', enabled: true },
  { title: 'register', count: 13, picture: 'https://register.com/img15', enabled: false },
  { title: 'dashboard', count: 17, picture: 'https://dashboard.com/img16', enabled: true },
  { title: 'settings', count: 16, picture: 'https://settings.com/img17', enabled: true },
  { title: 'notifications', count: 18, picture: 'https://notifications.com/img18', enabled: false },
  { title: 'messages', count: 19, picture: 'https://messages.com/img19', enabled: true },
  { title: 'billing', count: 21, picture: 'https://billing.com/img20', enabled: true },
  { title: 'reports', count: 22, picture: 'https://reports.com/img21', enabled: false },
  { title: 'analytics', count: 23, picture: 'https://analytics.com/img22', enabled: true },
  { title: 'integration', count: 24, picture: 'https://integration.com/img23', enabled: true },
  { title: 'feedback', count: 20, picture: 'https://feedback.com/img24', enabled: false }
]
EOL