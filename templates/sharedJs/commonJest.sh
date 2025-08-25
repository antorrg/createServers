#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear el archivo jest.config.js
cat > "$PROJECT_DIR/jest.config.js" <<'EOL'
export default {
  testEnvironment: 'node',
  projects: [
    {
      displayName: 'unit',
      testMatch: ['<rootDir>/test/**/*.test.js'],
      testPathIgnorePatterns: ['/int/'],
      
    },
    {
      displayName: 'integration',
      testMatch: ['<rootDir>/test/**/*.int.spec.js'],
      //setupFilesAfterEnv: ['./test/jest.setup.js']
    }
  ]
}
EOL
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#Crear archivo de ayudas para test
cat > "$PROJECT_DIR/test/generalFunctions.js" <<EOL
import { throwError } from '../src/Configs/errorHandlers.js'

export async function mockDeleteFunction (url, result) {
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
export const deletFunctionTrue = async (url, result) => {
  // console.log('probando deleteFunction: ', url);
  return {
    success: true,
    message: \`ImageUrl \${url} deleted succesfully\`
  }
}
export const deletFunctionFalse = async (url, result) => {
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

cat > "$PROJECT_DIR/test/testHelpers/User-helpers/users.js" <<EOL
export const users = [
  {
    username: 'Bret',
    email: 'Sincere@april.biz',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Antonette',
    email: 'Shanna@melissa.tv',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Samantha',
    email: 'Nathan@yesenia.net',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Karianne',
    email: 'Julianne.OConner@kory.org',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Kamren',
    email: 'Lucio_Hettinger@annie.ca',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Leopoldo_Corkery',
    email: 'Karley_Dach@jasper.info',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Elwyn.Skiles',
    email: 'Telly.Hoeger@billy.biz',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Maxime_Nienow',
    email: 'Sherwood@rosamond.me',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {
    username: 'Delphine',
    email: 'Chaim_McDermott@dana.io',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  },
  {

    username: 'Moriah.Stanton',
    email: 'Rey.Padberg@karina.biz',
    picture: 'abs@gmail.com',
    password: 'L1234567'
  }
]
EOL

