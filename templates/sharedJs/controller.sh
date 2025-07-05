#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el controlador
cat > "$PROJECT_DIR/src/Shared/Controllers/BaseController.js" <<EOL
import { catchController } from '../../Configs/errorHandlers.js'

export class BaseController {

  constructor (service) {
    this.service = service
  }

  static responder (
    res,
    status,
    success,
    message,
    results
  ) {
    return res.status(status).json({ success, message, results })
  }

  getAll = catchController(async (req, res) => {
    const response = await this.service.getAll()
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  findWithPagination = catchController(async (req, res) => {
    const { page, limit, sort, ...filters } = req.query
    // Parse sort: admite ?sort=title,-1 o ?sort=title:desc
    const sortObj: Record<string, 1 | -1> = {}
    if (typeof sort === 'string') {
    // Ejemplo: sort=title,-1  o  sort=title:desc
      const [field, order] = sort.includes(':') ? sort.split(':') : sort.split(',')
      if (field && order) {
        const ord = order === '-1' || order === 'desc' ? -1 : 1
        sortObj[field] = ord
      }
    }
    const response = await this.service.findWithPagination({
      page: Number(page),
      limit: Number(limit),
      sort: sortObj,
      filters
    })
    return BaseController.responder(res, 200, true, response.message, {
      info: response.info,
      results: response.results
    })
  })

  getById = catchController(async (req, res) => {
    const { id } = req.params
    const response = await this.service.getById(id)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  create = catchController(async (req, res) => {
    const data = req.body
    const response = await this.service.create(data)
    return BaseController.responder(res, 201, true, response.message, response.results)
  })

  update = catchController(async (req, res) => {
    const { id } = req.params
    const data = req.body
    const response = await this.service.update(id, data)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  delete = catchController(async (req, res) => {
    const { id } = req.params
    const response = await this.service.delete(id)
    return BaseController.responder(res, 200, true, response.message, null)
  })
}
EOL