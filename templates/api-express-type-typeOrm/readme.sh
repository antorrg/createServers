#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"


cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express con Typescript

Base para el proyecto $PROYECTO_VALIDO de Express.ts con entornos de ejecución y manejo de errores.

## Sobre la API:

Esta API fue construida de manera híbrida. Es decir, la parte de Repositories, Services y Controllers está desarrollada bajo el paradigma OOP (Programación Orientada a Objetos). Sin embargo, los routers y la aplicación en sí no lo están. Los middlewares, si bien forman parte de una clase, esta es una clase de métodos estáticos. De esta forma, se aprovecha la escalabilidad y el orden de la POO, pero al mismo tiempo se minimiza el consumo de recursos utilizando funciones puras siempre que sea posible (las clases en JavaScript tienen un costo, aunque no muy elevado).

En esta plantilla encontrará ambos paradigmas funcionando codo a codo. A partir de aquí, puede adaptarla según su preferencia. Si bien está construida de una manera básica, es funcional. Al revisar el código podrá ver, si desea mantener este enfoque, cómo continuar. ¡Buena suerte y buen código!

## Cómo comenzar:

### Instalaciones:

La app viene con las instalaciones básicas para comenzar a trabajar con TypeOrm y base de datos posgres. Las variables de entorno vienen ya con un usuario por defecto (random) y una base de datos ficticia que en caso de ejecutarse se creará, usted deberia cambiar esto por su propia base de datos apropiada para cada entorno.


### Scripts disponibles:

