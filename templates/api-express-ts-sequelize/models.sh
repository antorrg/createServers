#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la base de modelos
mkdir -p "$PROJECT_DIR/Models"
cat > "$PROJECT_DIR/Models/index.ts" <<EOL
import User from './user.model.js'

export default {
  User
}
EOL
#Crear el modelo de user
cat > "$PROJECT_DIR/Models/user.model.ts" <<EOL
import { type Sequelize, DataTypes, Model, type Optional } from 'sequelize'

// Atributos que tiene la tabla
export interface UserAttributes {
  id: string
  email: string
  password: string
  nickname?: string | null
  name?: string | null
  picture?: string | null
  enabled: boolean
}

// Atributos opcionales al crear (por ejemplo `id` lo genera Sequelize)
export type UserCreationAttributes = Optional<
UserAttributes,
'id' | 'nickname' | 'name' | 'picture' | 'enabled'
>

// Definición de la clase User tipada
export class User
  extends Model<UserAttributes, UserCreationAttributes>
  implements UserAttributes {
  declare id: string
  declare email: string
  declare password: string
  declare nickname: string | null
  declare name: string | null
  declare picture: string | null
  declare enabled: boolean
}

// Función que define el modelo 
export default (sequelize: Sequelize) => {
  User.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        allowNull: false,
        primaryKey: true
      },
      email: {
        type: DataTypes.STRING,
        allowNull: false
      },
      password: {
        type: DataTypes.STRING,
        allowNull: false
      },
      nickname: {
        type: DataTypes.STRING,
        allowNull: true
      },
      name: {
        type: DataTypes.STRING,
        allowNull: true
      },
      picture: {
        type: DataTypes.STRING,
        allowNull: true
      },
      enabled: {
        type: DataTypes.BOOLEAN,
        allowNull: true,
        defaultValue: true
      }
    },
    {
      sequelize,
      tableName: 'users',
      timestamps: false
    }
  )

  return User
}
EOL
