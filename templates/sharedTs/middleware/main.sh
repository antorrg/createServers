#!/bin/bash

PROJECT_DIR="$(dirname "$(pwd)")/$PROYECTO_VALIDO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIDD="$SCRIPT_DIR/"



source "$MIDD/complexFields.sh" "$PROYECTO_VALIDO"
source "$MIDD/helperFn.sh" "$PROYECTO_VALIDO"
source "$MIDD/middleware.sh" "$PROYECTO_VALIDO"
source "$MIDD/serverTest.sh" "$PROYECTO_VALIDO"
source "$MIDD/tests.sh" "$PROYECTO_VALIDO"