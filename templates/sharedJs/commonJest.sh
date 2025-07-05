#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear el archivo jest.config.js
cat > "$PROJECT_DIR/jest.config.js" <<'EOL'
export default {
  testEnvironment: 'node',
  setupFilesAfterEnv: ['./test/jest.setup.js']
  // extensionsToTreatAsEsm: ['.ts', '.js'],
  // transform: {},
}
EOL
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#Crear archivo de ayudas para test
cat > "$PROJECT_DIR/test/generalFunctions.js" <<EOL
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
cat > "$PROJECT_DIR/test/testHelpers/testStore.help.js" <<EOL
let adminToken= ''
let userToken = ''
let storeId = ''
let numberId

export const setAdminToken = (newToken)=> {
  adminToken = newToken
}

export const getAdminToken = ()=> {
  return adminToken
}

export const setUserToken = (newToken)=> {
  userToken = newToken
}

export const getUserToken = () => {
  return userToken
}

export const setStringId = (newId) => {
  storeId = newId
}

export const getStringId = () => {
  return storeId
}

export const setNumberId = (newId) => {
  numberId = newId
}

export const getNumberId = () => {
  return numberId
}
EOL