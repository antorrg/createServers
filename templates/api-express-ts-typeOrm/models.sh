#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la base de modelos
mkdir -p "$PROJECT_DIR/Models"
cat > "$PROJECT_DIR/Models/index.entities.ts" <<EOL
import { User } from './user.entity.js'

export default [
  User
]

EOL
#Crear el modelo de user
cat > "$PROJECT_DIR/Models/user.entity.ts" <<EOL
import { Entity, Column } from 'typeorm'
import { BaseEntity } from './BaseEntity.js'

@Entity({
  name: 'users'
})
export class User extends BaseEntity {
  @Column({ type: 'varchar', length: 100, unique: true })
    email!: string

  @Column({ type: 'varchar', length: 100 })
    password!: string

  @Column({ type: 'varchar', length: 100 })
    nickname!: string

  @Column({ type: 'varchar', length: 255 })
    picture!: string

  @Column({ type: 'varchar', length: 100, nullable: true })
    name?: string
}
EOL


cat > "$PROJECT_DIR/Models/BaseEntity.ts" <<EOL
import {
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  BaseEntity as TypeOrmBaseEntity,
  Column
} from 'typeorm'

export abstract class BaseEntity extends TypeOrmBaseEntity {
  @PrimaryGeneratedColumn('uuid')
    id!: string

  @CreateDateColumn({ name: 'created_at' })
    createdAt!: Date

  @UpdateDateColumn({ name: 'updated_at' })
    updatedAt!: Date

  @DeleteDateColumn({ name: 'deleted_at', nullable: true })
    deletedAt?: Date

  @Column({ type: 'boolean', default: true })
    enabled!: boolean

  // Métodos comunes que podrían ser útiles para todas las entidades
  toJSON (): Record<string, any> {
    const obj = { ...this }
    delete obj.deletedAt // Por ejemplo, no mostrar campos internos
    return obj
  }
}
EOL
