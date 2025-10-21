#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear BaseRepositories.ts
mkdir -p $PROJECT_DIR/src/Shared/{Repositories,Repositories/testHelpers}

cat > "$PROJECT_DIR/src/Shared/Repositories/BaseRepository.ts" <<EOL
import { type Repository, type FindOptionsWhere, type ObjectLiteral, FindManyOptions, SelectQueryBuilder } from 'typeorm'
import type { IBaseRepository, IRepositoryResponse, IPaginatedOptions, IPaginatedResults, Direction } from '../Interfaces/base.interface.js'
import { throwError } from '../../Configs/errorHandlers.js'

export class BaseRepository<
  TEntity extends ObjectLiteral,
  TDTO,
  TCreate,
  TUpdate = Partial<TCreate>
> implements IBaseRepository<TDTO, TCreate, TUpdate> {
  constructor (
    private readonly Model: Repository<TEntity>,
    private readonly parserFn: (entity: TEntity) => TDTO,
    private readonly modelName: string,
    private readonly whereField: keyof TDTO & string
  ) {
    this.Model = Model
    this.parserFn = parserFn
    this.whereField = whereField
  }

  async getAll (field?: unknown, whereField?: keyof TDTO | string): Promise<IRepositoryResponse<TDTO[]>> {
    const whereClause = (field && whereField)
      ? { [whereField]: field } as FindOptionsWhere<TEntity>
      : {}

    const entities = await this.Model.find({ where: whereClause })
    return {
      message: \`\${this.modelName} records retrieved successfully\`,
      results: entities.map(this.parserFn)
    }
  }

  async getWithPages (options?: IPaginatedOptions<TDTO>): Promise<IPaginatedResults<TDTO>> {
    const page = options?.page ?? 1
    const limit = options?.limit ?? 10
    const skip = (page - 1) * limit

    const whereClause = options?.query ?? {}
    const qb = this.Model.createQueryBuilder('t')

    // 🔹 Filtros simples (sin operador lógico)
    Object.entries(whereClause).forEach(([key, value]) => {
      qb.andWhere(\`t.\${key} = :\${key}\`, { [key]: value })
    })

    // 🔹 Ordenamiento seguro
    if (options?.order) {
      for (const [field, rawDir] of Object.entries(options.order)) {
        const dir =
        typeof rawDir === 'string'
          ? rawDir.toUpperCase()
          : rawDir === 1
            ? 'ASC'
            : 'DESC'
        // 👇 Aquí ya podés usar funciones SQL
        qb.addOrderBy(\`LOWER(t.\${field})\`, (dir as any))
      }
    }

    // 🔹 Paginación
    qb.take(limit).skip(skip)

    // 🔹 Ejecutar consulta
    const [entities, count] = await qb.getManyAndCount()

    return {
      message: \`Total records: \${count}. \${this.modelName}s retrieved successfully\`,
      info: {
        total: count,
        page,
        limit,
        totalPages: Math.ceil(count / limit)
      },
      data: entities.map(this.parserFn)
    }
  }

  async getById (id: string | number): Promise<IRepositoryResponse<TDTO>> {
    const entity = await this.Model.findOne({ where: { id } as any })
    if (!entity) throwError(\`\${this.modelName} not found\`, 404)
    return {
      message: \`\${this.modelName} record retrieved successfully\`,
      results: this.parserFn(entity!)
    }
  }

  async getByField (
    field?: unknown,
    whereField: keyof TDTO | string = this.whereField
  ): Promise<IRepositoryResponse<TDTO>> {
    if (field == null) { throwError(\`No value provided for \${whereField.toString()}\`, 400) }

    const entity = await this.Model.findOne({
      where: { [whereField]: field } as FindOptionsWhere<TEntity>
    })
    if (!entity) { throwError(\`The \${whereField.toString()} "\${field}" was not found\`, 404) }

    return {
      message: \`\${this.modelName} record retrieved successfully\`,
      results: this.parserFn(entity!)
    }
  }

  // 🔹 CREATE
  async create (data: TCreate): Promise<IRepositoryResponse<TDTO>> {
    const exists = await this.Model.findOne({
      where: { [this.whereField]: (data as any)[this.whereField] } as FindOptionsWhere<TEntity>
    })

    if (exists) {
      throwError(
        \`\${this.modelName} with \${this.whereField} \${(data as any)[this.whereField]} already exists\`,
        400
      )
    }

    const newEntity = this.Model.create(data as any)
    const saved = await this.Model.save(newEntity as any)
    return {
      message: \`\${this.modelName} \${(data as any)[this.whereField]} created successfully\`,
      results: this.parserFn(saved)
    }
  }

  // 🔹 UPDATE
  async update (id: string | number, data: TUpdate): Promise<IRepositoryResponse<TDTO>> {
    const entity = await this.Model.findOne({ where: { id } as any })
    if (!entity) throwError(\`\${this.modelName} not found\`, 404)

    const updated = this.Model.merge(entity!, data as any)
    const saved = await this.Model.save(updated)
    return {
      message: \`\${this.modelName} record updated successfully\`,
      results: this.parserFn(saved)
    }
  }

  // 🔹 DELETE
  async delete (id: string | number): Promise<IRepositoryResponse<string>> {
    const entity = await this.Model.findOne({ where: { id } as any })
    if (!entity) throwError(\`\${this.modelName} not found\`, 404)

    const value = (entity as any)[this.whereField]
    await this.Model.softRemove(entity!) // usa soft delete si tu entidad tiene @DeleteDateColumn

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
import { startUp, closeDatabase, AppDataSource } from '../../Configs/database.ts'
import { User } from '../../../Models/user.entity.ts'
import { BaseRepository } from './BaseRepository.ts'
import * as help from './testHelpers/testHelp.help.ts'
import * as store from '../../../test/testHelpers/testStore.help.ts'

describe('BaseRepository unit test', () => {
  beforeAll(async () => {
    await startUp(true, true)
  })
  afterAll(async () => {
    await closeDatabase()
  })
  const UserModel = AppDataSource.getRepository(User)
  const test = new BaseRepository(UserModel, help.parser, 'User', 'email')
    describe('Create method', () => {
        it('should create a element', async() => {
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
        it('should retrieve an array of elements', async() => {
            await help.createSeedRandomElements(User,help.usersSeed)
            const response = await test.getAll()
            expect(response.message).toBe('User records retrieved successfully')
            expect(response.results.length).toBe(16)
        })
        it('Should retrieve an array of elements filtered by query', async() => {
             const response = await test.getAll('false', 'enabled')
            expect(response.message).toBe('User records retrieved successfully')
            expect(response.results.length).toBe(3)
        })
        })
        describe('"getById" method', () => { 
            it('Should retrieve an element by Id', async() => {
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
            it('Should retrieve an element by field', async() => {
             const response = await test.getByField("user15@email.com", 'email')
            expect(response.message).toBe('User record retrieved successfully')
            expect(response.results).toEqual({
                id: expect.any(String),
                email: "user15@email.com",
                password: "123456",
                nickname: "userTest15",
                name: "Fifteen",
                picture: "https://picsum.photos/200?random=15",
                enabled: false
            })
            
        })
      })
      describe('"getWithPages" method', () => { 
         it('Should retrieve an array of paginated elements', async() => {
            const queryObject = {page:1, limit:10,}
             const response = await test.getWithPages(queryObject)
            expect(response.message).toBe('Total records: 16. Users retrieved successfully')
            expect(response.info).toEqual({ total: 16, page: 1, limit: 10, totalPages: 2 })
            expect(response.data.length).toBe(10)
             expect(response.data.map(a => a.name)).toEqual(["user", "One","Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"])// Order
        })
         it('Should retrieve filtered and sorted elements', async() => {
            const queryObject = {page:1, limit:10,query:{enabled: false}, order: { name : 'ASC'}} as const
             const response = await test.getWithPages(queryObject)
            expect(response.message).toBe('Total records: 3. Users retrieved successfully')
            expect(response.info).toEqual({ total: 3, page: 1, limit: 10, totalPages: 1 })
            expect(response.data.length).toBe(3)
            expect(response.data.map(a => a.name)).toEqual(["Fifteen", "Seven", "Six"])// Order
        })
      })

    })
    describe('Update method', () => {
        it('should update an element', async() => {
            const data ={name: 'Name of user'}
            const response = await test.update(store.getStringId(), data)
            expect(response.results).toEqual({
                id: expect.any(String),
                ...help.dataUpdate 
            })
        })
    })
    describe('Delete method', () => {
        it('should deleted an element', async() => { 
            const response = await test.delete(store.getStringId())
            expect(response.message).toBe('user@email.com deleted successfully')
        })
    })
})
EOL
# Crear testHelp.help.ts
cat > "$PROJECT_DIR/src/Shared/Repositories/testHelpers/testHelp.help.ts" <<EOL
import { type User } from '../../../../Models/user.entity.ts'
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
    await model.insert(seed)
  } catch (error) {
    console.error('Error createSeedRandomElements: ', error)
  }
}
export const usersSeed = [
  {
    email: "user1@email.com",
    password: "123456",
    nickname: "userTest1",
    name: "One",
    picture: "https://picsum.photos/200?random=1",
    enabled: true
  },
  {
    email: "user2@email.com",
    password: "123456",
    nickname: "userTest2",
    name: "Two",
    picture: "https://picsum.photos/200?random=2",
    enabled: true
  },
  {
    email: "user3@email.com",
    password: "123456",
    nickname: "userTest3",
    name: "Three",
    picture: "https://picsum.photos/200?random=3",
    enabled: true
  },
  {
    email: "user4@email.com",
    password: "123456",
    nickname: "userTest4",
    name: "Four",
    picture: "https://picsum.photos/200?random=4",
    enabled: true
  },
  {
    email: "user5@email.com",
    password: "123456",
    nickname: "userTest5",
    name: "Five",
    picture: "https://picsum.photos/200?random=5",
    enabled: true
  },
  {
    email: "user6@email.com",
    password: "123456",
    nickname: "userTest6",
    name: "Six",
    picture: "https://picsum.photos/200?random=6",
    enabled: false
  },
  {
    email: "user7@email.com",
    password: "123456",
    nickname: "userTest7",
    name: "Seven",
    picture: "https://picsum.photos/200?random=7",
    enabled: false
  },
  {
    email: "user8@email.com",
    password: "123456",
    nickname: "userTest8",
    name: "Eight",
    picture: "https://picsum.photos/200?random=8",
    enabled: true
  },
  {
    email: "user9@email.com",
    password: "123456",
    nickname: "userTest9",
    name: "Nine",
    picture: "https://picsum.photos/200?random=9",
    enabled: true
  },
  {
    email: "user10@email.com",
    password: "123456",
    nickname: "userTest10",
    name: "Ten",
    picture: "https://picsum.photos/200?random=10",
    enabled: true
  },
  {
    email: "user11@email.com",
    password: "123456",
    nickname: "userTest11",
    name: "Eleven",
    picture: "https://picsum.photos/200?random=11",
    enabled: true
  },
  {
    email: "user12@email.com",
    password: "123456",
    nickname: "userTest12",
    name: "Twelve",
    picture: "https://picsum.photos/200?random=12",
    enabled: true
  },
  {
    email: "user13@email.com",
    password: "123456",
    nickname: "userTest13",
    name: "Thirteen",
    picture: "https://picsum.photos/200?random=13",
    enabled: true
  },
  {
    email: "user14@email.com",
    password: "123456",
    nickname: "userTest14",
    name: "Fourteen",
    picture: "https://picsum.photos/200?random=14",
    enabled: true
  },
  {
    email: "user15@email.com",
    password: "123456",
    nickname: "userTest15",
    name: "Fifteen",
    picture: "https://picsum.photos/200?random=15",
    enabled: false
  }
];
EOL
