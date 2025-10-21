#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"


cat > "$PROJECT_DIR/README.md" <<EOL
# Api $PROYECTO_VALIDO de Express con Typescript

Base para el proyecto $PROYECTO_VALIDO de Express.ts con entornos de ejecución y manejo de errores.

## Sobre la API:

Esta API fue construida de manera híbrida. Es decir, la parte de Repositories, Services y Controllers está desarrollada bajo el paradigma OOP (Programación Orientada a Objetos). Sin embargo, los routers y la aplicación en sí no lo están.

En esta plantilla encontrará ambos paradigmas funcionando codo a codo. A partir de aquí, puede adaptarla según su preferencia. Si bien está construida de una manera básica, es funcional. Al revisar el código podrá ver, si desea mantener este enfoque, cómo continuar. ¡Buena suerte y buen código!

## Cómo comenzar:

### Instalaciones:

La app viene con las instalaciones básicas para comenzar a trabajar con typeOrm y una base de datos PostgreSQl. Las variables de entorno vienen ya con un usuario por defecto (random) y una base de datos ficticia, usted deberia cambiar esto por su propia base de datos apropiada para cada entorno.

### Scripts disponibles:

- \`npm start\`: Inicializa la app en modo producción con Node.js y Express (.env.production).
- \`npm run dev\`: Inicializa la app en modo desarrollo con jsx y Express (.env.development).
- \`npm test\`: Ejecuta todos los tests. También puede ejecutarse un test específico, por ejemplo: \`npm test EnvDb\`. La app se inicializa en modo test (.env.test).
- \`npm run lint\`: Ejecuta el linter analiza el codigo y corrige automáticamente los errores.
- \`npm run gen:schema\`: Inicializa la función \`generateSchema\`, que genera documentación Swagger para las rutas mediante una guía por consola. Si bien es susceptible de mejora, actualmente resulta muy útil para agilizar el trabajo de documentación.

La aplicación incluye un servicio de ejemplo que muestra su funcionalidad. En la carpeta \`Features/user\` se encuentra un servicio modelo de usuario, con un Servicio, Controlador, userMapper, middleware. El archivo \`user.route.ts\` conecta esta funcionalidad con la app a través de \`mainRouter\` (\`routes.ts\`).

La aplicación puede ejecutarse con \`npm run dev\` (modo desarrollo) o \`npm start\` (producción). Para ejecutar npm start es necesario antes ejecutar npm run build para traspilar el codigo TS en JS. Tambien puede (sería lo ideal) desarrollar la app por medio de los test, lo cual puede hacerse desde el comienzo.

Se requieren al menos dos bases de datos: una para desarrollo y otra para test.

### Documentación y rutas:

Esta api cuenta con documentación por medio de Swagger, al inicializar la app en modo dev aparecerá el endpoint (link que se abre con el navegador) adonde se verán los endpoints declarados.

Suele darse el caso (como en el ejemplo dado en la app) que haya endpoints protegidos por token, en ese caso, en el endpoint \`user/login\` es necesario hacer login con los datos del usuario de ejemplo, luego en el resultado copiar el token resultante y pegarlo en la ventana que se abrirá al hacer click en \`authorize\`, seguir los pasos y automaticamente se podrá acceder a todos los endpoints protegidos de la app.

Los endpoints se ordenan automaticamente por lo tanto, lo más probable es que los encuentre ordenados alfabeticamente.

Para crear los endpoints simplemente se ejecuta el comando \`npm run gen:schema\`, y aparecerá en la consola un menú interactivo adonde podrá ingresar los items, campos, parametros y rutas.

La documentación se escribe en \`jsdoc\`, asimismo se creará un archivo \`json\` con los parametros, el menú los guiará y automáticamente se añadiran a la documentación. Es posible que en los casos en que haya endpoints especiales como login y otros, haya que crearlos a mano en el mismo archivo, asi como también si se utilza o no protección con jwt, pero esta automatización garantiza que una gran parte del trabajo estará hecha y servirá de modelo a todo lo que haya que documentar.

### Manejo de errores:

- La función \`throwError\` se utiliza en los servicios. Recibe un mensaje y un código de estado retornando un mensaje de error con status:

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


Se ha intentado cubrir la mayor cantidad de casos de uso posibles. Por supuesto, pueden existir muchos más, pero esta base ofrece un punto de partida sólido.

---

Espero que esta explicación te sea útil. ¡Suerte!
EOL