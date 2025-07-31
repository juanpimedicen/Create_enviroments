#!/bin/bash

CONFIG_FILE="./env.config.json"

# Validar que jq est   instalado
if ! command -v jq &> /dev/null; then
    echo "Error: jq no est   instalado. Inst  lalo con: sudo apt install jq"
    exit 1
fi

# Validar argumento
if [[ "$1" != "desa" && "$1" != "prod" ]]; then
    echo "Uso: $0 [desa|prod]"
    exit 1
fi

AMBIENTE=$1

# Validar que el archivo de configuraci  n existe
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Archivo de configuraci  n $CONFIG_FILE no encontrado."
    exit 1
fi

# Extraer y mostrar el bloque JSON del ambiente
jq ".$AMBIENTE" "$CONFIG_FILE"
