#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear BaseRepositories.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.ts" <<EOL
import { type Repository, type FindOptionsWhere, type FindOptionsOrder, type DeepPartial, type EntityTarget, type ObjectLiteral } from 'typeorm'
import { type QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity.js'
import { AppDataSource } from '../../Configs/dataSource.js'
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

export class BaseRepository<T extends ObjectLiteral> {
  protected readonly model: Repository<T>
  protected readonly modelName?: string
  protected readonly whereField?: string
  constructor (
    entityClass: EntityTarget<T>,
    modelName?: string,
    whereField?: string
  ) {
    this.model = AppDataSource.getRepository(entityClass)
    this.modelName = modelName
    this.whereField = whereField
  }

  async getAll (): Promise<{ message: string, results: T[] }> {
    const docs = await this.model.find()
    if (!docs) { eh.throwError(\`\${this.modelName} not found\`, 404) }
    if (docs.length === 0) { return { message: \`No \${this.modelName} yet\`, results: [] } }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: docs
    }
  }

  async findWithPagination (query: Pagination & { sort?: FindOptionsOrder<T> }): Promise<ResponseWithPagination<T>> {
    const page = query.page ?? 1
    const limit = query.limit ?? 10
    const skip = (page - 1) * limit
    const filters = (query.filters != null) && typeof query.filters === 'object' ? query.filters : {}
    const order = (query.sort != null) && typeof query.sort === 'object' ? query.sort : {}

    const [docs, total] = await this.model.findAndCount({
      where: filters,
      order,
      skip,
      take: limit
    })
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

  async getById (id: string): Promise<{ message: string, results: T | null }> {
    const doc = await this.model.findOneBy({ id } as unknown as FindOptionsWhere<T>)
    if (doc == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: doc
    }
  }

  async getOne (where: FindOptionsWhere<T>): Promise<{ message: string, results: T | null }> {
    const doc = await this.model.findOneBy(where)
    if (doc == null) {
      eh.throwError(\`This \${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} retrieved\`,
      results: doc
    }
  }

  async create (data: DeepPartial<T>): Promise<{ message: string, results: T }> {
    if (!this.whereField) {
      throw new Error('No field specified for search')
    }
    if (!(this.whereField in data)) {
      throw new Error(\`Missing value for field "\${String(this.whereField)}" in data\`)
    }
    const fieldValue = data[this.whereField as keyof DeepPartial<T>]
    const exists = await this.model.findOneBy({ [this.whereField]: fieldValue } as FindOptionsWhere<T>)
    if (exists != null) {
      eh.throwError(\`This \${this.modelName} already exists\`, 400)
    }
    const entity = this.model.create(data)
    const newDoc = await this.model.save(entity)
    return {
      message: \`\${this.modelName} created successfully\`,
      results: newDoc
    }
  }

  async update (id: string, data: QueryDeepPartialEntity<T>): Promise<{ message: string, results: T | null }> {
    await this.model.update(id, data)
    const updated = await this.model.findOneBy({ id } as unknown as FindOptionsWhere<T>)
    if (updated == null) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} updated successfully\`,
      results: updated
    }
  }

  async delete (id: string): Promise<{ message: string }> {
    const result = await this.model.delete(id)
    if (result.affected === 0) {
      eh.throwError(\`\${this.modelName} not found\`, 404)
    }
    return {
      message: \`\${this.modelName} deleted successfully\`
    }
  }
}
EOL
# Crear BaseRepository.test.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.test.ts" <<EOL
import { beforeAll, afterAll, describe, it, xit, expect } from '@jest/globals'
import { BaseRepository } from './BaseRepository.js'
import { AppDataSource } from '../../Configs/dataSource.js'
import { User } from '../Entities/user.entity.js'
import { infoClean, createUser, newData } from './testHelpers/testHelp.help.js'
import { setStringId, getStringId } from '../../../test/testHelpers/testStore.help.js'
import { userSeeds } from './testHelpers/seeds.help.js'
import { resetDatabase } from '../../../test/jest.setup.js'

/* constructor (
   entityClass: EntityTarget<T>,
       modelName?: string,
       whereField?: string
  ) */

const test = new BaseRepository<User>(User, 'User', 'email')
describe('Unit tests for the BaseRepository class: CRUD operations.', () => {
  afterAll(async () => {
    await resetDatabase()
  })
  describe('The "create" method for creating a service', () => {
    it('should create an item with the correct parameters', async () => {
      const response = await test.create(createUser)
      setStringId(response.results.id)
      expect(response.message).toBe('User created successfully')
      expect(infoClean(response.results)).toEqual({
        id: expect.any(String),
        email: 'userejemplo@example.com',
        picture: 'https://pics.com/u1.jpg',
        isVerify: true,
        role: 1,
        isRoot: false,
        enabled: true
      })
    })
  })
  describe('"GET" methods. Return one or multiple services..', () => {
    beforeAll(async () => {
      const userRepo = AppDataSource.getRepository(User)
      const users = userRepo.create(userSeeds) // crea instancias
      await userRepo.save(users) // guarda todas en la base de datos
    })
    it('"getAll" method: should return an array of services', async () => {
      const response = await test.getAll()
      expect(response.message).toBe('User retrieved')
      expect(response.results.length).toBe(26)
    })
    it('"findWithPagination" method: should return an array of services', async () => {
      const queryObject = { page: 1, limit: 10, filters: {} }
      const response = await test.findWithPagination(queryObject)
      console.log('no order: ', response.results)
      expect(response.message).toBe('User list retrieved')
      expect(response.info).toEqual({ page: 1, limit: 10, totalPages: 3, count: 10, total: 26 })
      expect(response.results.length).toBe(10)
    })
    it('"findWithPagination" method should return page 2 of results', async () => {
      const queryObject = { page: 3, limit: 10, filters: {} }
      const response = await test.findWithPagination(queryObject)
      expect(response.results.length).toBeLessThan(10)
      expect(response.info.page).toBe(3)
      expect(response.results.length).toBe(6)
    })
    it('"findWithPagination" method should return sorted results (by title desc)', async () => {
      const queryObject = { page: 1, limit: 5, sort: { email: 'DESC' as 'DESC' } }
      const response = await test.findWithPagination(queryObject)
      const emails = response.results.map(u => u.email)
      const sorted = [...emails].sort((a, b) => b.localeCompare(a))
      expect(emails).toEqual(sorted)
    })

    it('"getById" method: should return an service', async () => {
      const id = getStringId()
      const response = await test.getById(id)
      expect(response.results).not.toBeNull()
      expect(infoClean(response.results!)).toEqual({
        id: expect.any(String),
        email: 'userejemplo@example.com',
        picture: 'https://pics.com/u1.jpg',
        isVerify: true,
        role: 1,
        isRoot: false,
        enabled: true
      })
    })
    it('"getOne" method: should return an service', async () => {
      const title = 'userejemplo@example.com'
      const response = await test.getOne({ email: title })
      expect(infoClean(response.results!)).toMatchObject({
        id: expect.any(String),
        email: 'userejemplo@example.com',
        picture: 'https://pics.com/u1.jpg',
        isVerify: true,
        role: 1,
        isRoot: false,
        enabled: true
      })
    })
  })
  describe('The "update" method - Handles removal of old images from storage.', () => {
    it('should update the document without removing any images', async () => {
      const id = getStringId()
      const data = newData
      const response = await test.update(id, data)
      expect(response.message).toBe('User updated successfully')
      expect(response.results).toMatchObject({
        id: expect.any(String),
        email: 'userejemplo@example.com',
        picture: 'https:donJose.jpg',
        isVerify: true,
        role: 1,
        isRoot: false,
        enabled: true
      })
    })
  })
  describe('The "delete" method.', () => {
    it('should delete a document successfully (soft delete)', async () => {
      const id = getStringId()
      const response = await test.delete(id)
      expect(response.message).toBe('User deleted successfully')
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
          expect((error as { message: string }).message).toBe('User not found')
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
import { expect } from '@jest/globals'
import { type User } from '../../Entities/user.entity'

export interface IUser {
  id: string
  email: string
  password: string
  nickname: string
  picture: string
  name: string
  surname: string
  country: string
  role: number
  isVerify: boolean
  isRoot: boolean
  createdAt: Date
  updatedAt?: Date
  deletedAt?: Date
  enabled: boolean

}

export interface ParsedInfo {
  id: string
  email: string
  picture: string
  role: number
  isVerify: boolean
  isRoot: boolean
  enabled: boolean
}

export const infoClean = (data: User): ParsedInfo => {
  return {
    id: data.id,
    email: data.email,
    picture: data.picture,
    role: data.role,
    isVerify: data.isVerify,
    isRoot: data.isRoot,
    enabled: data.enabled
  }
}
export const createUser: Partial<User> = {
  email: 'userejemplo@example.com',
  password: 'password1',
  nickname: 'userejemplo',
  picture: 'https://pics.com/u1.jpg',
  name: 'Jose',
  surname: 'Ejemplo',
  country: 'Argentina',
  isVerify: true,
  role: 1,
  isRoot: false,
  enabled: true
}

export const newData: Omit<ParsedInfo, 'id'> = {
  email: 'userejemplo@example.com',
  picture: 'https:donJose.jpg',
  isVerify: true,
  role: 1,
  isRoot: false,
  enabled: true
}

export const responseNewData: any = {
  id: expect.any(String),
  email: 'userejemplo@example.com',
  picture: 'https:donJose.jpg',
  isVerify: true,
  role: 1,
  isRoot: false,
  enabled: true
}
EOL
# Crear testHelp.help.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/testHelpers/seeds.help.ts" <<EOL
import { type DeepPartial } from 'typeorm'
import { type User } from '../../Entities/user.entity.js'

export const userSeeds: Array<DeepPartial<User>> = [
  {
    email: 'user1@example.com',
    password: 'password1',
    nickname: 'UserOne',
    picture: 'https://pics.com/u1.jpg',
    name: 'Alice',
    surname: 'Smith',
    country: 'USA',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user2@example.com',
    password: 'password2',
    nickname: 'UserTwo',
    picture: 'https://pics.com/u2.jpg',
    name: 'Bob',
    surname: 'Johnson',
    country: 'Canada',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user3@example.com',
    password: 'password3',
    nickname: 'UserThree',
    picture: 'https://pics.com/u3.jpg',
    name: 'Carol',
    surname: 'Williams',
    country: 'UK',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user4@example.com',
    password: 'password4',
    nickname: 'UserFour',
    picture: 'https://pics.com/u4.jpg',
    name: 'David',
    surname: 'Brown',
    country: 'Australia',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user5@example.com',
    password: 'password5',
    nickname: 'UserFive',
    picture: 'https://pics.com/u5.jpg',
    name: 'Eve',
    surname: 'Jones',
    country: 'Spain',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user6@example.com',
    password: 'password6',
    nickname: 'UserSix',
    picture: 'https://pics.com/u6.jpg',
    name: 'Frank',
    surname: 'Garcia',
    country: 'Mexico',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user7@example.com',
    password: 'password7',
    nickname: 'UserSeven',
    picture: 'https://pics.com/u7.jpg',
    name: 'Grace',
    surname: 'Martinez',
    country: 'Argentina',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user8@example.com',
    password: 'password8',
    nickname: 'UserEight',
    picture: 'https://pics.com/u8.jpg',
    name: 'Hank',
    surname: 'Lopez',
    country: 'Chile',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user9@example.com',
    password: 'password9',
    nickname: 'UserNine',
    picture: 'https://pics.com/u9.jpg',
    name: 'Ivy',
    surname: 'Gonzalez',
    country: 'Peru',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user10@example.com',
    password: 'password10',
    nickname: 'UserTen',
    picture: 'https://pics.com/u10.jpg',
    name: 'Jack',
    surname: 'Perez',
    country: 'Colombia',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user11@example.com',
    password: 'password11',
    nickname: 'UserEleven',
    picture: 'https://pics.com/u11.jpg',
    name: 'Karen',
    surname: 'Sanchez',
    country: 'Uruguay',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user12@example.com',
    password: 'password12',
    nickname: 'UserTwelve',
    picture: 'https://pics.com/u12.jpg',
    name: 'Leo',
    surname: 'Ramirez',
    country: 'Paraguay',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user13@example.com',
    password: 'password13',
    nickname: 'UserThirteen',
    picture: 'https://pics.com/u13.jpg',
    name: 'Mona',
    surname: 'Torres',
    country: 'Venezuela',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user14@example.com',
    password: 'password14',
    nickname: 'UserFourteen',
    picture: 'https://pics.com/u14.jpg',
    name: 'Nate',
    surname: 'Flores',
    country: 'Bolivia',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user15@example.com',
    password: 'password15',
    nickname: 'UserFifteen',
    picture: 'https://pics.com/u15.jpg',
    name: 'Olga',
    surname: 'Rivera',
    country: 'Ecuador',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user16@example.com',
    password: 'password16',
    nickname: 'UserSixteen',
    picture: 'https://pics.com/u16.jpg',
    name: 'Paul',
    surname: 'Gomez',
    country: 'Guatemala',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user17@example.com',
    password: 'password17',
    nickname: 'UserSeventeen',
    picture: 'https://pics.com/u17.jpg',
    name: 'Quinn',
    surname: 'Diaz',
    country: 'Honduras',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user18@example.com',
    password: 'password18',
    nickname: 'UserEighteen',
    picture: 'https://pics.com/u18.jpg',
    name: 'Rita',
    surname: 'Cruz',
    country: 'El Salvador',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user19@example.com',
    password: 'password19',
    nickname: 'UserNineteen',
    picture: 'https://pics.com/u19.jpg',
    name: 'Sam',
    surname: 'Ortiz',
    country: 'Nicaragua',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user20@example.com',
    password: 'password20',
    nickname: 'UserTwenty',
    picture: 'https://pics.com/u20.jpg',
    name: 'Tina',
    surname: 'Morales',
    country: 'Costa Rica',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user21@example.com',
    password: 'password21',
    nickname: 'UserTwentyOne',
    picture: 'https://pics.com/u21.jpg',
    name: 'Uma',
    surname: 'Castro',
    country: 'Panama',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user22@example.com',
    password: 'password22',
    nickname: 'UserTwentyTwo',
    picture: 'https://pics.com/u22.jpg',
    name: 'Vic',
    surname: 'Rojas',
    country: 'Cuba',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user23@example.com',
    password: 'password23',
    nickname: 'UserTwentyThree',
    picture: 'https://pics.com/u23.jpg',
    name: 'Will',
    surname: 'Mendez',
    country: 'Dominican Republic',
    isVerify: true,
    role: 1,
    isRoot: false,
    enabled: true
  },
  {
    email: 'user24@example.com',
    password: 'password24',
    nickname: 'UserTwentyFour',
    picture: 'https://pics.com/u24.jpg',
    name: 'Xena',
    surname: 'Silva',
    country: 'Puerto Rico',
    isVerify: false,
    role: 2,
    isRoot: false,
    enabled: false
  },
  {
    email: 'user25@example.com',
    password: 'password25',
    nickname: 'UserTwentyFive',
    picture: 'https://pics.com/u25.jpg',
    name: 'Yuri',
    surname: 'Navarro',
    country: 'Haiti',
    isVerify: true,
    role: 1,
    isRoot: true,
    enabled: true
  }
]
EOL