# createServers

Application written in **Bash** to quickly and consistently generate **REST APIs** in **Node.js**.

[You can read this in spanish](/templates/apuntes.md)


---

## 📌 Description

`createServers` is a tool designed to **create and manage boilerplates** for backend applications in Node.js, mainly using **Express** or **Fastify**, implementing different design paradigms and supporting multiple **ORMs/ODMs**.

Its goal is to **streamline development** by providing a ready-to-use environment with:

* Organized folder structure
* Environment configuration
* Unit and integration tests
* Preconfigured functions and utilities

---

## 🚀 Main Features

* **Supported frameworks**:

  * Express
  * Fastify

* **Available ORMs/ODMs**:

  * Sequelize
  * Prisma
  * TypeORM
  * Mongoose

* **Supported languages**:

  * JavaScript
  * TypeScript

* **Compatibility**: Node.js **v20+**

* **Preconfigured environments**: Development, Testing, and Production

* **Ready-to-use templates** including:

  * Controllers
  * Services
  * Repositories
  * Middlewares
  * Modular routing
  * Initialization scripts
  * Default database user
  * Unit tests for each module
  * Functional integration test

---

## ⚙️ Requirements

* **Bash** installed
* On Windows, **Git Bash** or a compatible environment is required
* **Node.js v20 or later**

---

## 📂 What it generates

A REST API created with `createServers` includes:

1. **Environment separation** based on the initialization script
2. **Database connection** depending on the chosen ORM/ODM
3. **Default initial user** for testing
4. **Modular structure** with a clear separation between **generic code** and **feature-specific code**:

```
 ├── package.json
 ├── index.js
 ├── models (or prisma)
 |
src/
 ├── app.js
 ├── routes.js
 ├── Configs/
 |
 ├── Shared/                  # Generic reusable code
 │   ├── Controllers/
 │   ├── Middlewares/
 │   ├── Repositories/
 │   ├── Auth/
 │   └── Services/
 │
 └── Features/                # Feature-specific implementations
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

> **Flow:** Features import generic implementations from `Shared` and adapt them according to the needs of each module (User, Product, etc.).

5. **Unit tests** for each entity (also serving as documentation)
6. **Integration test** to validate overall functionality

---

## 🛠 Installation & Usage

```bash
# Clone the repository
git clone https://github.com/yourusername/createServers.git

# Grant execution permissions
chmod +x createServer.sh

# Run the script
./createServer.sh
# or:
bash createServer.sh
```

The script will guide you step-by-step to choose:

* Framework
* ORM/ODM
* Language
* Initial configuration

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](./LICENSE) file for more details.
