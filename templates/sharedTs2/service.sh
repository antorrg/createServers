#!/bin/bash
PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear carpeta contenedora

mkdir -p $PROJECT_DIR/src/Shared/Services

# Crear el servicio
cat > "$PROJECT_DIR/src/Shared/Services/BaseService.ts" <<EOL
import { throwError } from '../../Configs/errorHandlers.js'
import { type IBaseRepository, type IRepositoryResponse, type IPaginatedOptions, type IPaginatedResults, type IExternalImageDeleteService } from '../Interfaces/base.interface.js'

export class BaseService<TDTO, TCreate, TUpdate> {
  protected repository: IBaseRepository<TDTO, TCreate, TUpdate>
  protected imageDeleteService: IExternalImageDeleteService<any>
  protected useImage: boolean
  protected nameImage: keyof TDTO // & keyof TUpdate;
  constructor (repository: IBaseRepository<TDTO, TCreate, TUpdate>, imageDeleteService: IExternalImageDeleteService<any>,
    useImage: boolean = false, nameImage: keyof TDTO) {
    this.repository = repository
    this.imageDeleteService = imageDeleteService
    this.useImage = useImage
    this.nameImage = nameImage
  }

  async handleImageDeletion (imageUrl: string) {
    if (this.useImage && imageUrl.trim()) {
      return await this.imageDeleteService.deleteImage(imageUrl)
    }
  }

  async getAll (field?: unknown, whereField?: keyof TDTO | string): Promise<IRepositoryResponse<TDTO[]>> {
    return await this.repository.getAll(field, whereField)
  }

  async getById (id: string | number): Promise<IRepositoryResponse<TDTO>> {
    return await this.repository.getById(id)
  }

  async getByField (field: unknown, whereField: keyof TDTO | string): Promise<IRepositoryResponse<TDTO>> {
    return await this.repository.getByField(field, whereField)
  }

  async getWithPages (options?: IPaginatedOptions<TDTO>): Promise<IPaginatedResults<TDTO>> {
    return await this.repository.getWithPages(options)
  }

  async create (data: TCreate): Promise<IRepositoryResponse<TDTO>> {
    return await this.repository.create(data)
  }

