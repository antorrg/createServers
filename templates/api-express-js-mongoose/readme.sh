#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"


# Crear README.md
cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express

Base para el proyecto $PROYECTO_VALIDO de Express.js con entornos de ejecución y manejo de errores.

## Sobre la API

Esta API fue construida con un enfoque **híbrido**.
La capa de **Repositories**, **Services** y **Controllers** está desarrollada bajo el paradigma **POO** (Programación Orientada a Objetos).
Sin embargo, los **routers** y la aplicación en sí misma no siguen estrictamente este patrón.

Los **middlewares**, aunque forman parte de una clase, utilizan una **clase de métodos estáticos**, lo que permite aprovechar la escalabilidad y el orden de la POO, pero minimizando el consumo de recursos gracias al uso de **funciones puras** siempre que es posible.
(Las clases en JavaScript siempre tienen un costo —pequeño, pero existente—).

En esta plantilla encontrarás ambos paradigmas funcionando **codo a codo**.
A partir de aquí, puedes darle la forma que desees.
Si bien está construida de forma básica, **funciona**, y revisando el código podrás entender cómo seguir este sistema si decides mantenerlo.

¡Buena suerte y buen código!

---

## Cómo comenzar

En la aplicación hay un **servicio de ejemplo** para mostrar la funcionalidad de la API.
Dentro de la carpeta \`Features\` encontrarás la carpeta \`user\`, que contiene:

* \`user.routes.js\`
* \`userDTO.js\`
* Una carpeta \`validHelpers\` con cuatro archivos (tres de validación y un \`index.js\`)

El archivo \`user.routes.js\` conecta todo esto con la aplicación principal a través del \`mainRouter\` (\`routes.js\`).

Puedes ejecutar la aplicación con:

* \`npm run dev\` → modo desarrollo
* \`npm start\` → modo producción

⚠️ Los tests solo podrán ejecutarse luego de haber declarado los modelos y conectado la base de datos.

Necesitarás **dos bases de datos**: una para desarrollo y otra para test.
Cuando todo esté listo, podrás correr los **tests unitarios** (ubicados en \`Configs\` y en \`Shared/Auth\`, \`Middlewares\`, \`Repositories\` y \`Services\`).
Cada test unitario se encuentra junto al archivo que valida, y en la carpeta \`test\` se encuentra el **test de integración** de \`User\`.

---

## Base de datos

La aplicación está preparada para trabajar con **Sequelize**.
Para inicializar Sequelize:

Crear dos bases de datos (minimo), una para pruebas y otra para desarrollo

(Esto vale también para MySQL, etc. Por defecto Sequelize aquí está configurado para PostgreSQL).

Esta API ya incluye la carpeta \`prisma\` y el archivo \`schema.prisma\` con un usuario por defecto.
Aun así, antes de iniciar la aplicación debes ejecutar:

---

## Resumen de pasos iniciales

1. Crear y conectar las bases de datos
2. Comandos útiles:

   * \`npm run unit:test nombreTest\` → Ejecuta un test unitario
   * \`npm run lint\` → Ejecuta el linter
   * \`npm run gen:schema\` → Genera documentación Swagger de los endpoints
   * \`npm run validate:schemas\` → Genera esquemas de validación para cada ruta

---

## Manejo de errores

* **\`catchController\`**: se utiliza para envolver controladores (ver \`GenericController.js\`).
* **\`throwError\`**: para uso en servicios, recibe un mensaje y un estado. Ejemplo:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";

eh.throwError("Usuario no encontrado", 404);
\`\`\`

* **\`middError\`**: para uso en middlewares, devuelve un error para \`next()\`. Ejemplo:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";

if (!user) {
  return next(eh.middError("Falta el usuario", 400));
}
\`\`\`

---

## \`MiddlewareHandler.js\`

Esta clase estática contiene métodos auxiliares para middlewares activos, evitando código repetitivo.

### Métodos principales:

* **validateFields** → Valida y tipa datos del body
* **validateHeaders** → Valida cabeceras
* **validateQuery** → Valida y tipa queries (hace copia por limitaciones de Express 5)
* **validateRegex** → Valida datos del body con expresiones regulares
* **paramId** → Valida IDs en params

Para validar, necesitas un **esquema de validación** (objeto JS) creado manualmente o generado automáticamente con:

\`\`\`bash
npm run validate:schemas
\`\`\`

El proceso es interactivo y te pedirá ruta, nombre de archivo, campos, sanitización, obligatoriedad y valores por defecto.

---

### Ejemplo de esquema:

\`\`\`javascript
// userCreate.js
export default {
  name: { type: "string" },
  username: { type: "string" },
  email: { type: "string" }
};
\`\`\`

---

### Ejemplo con \`validateFields\`:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js';

router.post('/', MiddlewareHandler.validateFields(userCreate), controlador);
\`\`\`

> En \`validateFields\`, \`validateHeaders\` y \`validateQuery\`, los datos no declarados se eliminan del body.
> Si faltan valores obligatorios o no se pueden convertir al tipo indicado, se lanza el error correspondiente.

---

### Ejemplo con \`paramId\`:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js';
import { validate as uuidValidate } from 'uuid';

// Usando regex propio de la clase
router.get(
  '/:id',
  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.UUIDv4),
  controller
);

// Usando validador externo
router.get(
  '/:userId',
  MiddlewareHandler.paramId('userId', uuidValidate),
  controller
);
\`\`\`

---

### Ejemplo con \`validateRegex\`:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js';
const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

router.post(
  '/',
  MiddlewareHandler.validateRegex(emailRegex, 'email', 'Introduzca un mail válido'),
  controlador
);
\`\`\`

---

Con esto se cubren la mayoría de casos de validación y manejo de errores.
Naturalmente, puedes ampliarlo según tus necesidades.

---

📌 **Espero que esta explicación te sirva para entender y usar la plantilla sin problemas. ¡Éxitos!**
EOL