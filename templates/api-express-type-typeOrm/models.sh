#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la base de modelos
cat > "$PROJECT_DIR/src/Shared/Entities/BaseEntity.ts" <<EOL
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
    id: string

  @CreateDateColumn({ name: 'created_at' })
    createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date

  @DeleteDateColumn({ name: 'deleted_at', nullable: true })
    deletedAt?: Date

  @Column({ type: 'boolean', default: true })
    enabled: boolean

  // Métodos comunes que podrían ser útiles para todas las entidades
  toJSON (): Record<string, any> {
    const obj = { ...this }
    delete obj.deletedAt // Por ejemplo, no mostrar campos internos
    return obj
  }
}
EOL

#Crear el modelo de user
cat > "$PROJECT_DIR/src/Shared/Entities/user.entity.ts" <<EOL
import { Entity, Column } from 'typeorm'
import { BaseEntity } from './BaseEntity.js'

@Entity({
  name: 'users'
})
export class User extends BaseEntity {
  @Column({ type: 'varchar', length: 100, unique: true })
    email: string

  @Column({ type: 'varchar', length: 100 })
    password: string

  @Column({ type: 'varchar', length: 100 })
    nickname: string

  @Column({ type: 'varchar', length: 255 })
    picture: string

  @Column({ type: 'varchar', length: 100, nullable: true })
    name?: string

  @Column({ type: 'varchar', length: 100, nullable: true })
    surname?: string

  @Column({ type: 'varchar', length: 100, nullable: true })
    country?: string

  @Column({ type: 'boolean', default: false })
    isVerify: boolean

  @Column({ type: 'int', default: 1 })
    role: number

  @Column({ type: 'boolean', default: false })
    isRoot: boolean
}
EOL
