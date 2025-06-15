#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear el archivo jest.config.js
cat > "$PROJECT_DIR/jest.config.js" <<'EOL'
export default {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  extensionsToTreatAsEsm: ['.ts'],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      useESM: true
    }]
  },
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '\$1',
  },
  testMatch: [
    '**/__tests__/**/*.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts'
  ],
  setupFilesAfterEnv: ['./test/jest.setup.ts'],
  detectOpenHandles: true,
  forceExit: true
};
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