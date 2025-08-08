#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el controlador
cat > "$PROJECT_DIR/src/Shared/Controllers/BaseController.js" <<EOL
import { catchController } from '../../Configs/errorHandlers.js'
import { queryHelper } from './queryHelper.js'

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
    // console.log('a ver las queries: ', req.context.query)
    const response = await this.service.getAll()
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  getWithPagination = catchController(async (req, res) => {
    const response = await this.service.getWithPagination(queryHelper(req.context.query))
    return BaseController.responder(res, 200, true, response.message, {
      info: response.results.info,
      data: response.results.data
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
    return BaseController.responder(res, 200, true, response.message, response.results)
  })
}
EOL