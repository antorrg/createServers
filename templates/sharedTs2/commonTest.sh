#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear el archivo vitest.config.ts
cat > "$PROJECT_DIR/vitest.config.ts" <<'EOL'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    globals: true
  }
})
EOL
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#Crear archivo de ayudas para test
cat > "$PROJECT_DIR/test/generalFunctions.ts" <<EOL
import { throwError } from '../src/Configs/errorHandlers.js'

interface DeleteResult {
  success: true
  message: string
}
export async function mockDeleteFunction (url: string, result: boolean): Promise<DeleteResult> {
  if (result) {
    await new Promise(resolve => setTimeout(resolve, 1500))
    return {
      success: true,
      message: \`ImageUrl \${url} deleted succesfully\`
    }
  } else {
    await new Promise(reject => setTimeout(reject, 1500))
    throwError(\`Error processing ImageUrl \${url}\`, 500)
    throw new Error()
  }
}
export const deletFunctionTrue = async (url: string, _result?: boolean): Promise<DeleteResult> => {
  // console.log('probando deleteFunction: ', url);
  return {
    success: true,
    message: \`ImageUrl \${url} deleted succesfully\`
  }
}
export const deletFunctionFalse = async (url: string, _result?: boolean): Promise<never> => {
  // console.log('probando deleteErrorFunction: ', url);
  throwError(\`Error processing ImageUrl: \${url}\`, 500)
  throw new Error()
}
EOL
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# Crear el archivo testStore.test.ts
cat > "$PROJECT_DIR/test/testHelpers/testStore.help.ts" <<EOL
let adminToken: string = ''
let userToken: string = ''
let storeId: string = ''
let numberId: number

export const setAdminToken = (newToken: string): void => {
  adminToken = newToken
}

export const getAdminToken = (): string => {
  return adminToken
}

export const setUserToken = (newToken: string): void => {
  userToken = newToken
}

export const getUserToken = (): string => {
  return userToken
}

export const setStringId = (newId: string): void => {
  storeId = newId
}

export const getStringId = (): string => {
  return storeId
}

export const setNumberId = (newId: number): void => {
  numberId = newId
}

export const getNumberId = (): number => {
  return numberId
}
EOL

# Crear auxiliar para tests de imagenes:

cat > "$PROJECT_DIR/test/testHelpers/prepareTestImages.help.ts" <<EOL
import fs from 'fs/promises'
import path from 'path'

const fixturesDir = './assets/fixtures'
const uploadDir = './assets/uploads'

export default async function prepareTestImages (q: number): Promise<string[]> {
  // asegurar que la carpeta uploads existe
  await fs.mkdir(uploadDir, { recursive: true })

  // leer archivos de fixtures
  const files = await fs.readdir(fixturesDir)
  const quantity = q && q > 0 ? Math.min(q, files.length) : files.length
  // copiar cada fixture a uploads
  const copied: string[] = []

  for (let i = 0; i < quantity; i++) {
    const file = files[i]
    const src = path.join(fixturesDir, file)
    const dest = path.join(uploadDir, file)
    await fs.copyFile(src, dest)
    copied.push(file)
  }

  return copied
}
EOL