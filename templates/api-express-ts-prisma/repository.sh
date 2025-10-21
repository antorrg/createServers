#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear BaseRepositories.ts
mkdir -p $PROJECT_DIR/src/Shared/{Repositories,Repositories/testHelpers}

cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.ts" <<EOL
import type { IBaseRepository, IRepositoryResponse, IPaginatedOptions, IPaginatedResults, Direction } from '../Interfaces/base.interface.js'
import { throwError } from '../../Configs/errorHandlers.js'

export class BaseRepository<
  TDTO,
  TCreate extends Record<string, any>,
  TUpdate = Partial<TCreate>,
  TModel extends {
    findMany: Function
    findUnique: Function
    findFirst: Function
    create: Function
    update: Function
    delete: Function
    count: Function
    name?: string
  } = any
> implements IBaseRepository<TDTO, TCreate, TUpdate> {
  constructor(
    private readonly Model: TModel,
    private readonly parserFn: (model: any) => TDTO,
    private readonly modelName: string = Model.name ?? 'Model',
    private readonly whereField: keyof TDTO & string,
  ) {}

  async getAll(
    field?: unknown,
    whereField?: keyof TDTO | string
  ): Promise<IRepositoryResponse<TDTO[]>> {
    const whereClause = whereField != null && field != null
  ? { [whereField]: field }
  : {}
    const models = await this.Model.findMany({ where: whereClause })
    return {
      message: \`\${this.modelName} records retrieved successfully\`,
      results: models.map(this.parserFn)
    }
  }

  async getWithPages(
    options?: IPaginatedOptions<TDTO>
  ): Promise<IPaginatedResults<TDTO>> {
    const page = options?.page ?? 1
    const limit = options?.limit ?? 10
    const whereClause = options?.query ?? {}
    const skip = (page - 1) * limit

  const orderClause = options?.order
  ? Object.entries(options.order).map(([field, dir]) => ({
      [field]:
        String(dir).toLowerCase() === 'asc'? 'asc' : 'desc'
    }))
  : { [this.whereField]: 'asc' }

    const data = await this.Model.findMany({
        where: whereClause,
        orderBy: orderClause,
        skip,
        take: limit,
      })
     const total = await this.Model.count({ where: whereClause })
    

    return {
      message: \`Total records: \${total}. \${this.modelName}s retrieved successfully\`,
      info: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit)
      },
      data: data.map(this.parserFn)
    }
  }

  async getById(id: string | number): Promise<IRepositoryResponse<TDTO>> {
    const model = await this.Model.findUnique({ where: { id: id } })
    if (!model) throwError(\`\${this.modelName} not found\`, 404)
    return {
      message: \`\${this.modelName} record retrieved successfully\`,
      results: this.parserFn(model)
    }
  }

  async getByField(
    field?: unknown,
    whereField: keyof TDTO | string = this.whereField
  ): Promise<IRepositoryResponse<TDTO>> {
    if (field == null) throwError(\`No value provided for \${(whereField as string)}\`, 400)
    const model = await this.Model.findFirst({
      where: { [whereField]: field }
    })
    if (!model) throwError(\`The \${(whereField as string)} "\${field}" was not found\`, 404)
    return {
      message: \`\${this.modelName} record retrieved successfully\`,
      results: this.parserFn(model)
    }
  }

  async create(data: TCreate): Promise<IRepositoryResponse<TDTO>> {
    const exists = await this.Model.findFirst({
      where: { [this.whereField]: (data as any)[this.whereField] }
    })
    if (exists) {
      throwError(
        \`\${this.modelName} with \${this.whereField} \${
          (data as any)[this.whereField]
        } already exists\`,
        400
      )
    }
    const model = await this.Model.create({ data })
    return {
      message: \`\${this.modelName} \${model[this.whereField]} created successfully\`,
      results: this.parserFn(model)
    }
  }

  async update(
    id: string | number,
    data: TUpdate
  ): Promise<IRepositoryResponse<TDTO>> {
    const model = await this.Model.findUnique({ where: { id: id } })
    if (!model) throwError(\`\${this.modelName} not found\`, 404)
    const updated = await this.Model.update({
      where: { id:id },
      data
    })
    return {
      message: \`\${this.modelName} record updated successfully\`,
      results: this.parserFn(updated)
    }
  }

  async delete(id: string | number): Promise<IRepositoryResponse<string>> {
    const model = await this.Model.findUnique({ where: { id: id } })
    if (!model) throwError(\`\${this.modelName} not found\`, 404)
    const value = (model as any)[this.whereField]
    await this.Model.delete({ where: { id: id } })
    return {
      message: \`\${value} deleted successfully\`,
      results: ''
    }
  }
}
EOL
# Crear BaseRepository.test.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.test.ts" <<EOL
import { beforeAll, afterAll, describe, it, expect } from 'vitest'
import { startUp, closeDatabase, prisma} from '../../Configs/database.ts'
import { BaseRepository } from './BaseRepository.ts'
import * as help from './testHelpers/testHelp.help.ts'
import * as store from '../../../test/testHelpers/testStore.help.ts'

describe('BaseRepository unit test', () => {
  beforeAll(async () => {
    await startUp(true)
  })
  afterAll(async () => {
    await closeDatabase()
  })
  const UserModel = prisma.user
  const test = new BaseRepository(UserModel, help.parser, 'User', 'email')
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
        await help.createSeedRandomElements(UserModel, help.usersSeed)
        const response = await test.getAll()
        expect(response.message).toBe('User records retrieved successfully')
        expect(response.results.length).toBe(16)
      })
      it('Should retrieve an array of elements filtered by query', async () => {
        const response = await test.getAll(false, 'enabled')
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
        expect(response.data.map(a => a.name)).toEqual(['One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten'])// Order
      })
      it('Should retrieve filtered and sorted elements', async () => {
        const queryObject = { page: 1, limit: 10, query: { enabled: false }, order: { name: 'ASC' } } as const
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
import type { User } from '@prisma/client'

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

export const parser = (raw: User): IUserTest => {
  return {
    id: raw.id,
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
    await model.createMany({data: seed})
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
