#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"


mkdir -p $PROJECT_DIR/models

cat > "$PROJECT_DIR/models/user.js" <<EOL
import {DataTypes} from 'sequelize'

export default (sequelize)=>{
  sequelize.define('User', {
    id: {type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, allowNull: false, primaryKey: true},
    email:  {type: DataTypes.STRING, unique: true, allowNull: false},
    username: {type: DataTypes.STRING, allowNull: true },
    password: {type: DataTypes.STRING, allowNull: false },
    role: {type: DataTypes.SMALLINT, allowNull: false, defaultValue: 1, validate: {isIn: [[9, 1, 2,3]]}},
    picture: { type: DataTypes.STRING, allowNull: false},
    enabled: {type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
    createdAt: {type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW}
  },{
        scopes: {
            enabledOnly: {
                where: {
                    enabled: true
                }
            },
            allRecords: {} // No aplica ningún filtro
        },
        timestamps: false,
       
    })
}
EOL
cat > "$PROJECT_DIR/models/index.js" <<EOL
import User from './user.js'

export default {
    User,
}
EOL