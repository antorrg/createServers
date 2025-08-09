#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

mkdir -p $PROJECT_DIR/models

cat > "$PROJECT_DIR/models/user.js" <<EOL
import mongoose from 'mongoose'
import { applyBaseSchema } from './baseSchemaMixin.js'

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true
    },
    password: {
      type: String,
      required: true
    },
    picture: {
      type: String,
      required: true
    },
    username: {
      type: String,
      required: false
    },
    role: {
      type: Number,
      enum: [1, 2, 3, 9],
      default: 1,
      required: true
    },
  },
  {
    timestamps: true
  }
)

applyBaseSchema(userSchema)

const User = mongoose.model('User', userSchema)

export default User
EOL


cat > "$PROJECT_DIR/models/baseSchemaMixin.js" <<EOL
const baseSchemaFields = {
  enabled: { type: Boolean, default: true },
  deleted: { type: Boolean, default: false }
}

export function applyBaseSchema (schema) {
  schema.add(baseSchemaFields)

  // Garantiza que los campos estén siempre presentes
  schema.pre('save', function (next) {
    if (this.enabled === undefined) this.enabled = true
    if (this.deleted === undefined) this.deleted = false
    next()
  })

  // Método de instancia: soft delete
  schema.methods.softDelete = function () {
    this.deleted = true
    this.enabled = false
    return this.save()
  }

  // Método estático: encuentra solo activos
  schema.statics.findEnabled = function (filter = {}) {
    return this.find({ ...filter, enabled: true, deleted: false })
  }

  return schema
}
EOL