  async update<K extends keyof TDTO & keyof TUpdate>(
    id: string | number,
    data: TUpdate
  ): Promise<IRepositoryResponse<TDTO>> {
    let imageUrl: string | null = null
    let activeDel = false

    try {
      const register = await this.getById(id)
      if (!register) throwError('Element not found', 404)

      // 👇 Usamos una variable intermedia tipada
      const key = this.nameImage as K

      if (this.useImage && (register.results[key] as unknown) !== (data[key] as unknown)) {
        imageUrl = register.results[key] as unknown as string
        activeDel = true
      }

      const updated = await this.repository.update(id, data)
      const imgDeleted = activeDel ? await this.handleImageDeletion(imageUrl!) : null
      const messageUpd =
      activeDel ? \`\${updated.message}\n\${imgDeleted}\` : updated.message

      return {
        message: messageUpd,
        results: updated.results
      }
    } catch (error) {
      console.error('Update error', error)
      throw error
    }
  }

  async delete (id: string | number): Promise<IRepositoryResponse<string>> {
    let imageUrl: string | null = null
    let activeDel: boolean = false
    try {
      const register = await this.getById(id)
      if (!register) throwError('Element not found', 404)
      if (this.useImage && (register.results[this.nameImage] as unknown)) {
        imageUrl = register.results[this.nameImage] as unknown as string
        activeDel = true
      }
      const deleted = await this.repository.delete(id)
      const imgDeleted = await this.handleImageDeletion(imageUrl!)
      const messageUpd =
      activeDel ? \`\${deleted.message} and \${imgDeleted}\` : deleted.message
      return {
        message: messageUpd,
        results: deleted.results
      }
    } catch (error) {
      console.error('Error deleting: ', error)
      throw error
    }
  }
}
EOL
# Crear el  imageService para el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/ImgsService.ts" <<EOL
//import { XXXXServices } from '../../ExternalProviders/xxxx.js' //Crear el servicio...
import MockImgsService from './MockImgsService.js'
import envConfig from '../../Configs/envConfig.js'

//Cambiar la segunda opcion por el servicio de imagenes creado
const deleteImageByUrl = envConfig.Status !== 'production' ? MockImgsService.mockFunctionDelete : MockImgsService.mockFunctionDelete 
const selectUploaders = envConfig.Status !== 'production' ? MockImgsService.mockUploadNewImage : MockImgsService.mockUploadNewImage

export default class ImgsService {
  static uploadNewImage = async (file: any) => {
    return await selectUploaders(file)
  }

  static deleteImage = async (imageUrl: string) => {
    return await deleteImageByUrl(imageUrl)
  }
}
EOL

# Crear el mockService de imagenes para el Servicio 
cat > "$PROJECT_DIR/src/Shared/Services/MockImgsService.ts" <<EOL
import { throwError } from '../../Configs/errorHandlers.js'
import fs from 'fs/promises'
import path from 'path'

const LocalBaseUrl = process.env.LOCAL_BASE_URL

export default class MockImgsService {
  static mockUploadNewImage = async (file: any) => {
    try {
      const uploadDir = './assets/uploads'
      // Asegurarse que exista la carpeta
      await fs.mkdir(uploadDir, { recursive: true })
      const newPath = path.join(uploadDir, file.originalname)
      await fs.writeFile(newPath, file.buffer)
      return \`\${LocalBaseUrl}/assets/uploads/\${file.originalname}\`
    } catch (error) {
      console.error('Error subiendo: ', error)
      throw error
    }
  }

  static mockFunctionDelete = async (imageUrl: string) => {
    const filename = path.basename(imageUrl)
    if (!path.extname(filename)) {
      throw new Error(\`URL inválida, no contiene archivo: \${imageUrl}\`)
    }
    const filePath = path.join('./assets/uploads', filename)
    try {
      await new Promise(res => setTimeout(res, 1000))
      await fs.unlink(filePath)
      return \`Image \${filePath} deleted successfully\`
    } catch (err) {
      console.error(\`Error al borrar imagen local: \${filename}\`, err)
      throwError('Error deleting images', 500)
    }
  }
}
EOL

# Crear el  test para el imageService 
cat > "$PROJECT_DIR/src/Shared/Services/MockImgsService.test.ts" <<EOL
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import fs from 'fs/promises'
import path from 'path'
import MockImgsService from './MockImgsService.js' // ajusta la ruta según tu proyecto

const uploadDir = './assets/uploads'
const fakeFile = {
  originalname: 'test-image.png',
  buffer: Buffer.from('contenido-de-prueba', 'utf-8')
}

describe('MockImgsService', () => {
  beforeAll(async () => {
    // Asegurar que exista la carpeta
    await fs.mkdir(uploadDir, { recursive: true })
  })

  afterAll(async () => {
    // Limpiar el directorio después de las pruebas
    try {
      const filePath = path.join(uploadDir, fakeFile.originalname)
      await fs.unlink(filePath)
    } catch {
      // ignorar si no existe
    }
  })

  it('debe subir un archivo localmente con mockUploadNewImage', async () => {
    const imageUrl = await MockImgsService.mockUploadNewImage(fakeFile)

    // Verificar que devuelve una URL válida
    expect(imageUrl).toContain(fakeFile.originalname)

    // Verificar que el archivo fue creado
    const filePath = path.join(uploadDir, fakeFile.originalname)
    const exists = await fs
      .access(filePath)
      .then(() => true)
      .catch(() => false)

    expect(exists).toBe(true)
  })

  it('debe eliminar un archivo con mockFunctionDelete', async () => {
    // Subir primero el archivo
    const imageUrl = await MockImgsService.mockUploadNewImage(fakeFile)

    // Eliminar con la función mock
    const result = await MockImgsService.mockFunctionDelete(imageUrl)

    expect(result).toBe(true)

    // Verificar que ya no existe
    const filePath = path.join(uploadDir, fakeFile.originalname)
    const exists = await fs
      .access(filePath)
      .then(() => true)
      .catch(() => false)

    expect(exists).toBe(false)
  })
})
EOL


# Crear carpeta e imagenes para testear 
mkdir -p "$PROJECT_DIR/assets"
mkdir -p "$PROJECT_DIR/assets"/{fixtures,uploads}
#Crear imagenes prueba
for i in {0..6}; do
  touch "$PROJECT_DIR/assets/fixtures/test${i}.jpg"
done
#Crear gitKeep
touch "$PROJECT_DIR/assets/uploads/.gitkeep"
