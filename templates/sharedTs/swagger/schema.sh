#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/user.jsdoc.ts" <<EOL
/**
* @swagger
* tags:
*   - name: Users
*     description: Operaciones relacionadas con users
 */

/**
* @swagger
* '/api/v1/user/create':
*   post:
*     summary: Crear un nuevo usuario
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             required:
*                - email
*                - password
*             properties:
*             email:
*               type: string
*               format: email
*               example: bartolomiau@gmail.com
*               description: Descripción de email
*             password:
*               type: string
*               example: D12345678
*               description: Debe tener por lo menos 8 caracteres 1 número y una mayúscula.
*     responses:
*       201:
*         description: Creación exitosa
*         content:
*           application/json:
*             schema:
*               type: object
*               properties:
*                 success:
*                   type: boolean
*                 message:
*                   type: string
*                 results:
*                   \$ref: '#/components/schemas/User'
 */

/**
* @swagger
* '/api/v1/user/login':
*   post:
*     summary: Iniciar sesión
*     tags: [Users]
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             required:
*                - email
*                - password
*             properties:
*             email:
*               type: string
*               format: email
*               example: bartolomiau@gmail.com
*               description: debe tener por lo menos 1 @ y ser un email valido
*             password:
*               type: string
*               example: D12345678
*               description: Debe tener por lo menos 8 caracteres 1 número y una mayúscula.
*           example:
*             email: bartolomiau@gmail.com
*             password: D12345678
*     responses:
*       200:
*         description: Login successfully
*         content:
*           application/json:
*             schema:
*               type: object
*               properties:
*                 success:
*                   type: boolean
*                 message:
*                   type: string
*                 results:
*                   type: object
*                   properties:
*                     user:
*                       \$ref: '#/components/schemas/User'
*                     token:
*                       type: string
*/

/**
* @swagger
* '/api/v1/user':
*   get:
*     summary: Obtener todos los users
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: query
*         name: name
*         required: false
*         schema:
*           type: string
*         description: User name
*     responses:
*       200:
*         description: Lista de users
*         content:
*           application/json:
*             schema:
*               type: array
*               items:
*                 \$ref: '#/components/schemas/User'
 */

/**
* @swagger
* '/api/v1/user/{id}':
*   get:
*     summary: Obtener un user por ID
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: string
*         description: User id
*     responses:
*       200:
*         description: user encontrado
*         content:
*           application/json:
*             schema:
*               \$ref: '#/components/schemas/User'
*       404:
*         description: user no encontrado
 */

/**
* @swagger
* '/api/v1/user/{id}':
*   put:
*     summary: Actualizar un user
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: string
*         description: User id
*     requestBody:
*       required: true
*       content:
*         application/json:
*           schema:
*             type: object
*             properties:
*             email:
*               type: string
*               format: email
*               example: email ejemplo
*               description: Descripción de email
*             password:
*               type: string
*               example: password ejemplo
*               description: Descripción de password
*     responses:
*       200:
*         description: Actualización exitosa
*       400:
*         description: Error de validación
 */

/**
* @swagger
* '/api/v1/user/{id}':
*   delete:
*     summary: Eliminar un usuario
*     security:
*       - bearerAuth: []
*     tags: [Users]
*     parameters:
*       - in: path
*         name: id
*         required: true
*         schema:
*           type: string
*         description: User id
*     responses:
*       200:
*         description: Eliminado correctamente
*       404:
*         description: usuario no encontrado
*/
EOL