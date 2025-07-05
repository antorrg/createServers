#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

# Crear el controlador
cat > "$PROJECT_DIR/src/Shared/Controllers/BaseController.ts" <<EOL
import { Request, Response } from 'express'
import { ObjectLiteral } from 'typeorm'
import { catchController } from '../../Configs/errorHandlers.js'
import { BaseService } from '../Services/BaseService.js'

export class BaseController<T extends ObjectLiteral> {
  protected service: BaseService<T>

  constructor (service: BaseService<T>) {
    this.service = service
  }

  static responder (
    res: Response,
    status: number,
    success: boolean,
    message: string,
    results: any
  ) {
    return res.status(status).json({ success, message, results })
  }

  getAll = catchController(async (req: Request, res: Response) => {
    const response = await this.service.getAll()
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  findWithPagination = catchController(async (req: Request, res: Response) => {
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

  getById = catchController(async (req: Request, res: Response) => {
    const { id } = req.params
    const response = await this.service.getById(id)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })
  getOne = catchController(async (req: Request, res: Response) => {
    const search: any = req.query
    const response = await this.service.getOne(search)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  create = catchController(async (req: Request, res: Response) => {
    const data = req.body
    const response = await this.service.create(data)
    return BaseController.responder(res, 201, true, response.message, response.results)
  })

  update = catchController(async (req: Request, res: Response) => {
    const { id } = req.params
    const data = req.body
    const response = await this.service.update(id, data)
    return BaseController.responder(res, 200, true, response.message, response.results)
  })

  delete = catchController(async (req: Request, res: Response) => {
    const { id } = req.params
    const response = await this.service.delete(id)
    return BaseController.responder(res, 200, true, response.message, null)
  })
}
EOL