- \`npm start\`: Inicializa la app en modo producción con Node.js y Express (.env.production).
- \`npm run dev\`: Inicializa la app en modo desarrollo con jsx y Express (.env.development).
- \`npm run unit:test\`: Ejecuta todos los tests. También puede ejecutarse un test específico, por ejemplo: \`npm run unit:test EnvDb\`. La app se inicializa en modo test (.env.test).
- \`npm run lint\`: Ejecuta el linter (ts-standard) y analiza la sintaxis del código (no realiza cambios).
- \`npm run lint:fix\`: Ejecuta el linter y corrige automáticamente los errores.
- \`npm run gen:schema\`: Inicializa la función \`generateSchema\`, que genera documentación Swagger para las rutas mediante una guía por consola. Si bien es susceptible de mejora, actualmente resulta muy útil para agilizar el trabajo de documentación.

La aplicación incluye un servicio de ejemplo que muestra su funcionalidad. En la carpeta \`Features/Services/user\` se encuentra un servicio modelo de usuario, con un Servicio, Controlador, Dto y test. El archivo \`user.route.ts\` conecta esta funcionalidad con la app a través de \`mainRouter\` (\`routes.ts\`).

La aplicación puede ejecutarse con \`npm run dev\` (modo desarrollo) o \`npm start\` (producción). Tambien puede (sería lo ideal) desarrollar la app por medio de los test, lo cual puede hacerse desde el comienzo.

Se requieren dos bases de datos: una para desarrollo y otra para test.

### Documentación y rutas:

Esta api cuenta con documentación por medio de Swagger, al inicializar la app en modo dev aparecerá el endpoint (link que se abre con el navegador) adonde se verán los endpoints declarados.

Suele darse el caso (como en el ejemplo dado en la app) que haya endpoints protegidos por token, en ese caso, en el endpoint \`user/login\` es necesario hacer login con los datos del usuario de ejemplo, luego en el resultado copiar el token resultante y pegarlo en la ventana que se abrirá al hacer click en \`authorize\`, seguir los pasos y automaticamente se podrá acceder a todos los endpoints protegidos de la app.

Los endpoints se ordenan automaticamente por lo tanto, lo más probable es que los encuentre ordenados alfabeticamente.

Para crear los endpoints simplemente se ejecuta el comando \`npm run gen:schema\`, y aparecerá en la consola un menú interactivo adonde podrá ingresar los items, campos, parametros y rutas.

La documentación se escribe en \`jsdoc\`, asimismo se creará un archivo \`json\` con los parametros, el menú los guiará y automáticamente se añadiran a la documentación. Es posible que en los casos en que haya endpoints especiales como login y otros, haya que crearlos a mano en el mismo archivo, asi como también si se utilza o no protección con jwt, pero esta automatización garantiza que una gran parte del trabajo estará hecha y servirá de modelo a todo lo que haya que documentar.

### Manejo de errores:

- La función \`catchController\` se utiliza para envolver los controladores, como se detalla en \`BaseController.ts\`.
- La función \`throwError\` se utiliza en los servicios. Recibe un mensaje y un código de estado:

\`\`\`javascript
import eh from "./Configs/errorHandlers.ts";

eh.throwError("Usuario no encontrado", 404);
\`\`\`

- La función \`middError\` se usa en los middlewares:

\`\`\`javascript
import eh from "./Configs/errorHandlers.ts";

if (!user) {
  return next(eh.middError("Falta el usuario", 400));
}
\`\`\`

### Acerca de \`MiddlewareHandler.ts\`

Esta clase estática contiene una serie de métodos auxiliares para evitar la repetición de código en middlewares activos.

#### Métodos de validación disponibles:

- \`validateFields\`: validación y tipado de datos del body
- \`validateFieldsWithItems\`: validación de un objeto con un array de objetos anidados
- \`validateQuery\`: validación y tipado de queries (con copia debido a Express 5)
- \`validateRegex\`: validación de parámetros del body mediante expresiones regulares
- \`paramId\`: validación de Id dinámica con respecto al nombre como al contenido, consiste de dos parametros que le serán pasados al invocar la función.
- \`validReg\`: contiene las variables que contienen los regex para validar ids, ya sea uuidv4, integer, ObjectId de mongoose o firebaseId, tambien se pueden utilizar regex externos o funciones de validacion.
- \`middIntId\`: validación de ID como número entero

#### validateFields:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const user = [
  {name: 'email', type: 'string'},
  {name: 'password', type: 'string'},
  {name: 'phone', type: 'int'}
];

router.post('/', MiddlewareHandler.validateFields(user), controlador);
\`\`\`

Tipos de datos permitidos:
- \`'string'\`
- \`'int'\`
- \`'float'\`
- \`'boolean'\`
- \`'array'\` (no valida su contenido)

Los datos no declarados serán eliminados del body. Si falta alguno de los declarados o no puede convertirse al tipo esperado, se emitirá el error correspondiente.

#### validateFieldsWithItems:

Valida también un array anidado:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const user = [
  {name: 'email', type: 'string'},
  {name: 'password', type: 'string'},
  {name: 'phone', type: 'int'}
];

const address = [
  {name:'street', type:'string'},
  {name:'number', type:'int'}
];

router.post('/', MiddlewareHandler.validateFieldsWithItems(user, address, 'address'), controlador);
\`\`\`

Ejemplo de body:

\`\`\`json
{
  "name": "Leanne Graham",
  "password": "xxxxxxxx",
  "phone": 5578896,
  "address": [
    { "street": "Kulas Light", "number": 225 },
    { "street": "Victor Plains", "number": 1230 }
  ]
}
\`\`\`

#### validateQuery:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const queries = [
  { name: 'page', type: 'int' },
  { name: 'size', type: 'float' },
  { name: 'fields', type: 'string' },
  { name: 'truthy', type: 'boolean' }
];

router.get('/', MiddlewareHandler.validateQuery(queries), controlador);
\`\`\`

Express 5 convierte \`req.query\` en inmutable. La copia validada estará disponible en \`req.validatedQuery\`.

#### validateRegex:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

router.post('/', MiddlewareHandler.validateRegex(emailRegex, 'email', 'Introduzca un mail válido'), controlador);
\`\`\`

#### paramId y ValidReg(opcional):
Se coloca el nombre del id (userId, id, productId etc) y el regex (del metodo ValidReg o exterior) o funcion validadora:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.ts'

router.get('/:userId',  MiddlewareHandler.paramId('id', MiddlewareHandler.ValidReg.UUIDv4), controlador);
\`\`\`

---

Se ha intentado cubrir la mayor cantidad de casos de uso posibles. Por supuesto, pueden existir muchos más, pero esta base ofrece un punto de partida sólido.

---

Espero que esta explicación te sea útil. ¡Suerte!
EOL