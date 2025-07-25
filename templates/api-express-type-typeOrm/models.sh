#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la base de modelos
cat > "$PROJECT_DIR/src/Shared/Models/baseSchemaMixin.ts" <<EOL
import { Schema, SchemaDefinition, SchemaDefinitionType } from 'mongoose'

const baseSchemaFields: SchemaDefinition<SchemaDefinitionType<any>> = {
  enabled: { type: Boolean, default: true },
  deleted: { type: Boolean, default: false }
}

export function applyBaseSchema (schema: Schema): Schema {
  schema.add(baseSchemaFields)

  schema.pre('save', function (next) {
    if (this.enabled === undefined) this.enabled = true
    if (this.deleted === undefined) this.deleted = false
    next()
  })

  schema.methods.softDelete = function () {
    this.deleted = true
    this.enabled = false
    return this.save()
  }

  schema.statics.findEnabled = function (filter = {}) {
    return this.find({ ...filter, enabled: true, deleted: false })
  }

  return schema
}
EOL
# Crear el modelo de Test
cat > "$PROJECT_DIR/test/testHelpers/modelTest.help.ts" <<EOL
import mongoose, { Schema, Document, Model } from 'mongoose'
import { applyBaseSchema } from '../../src/Shared/Models/baseSchemaMixin.js'

// 1. Define la interfaz para el documento
export interface ITest extends Document {
  title: string
  count: number
  picture: string
  enabled: boolean
  deleted: boolean
  softDelete: () => Promise<this>
}

// 2. Define el schema con tipos
const testSchema = new Schema<ITest>(
  {
    title: {
      type: String,
      required: true,
      unique: true
    },
    count: {
      type: Number,
      required: true
    },
    picture: {
      type: String,
      required: true
    }
  },
  {
    timestamps: true
  }
)

// 3. Aplica los campos y métodos comunes
applyBaseSchema(testSchema)

// 4. Crea el modelo
const Test: Model<ITest> = mongoose.model<ITest>('Test', testSchema)

export default Test
EOL
#Crear el modelo de user
cat > "$PROJECT_DIR/src/Shared/Models/userModel.ts" <<EOL
import mongoose from 'mongoose'
import { applyBaseSchema } from './baseSchemaMixin.js'

export interface IUser extends mongoose.Document {
  _id: mongoose.Types.ObjectId
  email: string
  password: string
  nickname: string
  picture: string
  name?: string
  surname?: string
  country?: string
  isVerify: boolean
  role: number
  isRoot: boolean
  deleted: boolean
  enabled: boolean
  // ...otros campos heredados de baseSchemaMixin
}

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
    nickname: {
      type: String,
      required: true
    },
    picture: {
      type: String,
      required: true
    },
    name: {
      type: String,
      required: false
    },
    surname: {
      type: String,
      required: false
    },
    country: {
      type: String,
      required: false
    },
    isVerify: {
      type: Boolean,
      default: false,
      required: true
    },
    role: {
      type: Number,
      enum: [1, 2, 3, 9],
      default: 1,
      required: true
    },
    isRoot: {
      type: Boolean,
      default: false,
      required: true
    }

  },
  {
    timestamps: true
  }
)

applyBaseSchema(userSchema)

export const User = mongoose.model<IUser>('User', userSchema)
EOL
