#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear BaseRepositories.ts
mkdir -p $PROJECT_DIR/src/Shared/{Repositories,Repositories/testHelpers}

cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.ts" <<EOL
import { type Model, type Document, type FilterQuery, type UpdateQuery } from 'mongoose'
import { type IBaseRepository, type IRepositoryResponse, type IPaginatedOptions, type IPaginatedResults } from '../Interfaces/base.interface.js'
import { throwError } from '../../Configs/errorHandlers.js'

export class BaseRepository<TDTO, TCreate, TUpdate extends UpdateQuery<TMongoose>, TMongoose extends Document>
implements IBaseRepository<TDTO, TCreate, TUpdate> {
  private readonly model: Model<TMongoose>
  private readonly parser: (doc: TMongoose) => TDTO
  private readonly modelName: string
  private readonly whereField: keyof TDTO | string

  constructor (
    model: Model<TMongoose>,
    parser: (doc: TMongoose) => TDTO,
    modelName: string,
    whereField: keyof TDTO | string
  ) {
    this.model = model
    this.parser = parser
    this.modelName = modelName
    this.whereField = whereField
  }

  async getAll (field?: unknown, whereField?: keyof TDTO | string): Promise<IRepositoryResponse<TDTO[]>> {
    const whereClause: FilterQuery<TMongoose> =
    field && whereField ? { [whereField]: field } as FilterQuery<TMongoose> : {}
    const docs = await this.model.find(whereClause).exec()
    return {
      message: \`\${this.modelName} records retrieved successfully\`,
      results: docs.map(this.parser)
    }
  }

  async getById (id: string | number): Promise<IRepositoryResponse<TDTO>> {
    const doc = await this.model.findById(id.toString()).exec()
    if (!doc) throwError(\`\${this.modelName} not found\`, 404)
    return {
      message: \`\${this.modelName} record retrieved successfully\`,
      results: this.parser(doc!)
    }
  }

  async getByField (field?: unknown, whereField?: keyof TDTO | string): Promise<IRepositoryResponse<TDTO>> {
    const whereClause: FilterQuery<TMongoose> =
    field && whereField ? { [whereField]: field } as FilterQuery<TMongoose> : {}
    const doc = await this.model.findOne(whereClause).exec()
    if (!doc) throwError(\`\${this.modelName} not found\`, 404)
    return {
      message: \`\${this.modelName} record retrieved successfully\`,
      results: this.parser(doc!)
    }
  }

  async getWithPages (options?: IPaginatedOptions<TDTO>): Promise<IPaginatedResults<TDTO>> {
    const page = options?.page ?? 1
    const limit = options?.limit ?? 10
    const skip = (page - 1) * limit
    const filter: FilterQuery<TMongoose> = (options?.query ?? {}) as FilterQuery<TMongoose>
    const sort: Record<string, 1 | -1> = (options?.order ?? {}) as Record<string, 1 | -1>

    const [docs, total] = await Promise.all([
      this.model.find(filter).sort(sort).skip(skip).limit(limit).exec(),
      this.model.countDocuments(filter).exec()
    ])

    return {
      message: \`Total records: \${total}. \${this.modelName}s retrieved successfully\`,
      info: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit)
      },
      data: docs.map(this.parser)
    }
  }

async create (data: TCreate): Promise<IRepositoryResponse<TDTO>> {
    const key = this.whereField as string
    const value = (data as any)[key]

    const whereClause: FilterQuery<TMongoose> = { [key]: value } as FilterQuery<TMongoose>

  const existingDoc = await this.model.findOne(whereClause).lean().exec()
  if (existingDoc) {throwError(\`\${this.modelName} with \${this.whereField.toString()} \${value.toString()} already exists\`, 400)}

    const doc = await this.model.create(data)
    return {
      message: \`\${this.modelName} \${(data as any)[this.whereField].toString()} created successfully\`,
      results: this.parser(doc!)
    }
  }

  async update (id: string | number, data: TUpdate): Promise<IRepositoryResponse<TDTO>> {
    const doc = await this.model.findByIdAndUpdate(id.toString(), data, { new: true }).exec()
    if (!doc) throwError(\`\${this.modelName} not found\`, 404)
    return {
      message: \`\${this.modelName} record updated successfully\`,
      results: this.parser(doc!)
    }
  }

  async delete (id: string | number): Promise<IRepositoryResponse<string>> {
    const doc = await this.model.findByIdAndDelete(id.toString()).exec()
    if (!doc) throwError(\`\${this.modelName} not found\`, 404)
    return {
      message: \`\${(doc as any)[this.whereField].toString()} deleted successfully\`,
      results: ''
    }
  }
}
EOL
# Crear BaseRepository.test.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.test.ts" <<EOL
import { beforeAll, afterAll, describe, it, expect } from 'vitest'
import { startUp, closeDatabase} from '../../Configs/database.ts'
import { BaseRepository } from './BaseRepository.ts'
import User from '../../../Schemas/user.model.ts'
import * as help from './testHelpers/testHelp.help.ts'
import * as store from '../../../test/testHelpers/testStore.help.ts'

describe('BaseRepository unit test', () => {
  beforeAll(async () => {
    await startUp(true)
  })
  afterAll(async () => {
    await closeDatabase()
  })
  
  const test = new BaseRepository(User, help.parser, 'User', 'email')
  describe('Create method', () => {
    it('should create a element', async () => {
      const response = await test.create(help.dataCreate)
      expect(response.message).toBe('User user@email.com created successfully')
      expect(response.results).toEqual({
        id: expect.any(String),
        email: 'user@email.com',
        password: '123456',
        nickname: 'userTest',
        name: 'user',
        picture: 'https://picsum.photos/200?random=16',
        enabled: true
      })
      store.setStringId(response.results.id)
    })
  })
  describe('Get methods', () => {
    describe('"getAll" method', () => {
      it('should retrieve an array of elements', async () => {
        await help.createSeedRandomElements(User, help.usersSeed)
        const response = await test.getAll()
        expect(response.message).toBe('User records retrieved successfully')
        expect(response.results.length).toBe(16)
      })
      it('Should retrieve an array of elements filtered by query', async () => {
        const response = await test.getAll('false', 'enabled')
        expect(response.message).toBe('User records retrieved successfully')
        expect(response.results.length).toBe(3)
      })
    })
    describe('"getById" method', () => {
      it('Should retrieve an element by Id', async () => {
        const response = await test.getById(store.getStringId())
        expect(response.message).toBe('User record retrieved successfully')
        expect(response.results).toEqual({
          id: expect.any(String),
          email: 'user@email.com',
          password: '123456',
          nickname: 'userTest',
          name: 'user',
          picture: 'https://picsum.photos/200?random=16',
          enabled: true
        })
      })
    })
    describe('"getByField" method', () => {
      it('Should retrieve an element by field', async () => {
        const response = await test.getByField('user15@email.com', 'email')
        expect(response.message).toBe('User record retrieved successfully')
        expect(response.results).toEqual({
          id: expect.any(String),
          email: 'user15@email.com',
          password: '123456',
          nickname: 'userTest15',
          name: 'Fifteen',
          picture: 'https://picsum.photos/200?random=15',
          enabled: expect.any(Boolean)
        })
      })
    })
    describe('"getWithPages" method', () => {
      it('Should retrieve an array of paginated elements', async () => {
        const queryObject = { page: 1, limit: 10,}as const
        const response = await test.getWithPages(queryObject)
        expect(response.message).toBe('Total records: 16. Users retrieved successfully')
        expect(response.info).toEqual({ total: 16, page: 1, limit: 10, totalPages: 2 })
        expect(response.data.length).toBe(10)
        console.log(response.data)
        expect(response.data.map(a => a.name)).toEqual(['user','One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'])// Order
      })
      it('Should retrieve filtered and sorted elements', async () => {
        const queryObject = { page: 1, limit: 10, query: { enabled: false}, order: { name: 1 } } as const
        const response = await test.getWithPages(queryObject)
        expect(response.message).toBe('Total records: 3. Users retrieved successfully')
        expect(response.info).toEqual({ total: 3, page: 1, limit: 10, totalPages: 1 })
        expect(response.data.length).toBe(3)
        expect(response.data.map(a => a.name)).toEqual(['Fifteen', 'Seven', 'Six'])// Order
      })
    })
  })
  describe('Update method', () => {
    it('should update an element', async () => {
      const data = { name: 'Name of user' }
      const response = await test.update(store.getStringId(), data)
      expect(response.results).toEqual({
        id: expect.any(String),
        ...help.dataUpdate
      })
    })
  })
  describe('Delete method', () => {
    it('should deleted an element', async () => {
      const response = await test.delete(store.getStringId())
      expect(response.message).toBe('user@email.com deleted successfully')
    })
  })
})
EOL
# Crear testHelp.help.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/testHelpers/testHelp.help.ts" <<EOL
import { type HydratedDocument } from "mongoose";
import {IMongooseUser} from '../../../../Schemas/user.model'

export interface IUserTest {
  id: string
  email: string
  password: string
  nickname?: string | null
  name: string
  picture?: string | null
  enabled: boolean
}
export interface CreateUserInput {
  email: string
  password: string
  nickname?: string | null
  name?: string | null
  picture?: string | null
  enabled: boolean
}
export type UpdateUserInput = Partial<CreateUserInput>

export const parser = (u: HydratedDocument<IMongooseUser>): IUserTest => {
  const raw = typeof u.toObject === 'function'? u.toObject() : u
  return {
    id: raw._id.toString(),
    email: raw.email,
    password: raw.password,
    nickname: raw.nickname,
    name: raw.name ?? '',
    picture: raw.picture,
    enabled: raw.enabled
  }
}
export const dataCreate = {
  email: 'user@email.com',
  password: '123456',
  nickname: 'userTest',
  name: 'user',
  picture: 'https://picsum.photos/200?random=16'
}
export const dataUpdate: UpdateUserInput = {
  email: 'user@email.com',
  password: '123456',
  nickname: 'userTest',
  name: 'Name of user',
  picture: 'https://picsum.photos/200?random=16',
  enabled: true
}

//* --------------------------------------------------
// ?          UserSeed
//* ------------------------------------------------
export const createSeedRandomElements = async (model: any, seed: unknown[]) => {
  try {
    if (!seed || seed.length === 0) throw new Error('No data')
    await model.insertMany(seed)
  } catch (error) {
    console.error('Error createSeedRandomElements: ', error)
  }
}

export const usersSeed = [
  {
    email: 'user01@email.com',
    password: '123456',
    nickname: 'userTest01',
    name: 'One',
    picture: 'https://picsum.photos/200?random=1',
    enabled: true
  },
  {
    email: 'user02@email.com',
    password: '123456',
    nickname: 'userTest02',
    name: 'Two',
    picture: 'https://picsum.photos/200?random=2',
    enabled: true
  },
  {
    email: 'user03@email.com',
    password: '123456',
    nickname: 'userTest03',
    name: 'Three',
    picture: 'https://picsum.photos/200?random=3',
    enabled: true
  },
  {
    email: 'user04@email.com',
    password: '123456',
    nickname: 'userTest04',
    name: 'Four',
    picture: 'https://picsum.photos/200?random=4',
    enabled: true
  },
  {
    email: 'user05@email.com',
    password: '123456',
    nickname: 'userTest05',
    name: 'Five',
    picture: 'https://picsum.photos/200?random=5',
    enabled: true
  },
  {
    email: 'user06@email.com',
    password: '123456',
    nickname: 'userTest06',
    name: 'Six',
    picture: 'https://picsum.photos/200?random=6',
    enabled: false
  },
  {
    email: 'user07@email.com',
    password: '123456',
    nickname: 'userTest07',
    name: 'Seven',
    picture: 'https://picsum.photos/200?random=7',
    enabled: false
  },
  {
    email: 'user08@email.com',
    password: '123456',
    nickname: 'userTest08',
    name: 'Eight',
    picture: 'https://picsum.photos/200?random=8',
    enabled: true
  },
  {
    email: 'user09@email.com',
    password: '123456',
    nickname: 'userTest09',
    name: 'Nine',
    picture: 'https://picsum.photos/200?random=9',
    enabled: true
  },
  {
    email: 'user10@email.com',
    password: '123456',
    nickname: 'userTest10',
    name: 'Ten',
    picture: 'https://picsum.photos/200?random=10',
    enabled: true
  },
  {
    email: 'user11@email.com',
    password: '123456',
    nickname: 'userTest11',
    name: 'Eleven',
    picture: 'https://picsum.photos/200?random=11',
    enabled: true
  },
  {
    email: 'user12@email.com',
    password: '123456',
    nickname: 'userTest12',
    name: 'Twelve',
    picture: 'https://picsum.photos/200?random=12',
    enabled: true
  },
  {
    email: 'user13@email.com',
    password: '123456',
    nickname: 'userTest13',
    name: 'Thirteen',
    picture: 'https://picsum.photos/200?random=13',
    enabled: true
  },
  {
    email: 'user14@email.com',
    password: '123456',
    nickname: 'userTest14',
    name: 'Fourteen',
    picture: 'https://picsum.photos/200?random=14',
    enabled: true
  },
  {
    email: 'user15@email.com',
    password: '123456',
    nickname: 'userTest15',
    name: 'Fifteen',
    picture: 'https://picsum.photos/200?random=15',
    enabled: false
  }
]
EOL
