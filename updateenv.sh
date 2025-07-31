#!/bin/bash

CONFIG_FILE="./env.config.json"

# Validación de dependencia
if ! command -v jq &>/dev/null; then
  echo "Error: jq no está instalado. Instálalo con: sudo apt install jq"
  exit 1
fi

# Validación de archivo
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Archivo de configuración $CONFIG_FILE no encontrado."
  exit 1
fi

# Función para confirmar acción
confirmar() {
  read -p "$1 [s/N]: " respuesta
  case "$respuesta" in
    [sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# Mostrar resumen del servicio
mostrar_resumen() {
  local servicio="$1"
  echo -e "\n🔍 Resumen del servicio '$servicio':"
  jq --arg s "$servicio" '.desa[$s] as $desa | .prod[$s] as $prod | {desa: $desa, prod: $prod}' "$CONFIG_FILE"
}

# Crear objeto JSON desde un array asociativo
create_obj_json() {
  local -n vars=$1
  local obj="{"
  for k in "${!vars[@]}"; do
    obj+="\"$k\": \"${vars[$k]}\","
  done
  obj="${obj%,}}"
  echo "$obj"
}

# Copiar configuración de un servicio a otro
copiar_servicio() {
  origen="$1"
  destino="$2"

  if ! jq -e --arg s "$origen" '.desa | has($s)' "$CONFIG_FILE" >/dev/null || \
     ! jq -e --arg s "$origen" '.prod | has($s)' "$CONFIG_FILE" >/dev/null; then
    echo "❌ El servicio de origen '$origen' no existe en ambos entornos."
    exit 1
  fi

  if jq -e --arg s "$destino" '.desa | has($s)' "$CONFIG_FILE" >/dev/null || \
     jq -e --arg s "$destino" '.prod | has($s)' "$CONFIG_FILE" >/dev/null; then
    if ! confirmar "⚠️ El servicio destino '$destino' ya existe. ¿Deseas sobrescribirlo?"; then
      echo "❌ Operación cancelada."
      exit 0
    fi
  fi

  tmpfile=$(mktemp)
  jq --arg o "$origen" --arg d "$destino" \
    '.desa[$d] = .desa[$o] | .prod[$d] = .prod[$o]' "$CONFIG_FILE" > "$tmpfile"

  jq --arg s "$destino" '.desa[$s] as $desa | .prod[$s] as $prod | {desa: $desa, prod: $prod}' "$tmpfile"
  if confirmar "¿Deseas guardar estos cambios?"; then
    mv "$tmpfile" "$CONFIG_FILE"
    echo "✅ Servicio '$destino' copiado desde '$origen'."
  else
    echo "❌ Cambios cancelados."
    rm "$tmpfile"
  fi
}

# CREAR NUEVO SERVICIO
if [[ "$1" == "create" ]]; then
  shift
  servicio="$1"
  shift

  declare -A desa_vars
  declare -A prod_vars

  while [[ $# -gt 0 ]]; do
    clave="$1"
    desa_val="$2"
    prod_val="$3"
    shift 3
    desa_vars["$clave"]="$desa_val"
    prod_vars["$clave"]="$prod_val"
  done

  desa_json=$(create_obj_json desa_vars)
  prod_json=$(create_obj_json prod_vars)

  exists_desa=$(jq -r --arg s "$servicio" '.desa | has($s)' "$CONFIG_FILE")
  exists_prod=$(jq -r --arg s "$servicio" '.prod | has($s)' "$CONFIG_FILE")

  tmpfile=$(mktemp)
  jq \
    --arg s "$servicio" \
    --argjson desa "$desa_json" \
    --argjson prod "$prod_json" \
    '.desa[$s] = $desa | .prod[$s] = $prod | {desa: .desa[$s], prod: .prod[$s]}' \
    "$CONFIG_FILE" > resumen.tmp

  cat resumen.tmp
  if confirmar "¿Deseas guardar estos cambios?"; then
    jq \
      --arg s "$servicio" \
      --argjson desa "$desa_json" \
      --argjson prod "$prod_json" \
      '.desa[$s] = $desa | .prod[$s] = $prod' \
      "$CONFIG_FILE" > "$tmpfile"
    mv "$tmpfile" "$CONFIG_FILE"
    echo "✅ Servicio '$servicio' creado/actualizado."
  else
    echo "❌ Cambios cancelados."
    rm "$tmpfile"
  fi
  rm -f resumen.tmp

# ACTUALIZAR UNA CLAVE EXISTENTE
elif [[ "$1" == "update" ]]; then
  shift
  ambiente="$1"
  servicio="$2"
  clave="$3"
  valor="$4"

  if [[ "$ambiente" != "desa" && "$ambiente" != "prod" ]]; then
    echo "Error: ambiente debe ser 'desa' o 'prod'"
    exit 1
  fi

  if ! jq -e --arg s "$servicio" --arg a "$ambiente" '.[$a] | has($s)' "$CONFIG_FILE" >/dev/null; then
    echo "Error: El servicio '$servicio' no existe en el ambiente '$ambiente'."
    exit 1
  fi

  tmpfile=$(mktemp)
  jq --arg a "$ambiente" --arg s "$servicio" --arg k "$clave" --arg v "$valor" \
    '.[$a][$s][$k] = $v' "$CONFIG_FILE" > "$tmpfile"

  jq --arg a "$ambiente" --arg s "$servicio" '.[$a][$s]' "$tmpfile"
  if confirmar "¿Deseas guardar estos cambios?"; then
    mv "$tmpfile" "$CONFIG_FILE"
    echo "✅ Clave '$clave' actualizada en '$servicio' ($ambiente)."
  else
    echo "❌ Cambios cancelados."
    rm "$tmpfile"
  fi

# INTERACTIVO
elif [[ "$1" == "interactive" ]]; then
  echo "🛠️ Modo interactivo iniciado."
  read -p "¿Qué deseas hacer? (create/update/copiar): " modo

  if [[ "$modo" == "create" ]]; then
    read -p "🔧 Nombre del nuevo servicio: " servicio
    declare -A desa_vars
    declare -A prod_vars

    while true; do
      read -p "📝 Nombre de la variable (deja vacío para terminar): " clave
      [[ -z "$clave" ]] && break

      read -p "Valor para 'desa': " val_desa
      read -p "Valor para 'prod': " val_prod

      desa_vars["$clave"]="$val_desa"
      prod_vars["$clave"]="$val_prod"
    done

    desa_json=$(create_obj_json desa_vars)
    prod_json=$(create_obj_json prod_vars)

    exists_desa=$(jq -r --arg s "$servicio" '.desa | has($s)' "$CONFIG_FILE")
    exists_prod=$(jq -r --arg s "$servicio" '.prod | has($s)' "$CONFIG_FILE")

    tmpfile=$(mktemp)
    jq \
      --arg s "$servicio" \
      --argjson desa "$desa_json" \
      --argjson prod "$prod_json" \
      '.desa[$s] = $desa | .prod[$s] = $prod | {desa: .desa[$s], prod: .prod[$s]}' \
      "$CONFIG_FILE" > resumen.tmp

    cat resumen.tmp
    if confirmar "¿Deseas guardar estos cambios?"; then
      jq \
        --arg s "$servicio" \
        --argjson desa "$desa_json" \
        --argjson prod "$prod_json" \
        '.desa[$s] = $desa | .prod[$s] = $prod' \
        "$CONFIG_FILE" > "$tmpfile"
      mv "$tmpfile" "$CONFIG_FILE"
      echo "✅ Servicio '$servicio' creado/actualizado."
    else
      echo "❌ Cambios cancelados."
      rm "$tmpfile"
    fi
    rm -f resumen.tmp

  elif [[ "$modo" == "update" ]]; then
    read -p "🔄 Ambiente (desa/prod): " ambiente
    read -p "🔄 Nombre del servicio: " servicio
    read -p "🔄 Clave a modificar: " clave
    read -p "🔄 Nuevo valor: " valor

    if ! jq -e --arg s "$servicio" --arg a "$ambiente" '.[$a] | has($s)' "$CONFIG_FILE" >/dev/null; then
      echo "Error: El servicio '$servicio' no existe en el ambiente '$ambiente'."
      exit 1
    fi

    tmpfile=$(mktemp)
    jq --arg a "$ambiente" --arg s "$servicio" --arg k "$clave" --arg v "$valor" \
      '.[$a][$s][$k] = $v' "$CONFIG_FILE" > "$tmpfile"

    jq --arg a "$ambiente" --arg s "$servicio" '.[$a][$s]' "$tmpfile"
    if confirmar "¿Deseas guardar estos cambios?"; then
      mv "$tmpfile" "$CONFIG_FILE"
      echo "✅ Clave '$clave' actualizada en '$servicio' ($ambiente)."
    else
      echo "❌ Cambios cancelados."
      rm "$tmpfile"
    fi

  elif [[ "$modo" == "copiar" ]]; then
    read -p "📥 Nombre del servicio de origen: " origen
    read -p "📤 Nombre del nuevo servicio destino: " destino
    copiar_servicio "$origen" "$destino"

  else
    echo "Error: opción inválida. Usa 'create', 'update' o 'copiar'."
    exit 1
  fi

else
  echo "Uso:"
  echo "  $0 create nombre_servicio clave valor_desa valor_prod [...pares]"
  echo "  $0 update [desa|prod] nombre_servicio clave nuevo_valor"
  echo "  $0 copiar servicio_origen servicio_destino"
  echo "  $0 interactive"
  exit 1
fi
