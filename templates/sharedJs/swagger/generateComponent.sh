#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear archivo generadpr de json para jsdoc
cat > "$PROJECT_DIR/src/Shared/Swagger/schemas/tools/generateComponentSchema.js" <<EOL
import inquirer from 'inquirer'
import fs from 'fs/promises'
import path from 'path'

export async function generateComponentSchema () {
  const { componentName } = await inquirer.prompt([
    {
      type: 'input',
      name: 'componentName',
      message: 'Nombre del componente (por ejemplo: User):',
      validate: input => input.trim() ? true : 'Este campo es obligatorio.'

    }
  ])

  const { numFields } = await inquirer.prompt([
    {
      type: 'number',
      name: 'numFields',
      message: \`¿Cuántos campos tiene el componente "\${componentName}"?\`,
      validate: (input) => {
        const num = typeof input === 'number' ? input : Number(input)
        if (!isNaN(num) && num > 0) return true
        return 'Debe haber al menos un campo.'
      }
    }
  ])

  const properties = {}
  const required = []

  for (let i = 0; i < numFields; i++) {
    console.log(\`\n--- Campo #\${i + 1} ---\`)
    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'fieldName',
        message: 'Nombre del campo:',
        validate: input => input.trim() ? true : 'Este campo es obligatorio.'
      },
      {
        type: 'list',
        name: 'type',
        message: 'Tipo del campo:',
        choices: ['string', 'integer', 'boolean', 'number']
      },
      {
        type: 'input',
        name: 'example',
        message: 'Ejemplo del campo:'
      },
      {
        type: 'confirm',
        name: 'isRequired',
        message: '¿Es un campo requerido?',
        default: true
      }
    ])

    const { fieldName, type, example, isRequired } = answers

    properties[fieldName] = {
      type,
      example: castExample(type, example)
    }

    if (isRequired) {
      required.push(fieldName)
    }
  }

  const schema = {
    [componentName]: {
      type: 'object',
      properties,
      ...(required.length > 0 && { required })
    }
  }

  console.log(\`\n✅ Componente Swagger generado para "\${componentName}":\n\`)
  console.dir(schema, { depth: null, colors: true })
  const outDir = path.resolve(process.cwd(), 'src/Shared/Swagger/schemas/components')
  const filePath = path.join(outDir, \`\${componentName.toLowerCase()}.schema.json\`)
  await fs.writeFile(filePath, JSON.stringify(schema, null, 2))

  console.log(\`\n📁 Guardado en: \${filePath}\`)

  return schema
}

// Función auxiliar para convertir ejemplo a su tipo real
function castExample (type, value) {
  if (!value) return undefined
  if (type === 'integer') return parseInt(value, 10)
  if (type === 'number') return parseFloat(value)
  if (type === 'boolean') return value.toLowerCase() === 'true'
  return value
}
EOL