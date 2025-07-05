#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"


# Crear README.md
cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express

Base para el proyecto $PROYECTO_VALIDO de Express.js con entornos de ejecución y manejo de errores.

## Sobre la API:

Esta api fue construida de manera hibrida, es decir: la parte de Repositories, Services y Controllers está construida bajo el paradigma OOP (o POO en español, Programacion Orientada a Objetos), sin embargo los routers y la aplicacion en si misma no lo está, los Middlewares sin bien forman parte de una clase, esta es una clase de metodos estaticos, de manera que aproveche la escalabilidad y orden de la POO pero al mismo tiempo minimize el consumo de recursos utilizando funciones puras en todo lugar en el que se pueda (las clases en javascript tienen siempre un costo, no muy elevado pero costo al fin), de manera que en esta plantilla va a encontar los dos paradigmas funcionando codo a codo, usted puede a partir de aqui darle la forma que desee. Si bien está construida de una manera muy básica, esta funciona, por lo que al revisar el codigo podrá ver (si desea mantener este sistema de trabajo) como seguir. ¡Buena suerte y buen codigo!

## Cómo comenzar:

En la aplicacion hay un servicio hecho a modo de ejemplo para mostrar la funcionalidad de la api, en la carpeta Services se encuentra un archivo \`users.js\` que contiene un arreglo con un grupo de usuarios, estos junto con los controladores y servicios son llamados y utilizados en el archivo \`mainUser.js\` que se encuentra dentro del directorio Modules en la carpeta users, aqui tambien se declaran los tipos de datos que van a ingresar, y por medio del archivo \`user.routes.js\` la funcion userRouter conecta todo esto con la app en mainRouter (\`routes.js\`). La aplicacion se puede ejecutar tanto con el comando \`npm run dev\` (en desarrollo) o \`npm start\` (produccion). Los test solo podrán utilizarse luego de haber declarado los modelos y conectado la base de datos.

Es importante decir que necesitará dos dbs, una para desarrollo y otra para test, luego de tener todo listo, debe descomentar la linea en jest.config.js y el codigo que se encuentra en jest.setup.js dentro de la carpeta test, luego tendra que ajustar los tests a su caso de uso.

## Base de datos:

La aplicación esta preparada para trabajar con prisma, pero por causa de la misma configuracion de prisma debe inicializarse con el comando \`npx prisma init\`, en caso de querer declarar la base de datos a utilizar se deberia ejecutar \`npx prisma init --datasource-provider sqlite\` en el caso de querer utilzar squlite, o mongodb o mysql, por defecto prisma viene preparado para postgresql. En el archivo schema.prisma (que se genera al hacer prisma init) se deben declarar las tablas, asociaciones etc.


### Manejo de errores:

La funcion catchController se utiliza para envolver a los controladores como esta detallado en \`GenericController.js\`.

La función \`throwError\` es para los servicios, esta espera un mensaje y un estado. Ejemplo:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";
// Esta importación es solo a modo de ejemplo

eh.throwError("Usuario no encontrado", 404);
\`\`\`

La función \`middError\` está diseñada para usarse en los middlewares de este modo:

\`\`\`javascript
import eh from "./Configs/errorHandlers.js";
// Esta importación es solo a modo de ejemplo

if (!user) {
  return next(eh.middError("Falta el usuario", 400));
}
\`\`\`

### Acerca de MiddlewareHandler.js

Esta clase estática alberga una serie de métodos, muchos de los cuales no se utilizan (y no se deberian utilizar) de manera directa, más bien son funciones auxiliares de los middlewares activos que están alli como una manera de evitar escribir codigo repetitivo. 

Los métodos de validación de esta clase son los siguientes:

- validateFields: validacion y tipado de un conjunto de datos del body,
- validateFieldsWithItems: validacion y tipado de un objeto con un array de objetos anidado,
- validateQuery: validacion y tipado de queries (Por causa de Express 5 crea una copia de esta).
- validateRegex: validacion de parametro del body por medio de regex,
- middUuid: validacion de UUID
- middIntId: validacion de id como numero entero.

#### validateFields:
\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
// Los elementos se validan ingresando el nombre y el tipo de dato dentro de un objeto:
const user = [{name: 'email', type: 'string'}, {name: 'password', type: 'string'}, {name:'phone', type: 'int'}]
// y en el router:
router.post('/', MiddlewareHandler.validateFields(user), controlador)

//Los tipos de datos permitidos son: 
'string': //para los strings,
'int': //para numeros enteros,
'float'. //para numeros decimales,
'boolean' //para booleanos
'array' //en el caso de un array (no valida su interior)

\`\`\`
Cabe aclarar que en caso de validateFields, validateFieldsWithItems y validateQuery los datos que no estén declarados serán borrados del body, los que estén declarados y falten se emitirá el mensaje y status de error correspondientes asi como tambien en el caso de no poder convertir un dato a su correspondiente tipo. 
<hr>

#### validateFieldsWithItems:
Este metodo es similar al anterior solo que valida tambien un array 
\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
// Los elementos se validan ingresando el nombre y el tipo de dato dentro de un objeto:
const user = [{name: 'email', type: 'string'}, {name: 'password', type: 'string'}, {name:'phone', type: 'int'}]
const address = [{name:'street', type:'string'}, {name:'number', type:'int'}]
// y en el router:
router.post('/', MiddlewareHandler.validateFieldsWithItems(user, address, 'address'), controlador)
 //Es necesario ingresar el nombre de la propiedad que va a evaluarse, en nuestro caso el json se veria asi:
 {
    "name": "Leanne Graham",
    "password": "xxxxxxxx",
    "phone": 5578896,
    "address":[{
        "street": "Kulas Light",
         "number": 225
        },
        {
          "street": "Victor Plains",
         "number": 1230
        }]
  }
\`\`\`
<hr>

### validateQuery
Los tipos de datos y validacion son los mismos que para los metodos anteriores, solo que en este caso se examina el objeto req.query:

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
const queries = [
  { name: 'page', type: 'int' },
  { name: 'size', type: 'float' },
  { name: 'fields', type: 'string' },
  { name: 'truthy', type: 'boolean' }
]
router.get('/', MiddlewareHandler.validateQuery(queries),controlador)
//Y en este caso la url se veria asi:
//http://localhost:4000?page=2&size=2.5&fields=pepe&truthy=true'

\`\`\`
El objeto req.query quedará tal como está, ya que Express a partir de la version 5 lo convierte en un objeto inmutable, pero se hará una copia con los datos validados (validacion de los existentes y si no están crea por defecto) en el controlador a través de req.validatedQuery.

<hr>

### validateRegex
Este método se utiliza para validar por medio de regex una propiedad del body que lo requiera, es muy util para validar emails y passwords.
Los parametros requeridos son: el regex (que puede estar como en el ejemplo, en una variable), el nombres de la propiedad a validar y un mensaje si se quiere añadir algo al "Invalid xxx format".

\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...
const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

router.post('/', MiddlewareHandler.validateRegex(emailRegex, 'email', 'Introduzca un mail valido'),controlador)
\`\`\`
<hr>

### middUuid y middIntid 

Están juntos ya que su funcionamiento es igual en ambos casos, solo cambia el tipo de dato a validar, en ambos se debe especificar el nombre dado al parametro a evaluar, por ejemplo:
\`\`\`javascript
import MiddlewareHandler from '../MiddlewareHandler.js'
// Otras importaciones...

router.get('/:userId', MiddlewareHandler.middIntId('userId'), controlador)

\`\`\`
El nombre aqui es solo ilustrativo, adoptará el nombre que se le pase.

Con esto se trató de alcanzar la mayor cantidad de casos de uso posibles, por supuesto, puede haber muchisimos más pero una gran parte ha quedado cubierta.
<hr>

Espero que esta breve explicación sirva. ¡Suerte!
EOL