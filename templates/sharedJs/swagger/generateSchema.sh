#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivo para creacion guiada de jsdoc
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/tools/generateSchema.js" <<EOL
import fs from 'fs';
import path from 'path';
import inquirer from 'inquirer';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { generateComponentSchema } from './generateComponentSchema.js';


const __dirname = dirname(fileURLToPath(import.meta.url));
const outputPath = path.join(__dirname, '../../schemas');

const askFields = async ()=> {
  const fields= [];
  let addMore = true;

  while (addMore) {
    const { name, type, format } = await inquirer.prompt([
      { type: 'input', name: 'name', message: 'Nombre del campo (ej: title)' },
      {
        type: 'list',
        name: 'type',
        message: 'Tipo de dato',
        choices: ['string', 'number', 'boolean', 'integer']
      },
      {
        type: 'input',
        name: 'format',
        message: 'Formato (opcional, ej: email, date-time)',
        default: '',
        validate: (input) => true
      }
    ]);

    const field = { name, type };
    if (format.trim()) field.format = format.trim();
    fields.push(field);

    const { shouldContinue } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'shouldContinue',
        message: '¿Querés agregar otro campo?',
        default: true
      }
    ]);

    addMore = shouldContinue;
  }

  return fields;
};

const askParameters = async (kind = 'path') => {
  const result = [];
  let addMore = true;

  while (addMore) {
    const { name, type, description, required } = await inquirer.prompt([
      { type: 'input', name: 'name', message: \`Nombre del parámetro (\${kind})\` },
      {
        type: 'list',
        name: 'type',
        message: 'Tipo de dato',
        choices: ['string', 'integer', 'boolean']
      },
      { type: 'input', name: 'description', message: 'Descripción' },
      {
        type: 'confirm',
        name: 'required',
        message: '¿Es requerido?',
        default: kind === 'path'
      }
    ]);

    result.push({ name, in: kind, type, description, required });

    const { shouldContinue } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'shouldContinue',
        message: \`¿Querés agregar otro parámetro (\${kind})?\`,
        default: false
      }
    ]);

    addMore = shouldContinue;
  }

  return result;
};

const askSchemaInfo = async () => {
  const { tag } = await inquirer.prompt([
    { type: 'input', name: 'tag', message: 'Nombre del tag (ej: Users)' }
  ]);

  const { singular } = await inquirer.prompt([
    { type: 'input', name: 'singular', message: 'Nombre singular del recurso (ej: user)' }
  ]);

  const fields = await askFields();
  const pathParams = await askParameters('path');
  const queryParams = await askParameters('query');

  const { includeSchema } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'includeSchema',
      message: '¿Querés incluir la definición reusable (components.schemas)?',
      default: false
    }
  ]);
  const { basePrefix } = await inquirer.prompt([
  {
    type: 'input',
    name: 'basePrefix',
    message: '¿Cuál es el path base para la ruta? (ej: api, api/v1 o vacío para raíz)',
    default: 'api'
  }
]);

  return {
    tag,
    singular,
    fields,
    pathParams,
    queryParams,
    includeSchema,
    basePrefix
  };
};

const buildPropertiesBlock = (fields, indent = '            ') => {
  return fields.map(f => {
    const example =
      f.type === 'string' ? \`\${f.name} ejemplo\` :
      f.type === 'boolean' ? true :
      1;

    return \`\${indent}\${f.name}:\n\${indent}  type: \${f.type}\${f.format ? \`\n\${indent}  format: \${f.format}\` : ''}\n\${indent}  example: \${example}\n\${indent}  description: Descripción de \${f.name}\`;
  }).join('\n');
};

// 👇 cambia el método renderParameters
const renderParameters = (params, indent = '    ')=> {
  if (!params.length) return '';
  return \`\${indent}parameters:\n\${params.map(p => (
\`\${indent}  - in: \${p.in}
\${indent}    name: \${p.name}
\${indent}    required: \${p.required}
\${indent}    schema:
\${indent}      type: \${p.type}
\${indent}    description: \${p.description}\`
  )).join('\n')}\`;
};

const wrapWithJSDoc = (content) => {
  return '/**\n' + content.trim().split('\n').map(line => line.trim() ? \`* \${line}\` : '*').join('\n') + '\n */';
};

const generateJSDoc = (schema)=> {
  const { tag, singular, fields, pathParams, queryParams, includeSchema } = schema
  const schemaName = singular.charAt(0).toUpperCase() + singular.slice(1);
  const upperTag = tag.charAt(0).toUpperCase() + tag.slice(1);
  const required = fields.map(f => \`               - \${f.name}\`).join('\n');
  const props = buildPropertiesBlock(fields);
  const parametersBlock = renderParameters([...pathParams, ...queryParams]);
  const allParametersBlock = renderParameters(queryParams)

  //const basePath = \`/api/\${singular}\`;
  const prefix = schema.basePrefix?.replace(/^\/|\/$/g, ''); // limpia barras
  const basePath = \`/\${[prefix, singular].filter(Boolean).join('/')}\`;
  const pathWithId = \`\${basePath}/{id}\`;
  const blocks = [];

  // Tag block
  blocks.push(wrapWithJSDoc(\`
@swagger
tags:
  - name: \${upperTag}
    description: Operaciones relacionadas con \${tag.toLowerCase()}
\`));

  // Schema block (solo una vez si includeSchema es true)
  if (includeSchema) {
    blocks.push(wrapWithJSDoc(\`
@swagger
components:
  schemas:
    \${schemaName}:
      type: object
      properties:
\${props}
\`));
  }

  // Endpoints
  blocks.push(wrapWithJSDoc(\`
@swagger
'\${basePath}':
  post:
    summary: Crear un nuevo \${singular}
    tags: [\${upperTag}]
    requestBody:
      required: true
      content:
        application/json:
          schema:
            type: object
            required:
\${required}
            properties:
\${props}
    responses:
      201:
        description: Creación exitosa
        content:
          application/json:
            schema:
              type: object
              properties:
                success:
                  type: boolean
                message:
                  type: string
                results:
                  \$ref: '#/components/schemas/\${schemaName}'
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${basePath}':
  get:
    summary: Obtener todos los \${singular}s
    tags: [\${upperTag}]
\${allParametersBlock}
    responses:
      200:
        description: Lista de \${singular}s
        content:
          application/json:
            schema:
              type: array
              items:
                \$ref: '#/components/schemas/\${schemaName}'
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${pathWithId}':
  get:
    summary: Obtener un \${singular} por ID
    tags: [\${upperTag}]
\${renderParameters(pathParams)}
    responses:
      200:
        description: \${singular} encontrado
        content:
          application/json:
            schema:
              \$ref: '#/components/schemas/\${schemaName}'
      404:
        description: \${singular} no encontrado
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${pathWithId}':
  put:
    summary: Actualizar un \${singular}
    tags: [\${upperTag}]
\${renderParameters(pathParams)}
    requestBody:
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
\${props}
    responses:
      200:
        description: Actualización exitosa
      400:
        description: Error de validación
\`));

  blocks.push(wrapWithJSDoc(\`
@swagger
'\${pathWithId}':
  delete:
    summary: Eliminar un \${singular}
    tags: [\${upperTag}]
\${renderParameters(pathParams)}
    responses:
      200:
        description: Eliminado correctamente
      404:
        description: \${singular} no encontrado
\`));

  return blocks.join('\n\n');
};

const generateSchemaFile = async (schemaInfo) => {
  if (!fs.existsSync(outputPath)) fs.mkdirSync(outputPath, { recursive: true });

  const fileName = \`\${schemaInfo.singular}.jsdoc.js\`;
  const filePath = path.join(outputPath, fileName);
  const jsdocContent = generateJSDoc(schemaInfo);

  fs.writeFileSync(filePath, jsdocContent);
  console.log(\`✅ JSDoc generado: src/Shared/Swagger/schemas/\${fileName}\`);
};

const main = async () => {
  const schemaInfo = await askSchemaInfo();
  await generateSchemaFile(schemaInfo);
  await generateComponentSchema()
};

main();
EOL