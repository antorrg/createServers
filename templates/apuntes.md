
# createServers

Aplicación escrita en **Bash** para generar **APIs REST** en **Node.js** de forma rápida y estandarizada.

[⬅ Volver a README principal](../README.md)

---

## 📌 Descripción

`createServers` es una herramienta diseñada para **crear y gestionar boilerplates** de aplicaciones backend en Node.js, principalmente con **Express** o **Fastify**, incorporando distintos paradigmas de diseño y soportando múltiples **ORMs/ODMs**.

Su objetivo es **agilizar el desarrollo** proporcionando un entorno listo para usar, con:

* Estructura de carpetas organizada.
* Configuración de entornos.
* Tests unitarios e integración funcional.
* Funciones y utilidades preconfiguradas.

---

## 🚀 Características principales

* **Frameworks soportados**:

  * Express
  * Fastify

* **ORMs/ODMs disponibles**:

  * Sequelize
  * Prisma
  * TypeORM
  * Mongoose

* **Lenguajes soportados**:

  * JavaScript
  * TypeScript

* **Compatibilidad**: Node.js **v20+**.

* **Entornos preconfigurados**: Desarrollo, testing y producción.

* **Plantillas listas para usar** con:

  * Controladores
  * Servicios
  * Repositorios
  * Middlewares
  * Ruteo modular
  * Scripts de inicialización
  * Usuario por defecto en la base de datos
  * Tests unitarios por cada módulo
  * Test de integración funcional

---

## ⚙️ Requisitos

* **Bash** instalado.
* En Windows es necesario contar con **Git Bash** o un entorno compatible.
* **Node.js v20 o superior**.

---

## 📂 Qué genera

Una API REST creada con `createServers` incluye:

1. **División de entornos** según el script de inicialización.
2. **Conexión a base de datos** según el ORM/ODM elegido.
3. **Usuario inicial por defecto** para pruebas.
4. **Estructura modular** con separación clara entre **código genérico** y **código específico de cada feature**:

```
 ├── package.json
 ├── index.js
 ├── models (o prisma)
 |
src/
 ├── app.js
 ├── routes.js
 ├── Configs/
 |
 ├── Shared/                  # Código genérico reutilizable
 │   ├── Controllers/
 │   ├── Middlewares/
 │   ├── Repositories/
 │   ├── Auth/
 │   └── Services/
 │
 └── Features/                # Implementaciones por funcionalidad
     ├── User/
     │   ├── user.controller.js
     │   ├── user.service.js
     │   ├── user.repository.js
     │   └── user.routes.js
     │
     └── Product/
         ├── product.controller.js
         ├── product.service.js
         ├── product.repository.js
         └── product.routes.js
```

> **Flujo:** Las *features* importan las implementaciones genéricas desde `Shared` y las adaptan según las necesidades de cada módulo (User, Product, etc.).

5. **Tests unitarios** en cada entidad (sirven también como documentación).
6. **Test de integración** para validar el funcionamiento general.

---

## 🛠 Instalación y uso

```bash
# Clonar el repositorio
git clone https://github.com/tuusuario/createServers.git

# Dar permisos de ejecución
chmod +x createServer.sh

# Ejecutar el script
./createServer.sh
# o bien:
bash createServer.sh
```

El script te guiará paso a paso para elegir:

* Framework
* ORM/ODM
* Lenguaje
* Configuración inicial

---

## 📄 Licencia

Este proyecto está bajo la licencia **MIT**. Consulta el archivo [LICENSE](./LICENSE) para más información.



