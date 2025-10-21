#!/bin/bash


PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO" 

# Crear la base de modelos
mkdir -p "$PROJECT_DIR/Schemas"
cat > "$PROJECT_DIR/Schemas/user.model.ts" <<EOL
import {Schema, model, type InferSchemaType, type HydratedDocument } from "mongoose";


    const userSchema = new Schema({
        email: {type: String, required: true, unique:true},
        password: {type: String, required: true},
        nickname: {type: String, required: false},
        name: {type: String, required: false},
        picture: {type:String, required: false},
        enabled: {type: Boolean, default: true, required: true}
    },{
        timestamps:false
    }
)
export type IMongooseUser = InferSchemaType<typeof userSchema>
export type IUserDocument = HydratedDocument<IMongooseUser>

const User = model<IUserDocument>('User', userSchema)

export default User
EOL