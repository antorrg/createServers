#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el archivo package.json
cat > "$PROJECT_DIR/package.json" <<EOL
{
  "name": "$PROYECTO_PACKAGE",
  "version": "1.0.0",
  "main": "dist/index.js",
  "type": "module",
  "directories": {
    "test": "test"
  },
  "scripts": {
    "dev": "cross-env NODE_ENV=development tsx watch index.ts",
    "build": "tsc",
    "start": "cross-env NODE_ENV=production node dist/index.js",
    "lint": "eslint . --ext ts,js --fix",
    "test": "cross-env NODE_ENV=test vitest --run",
    "gen:schema": "tsx src/Shared/Swagger/schemas/tools/generateSchema.ts"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "description": "",
  "dependencies": {
  },
  "devDependencies": {
  }
}
EOL
##########
# Crear el .eslintrc.cjs
cat > "$PROJECT_DIR/.eslintrc.cjs" <<EOL
module.exports = {
    root: true,
    parser: "@typescript-eslint/parser",
    plugins: ["@typescript-eslint"],
    extends: ["standard-with-typescript"],
    parserOptions: {
        project: "./tsconfig.eslint.json"
    }
}
EOL
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#Crear el tsconfig el tsconfig.test y el tsconfig.eslint.json

cat > "$PROJECT_DIR/tsconfig.json" <<EOL
{
"compilerOptions": {
"incremental": true,
"target": "ESNext",
"module": "NodeNext",
"removeComments": true,
"moduleResolution": "NodeNext",
"types": ["node"],
"resolveJsonModule": true,
"noEmit": false,
"outDir": "dist",
"isolatedModules": true,
"experimentalDecorators": true,         // NECESARIO para TypeORM y validadores
"emitDecoratorMetadata": true,          // NECESARIO para reflejar tipos en decoradores
"allowSyntheticDefaultImports": true,
"esModuleInterop": true,
"forceConsistentCasingInFileNames": true,
"strict": true,
"strictPropertyInitialization": true
  },
  "include": [
    "index.ts",
    "src/**/*.ts",
    "src/@types/**/*.d.ts", "src/Shared/Swagger/schemas/tools/generateSchema.ts",
      
  ],
  "exclude": [
    "node_modules",
    "dist",
    "data", 
    "test",
    "**/*.test.ts",
    "**/*.help.ts"
  ]
}
EOL
# Crear el archivo tsconfig.test.json
cat > "$PROJECT_DIR/tsconfig.test.json" <<EOL
{
  "extends": "./tsconfig.json",
  "include": [
    "index.ts",
    "src/**/*.ts",
    "test/**/*.ts",
  ],
  "exclude": [
    "node_modules",
    "dist",
    "data"
  ]
}
EOL
# Crear el archivo tsconfig.eslint.json
cat > "$PROJECT_DIR/tsconfig.eslint.json" <<EOL
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "noEmit": true
  },
  "include": [
    "src/**/*",
    "test/**/*",
    "vitest.config.ts",
    "index.ts",
    "**/*.test.ts",
    "**/*.help.ts"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
EOL
# Crear el archivo .gitignore
cat > "$PROJECT_DIR/.gitignore" <<EOL
# ---------------------------------------
# Logs
# ---------------------------------------
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# Diagnostic reports
report.[0-9]*.[0-9]*.[0-9]*.[0-9]*.json

# ---------------------------------------
# Runtime data
# ---------------------------------------
pids
*.pid
*.seed
*.pid.lock

# ---------------------------------------
# Coverage / testing
# ---------------------------------------
lib-cov
coverage
*.lcov
.nyc_output

# ---------------------------------------
# Dependency directories
# ---------------------------------------
node_modules/
dist/

# ---------------------------------------
# Assets (uploads temporales)
# ---------------------------------------
assets/uploads/*
!assets/uploads/.gitkeep
data/

# ---------------------------------------
# TypeScript cache
# ---------------------------------------
*.tsbuildinfo

# ---------------------------------------
# npm cache (opcional)
# ---------------------------------------
.npm

# ---------------------------------------
# Firebase (si lo usás)
# ---------------------------------------
firebase-admin-key.json

# ---------------------------------------
# ESLint y Stylelint cache
# ---------------------------------------
.eslintcache
.stylelintcache

# ---------------------------------------
# REPL history
# ---------------------------------------
.node_repl_history

# ---------------------------------------
# npm pack output
# ---------------------------------------
*.tgz

# ---------------------------------------
# dotenv environment variable files
# ---------------------------------------
.env
.env.*
!.env.example

# ---------------------------------------
# VSCode (opcional)
# ---------------------------------------
.vscode-test
EOL