#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el controlador
cat > "$PROJECT_DIR/src/Shared/Controllers/parseSort.ts" <<EOL
export default function parseSort(sort: string | undefined): Record<string, 1 | -1> {
  const sortObj: Record<string, 1 | -1> = {}
  if (typeof sort === 'string') {
    const [field, order] = sort.includes(':') ? sort.split(':') : sort.split(',')
    if (field && order) {
      sortObj[field] = order === '-1' || order === 'desc' ? -1 : 1
    }
  }
  return sortObj
}
EOL