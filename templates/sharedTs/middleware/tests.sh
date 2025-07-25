#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

#Crear el middleware
cat > "$PROJECT_DIR/src/Shared/Middlewares/MiddHandler.test.ts" <<EOL
import session from 'supertest'
import serverTest from './testHelpers/serverTest.help.js'
const agent = session(serverTest)

describe('Clase "MiddlewareHandler". Clase estatica de middlewares. Validacion y tipado de datos', () => {
  describe('Metodo "validateFields". Validacion y tipado datos en body (POST y PUT)', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [] as any[]
      }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)

      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: []
      })
    })

    it('deberia validar, tipar y arrojar un error si faltara algun parametro.', async () => {
      const data = { name: 'name', amount: '100', price: '55.44', arreglo: [] }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing parameters: enable')
    })

    it('deberia validar, tipar y arrojar un error si no fuera posible tipar un parametro.', async () => {
      const data = {
        name: 'name',
        amount: 'ppp',
        price: '55.44',
        enable: 'true',
        arreglo: []
      }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid integer value')
    })

    it('deberia validar, tipar los parametros y permitir el paso quitando todo parametro no declarado.', async () => {
      const data = {
        name: 'name',
        email: 'pepe@gmail.com',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: []
      }
      const response = await agent
        .post('/test/body/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)

      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: []
      })
    })
  })

  describe('Metodo "validateFieldsWithItems"', () => {
    it('deberia validar, tipar los parametros y permitir el paso si estos fueran correctos.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [
          { name: 'name', picture: 'string', enable: 'true', arreglo: [] }
        ]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)

      expect(response.body.message).toBe('Passed middleware')
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: [],
        items: [
          { name: 'name', picture: 'string', enable: true, arreglo: [] }
        ]
      })
    })

    it('deberia arrojar un error si faltara un parametro en items.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [{ name: 'name', enable: 'true', arreglo: [] }]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Missing parameters in items[0]: picture')
    })

    it('deberia arrojar un error si no se puede tipar un valor.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [
          {
            name: 'name',
            picture: 'string',
            enable: '445',
            arreglo: []
          }
        ]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid boolean value')
    })

    it('deberia quitar parametros extra.', async () => {
      const data = {
        name: 'name',
        amount: '100',
        price: '55.44',
        enable: 'true',
        arreglo: [],
        items: [
          {
            name: 'name',
            picture: 'string',
            enable: 'true',
            deletedAt: 'queseyo',
            arreglo: []
          }
        ]
      }
      const response = await agent
        .post('/test/body/extra/create')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.data).toEqual({
        name: 'name',
        amount: 100,
        price: 55.44,
        enable: true,
        arreglo: [],
        items: [{ name: 'name', picture: 'string', enable: true, arreglo: [] }]
      })
    })
  })

  describe('Metodo "validateQuery"', () => {
    it('deberia tipar correctamente los query params.', async () => {
      const response = await agent
        .get('/test/param?page=2&size=2.5&fields=pepe&truthy=true')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.validData).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })

    it('deberia aplicar valores por defecto.', async () => {
      const response = await agent
        .get('/test/param')
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.validData).toEqual({
        page: 1,
        size: 1,
        fields: '',
        truthy: false
      })
    })

    it('deberia lanzar error si no se puede tipar un valor.', async () => {
      const response = await agent
        .get('/test/param?page=pepe&size=2.5')
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Invalid integer value')
    })

    it('deberia quitar campos no esperados.', async () => {
      const response = await agent
        .get(
          '/test/param?page=2&size=2.5&fields=pepe&truthy=true&demas=pepito'
        )
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.validData).toEqual({
        page: 2,
        size: 2.5,
        fields: 'pepe',
        truthy: true
      })
    })
  })

  describe('Metodo "validateRegex"', () => {
    it('deberia permitir email valido.', async () => {
      const data = { email: 'emaildeprueba@ejemplo.com' }
      const response = await agent
        .post('/test/user')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.data).toEqual(data)
    })

    it('deberia rechazar email invalido.', async () => {
      const data = { email: 'emaildeprueba@ejemplocom' }
      const response = await agent
        .post('/test/user')
        .send(data)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe(
        'Invalid email format! Introduzca un mail valido'
      )
    })
  })

  describe('Metodo "paramId"(Regex)', () => {
    it('deberia permitir UUID v4 valido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76-191f905a2edd'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })

    it('deberia rechazar UUID invalido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })

  describe('Metodo "paramId" (Funcion)', () => {
    it('deberia permitir UUID v4 valido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76-191f905a2edd'
      const response = await agent
        .get(\`/test/param/uuidFn/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })

    it('deberia rechazar UUID invalido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/uuidFn/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })

  describe('Metodo "paramId"(Regex)', () => {
    it('deberia permitir Integer valido.', async () => {
      const id = 22
      const response = await agent
        .get(\`/test/param/int/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(200)
      expect(response.body.message).toBe('Passed middleware')
    })

    it('deberia rechazar Integer invalido.', async () => {
      const id = 'c1d970cf-9bb6-4848-aa76191f905a2edd1'
      const response = await agent
        .get(\`/test/param/int/\${id}\`)
        .expect('Content-Type', /json/)
        .expect(400)
      expect(response.body).toBe('Parametros no permitidos')
    })
  })
})
EOL