# 🛠️ Configuración de Entornos Seguros (Producción y Desarrollo)

Este repositorio contiene un sistema modular en Bash para gestionar variables de entorno de manera **segura, organizada y escalable**, ideal para proyectos en servidores Debian.  

Los scripts permiten **leer**, **crear**, **actualizar**, **copiar** y **consultar** configuraciones de servicios para ambientes de `desa` (desarrollo) y `prod` (producción), todo desde un único archivo JSON estructurado.

---

## 📁 Estructura del Proyecto

Los archivos se ubican en el directorio:

```
/usr/src/scripts/ivr/
```

### Archivos incluidos:

- `env.config.json` → Archivo central de configuración.
- `loadenv.sh` → Script para leer variables del entorno.
- `updateenv.sh` → Script para crear o actualizar lista de servicios.

---

## 📘 `env.config.json` (Ejemplo)

```json
{
  "desa": {
    "consultasaldo": {
      "url": "http://desa-url.com",
      "urlauth": "http://desa-auth.com",
      "passwd": "passdesa"
    }
  },
  "prod": {
    "consultasaldo": {
      "url": "https://prod-url.com",
      "urlauth": "https://prod-auth.com",
      "passwd": "passprod"
    }
  }
}
```

---

## 🚀 `loadenv.sh`

Script para **leer** las variables de un entorno.

### ✅ Uso:
```bash
./loadenv.sh desa
```

### 💡 Resultado:
Devuelve en formato JSON todas las claves del ambiente `desa`.

Puedes acceder a una clave específica con `jq`:
```bash
./loadenv.sh prod | jq '.consultasaldo.url'
```

---

## ⚙️ `updateenv.sh`

Script principal para **crear**, **actualizar**, **copiar** y **gestionar** servicios dentro del archivo `env.config.json`.

### 🧪 Modo 1: Línea de comandos

#### 🔧 Crear un nuevo servicio:
```bash
./updateenv.sh create consultadeuda url "http://desa-url" "https://prod-url" \
                                    urlauth "desa-auth" "prod-auth" \
                                    passwd "clave-desa" "clave-prod"
```

✔️ Crea el servicio en ambos ambientes. Si alguna clave se deja vacía, se almacena como string vacío (`""`) para ese entorno.

#### 🔁 Actualizar un valor específico:
```bash
./updateenv.sh update prod consultadeuda passwd "nuevaClaveProd"
```

#### 📥 Copiar configuración de un servicio:
```bash
./updateenv.sh copiar consultadeuda consultaprestamo
```

✔️ Copia la configuración de `consultadeuda` a un nuevo servicio llamado `consultaprestamo`.

---

### 💬 Modo 2: Interactivo

Invoca el script sin argumentos:
```bash
./updateenv.sh interactive
```

El sistema te preguntará si deseas:

- Crear un nuevo servicio.
- Actualizar una clave específica.
- Copiar un servicio a otro.

Todos los cambios muestran un resumen previo y requieren confirmación antes de escribirse en el archivo.

---

## 🔒 Seguridad

- Se recomienda proteger el archivo:
  ```bash
  chmod 600 env.config.json
  ```

---

## ✅ Requisitos

- `jq` instalado:
  ```bash
  sudo apt install jq
  ```

---

## 📌 Notas finales

Este sistema es ideal para equipos DevOps, backend o infraestructura que requieren:
- Acceder a configuraciones variables por entorno.
- Mantener una fuente única de configuración segura.
- Automatizar despliegues sin exponer claves directamente en los scripts.

---
