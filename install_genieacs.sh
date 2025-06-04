#!/bin/bash

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
echo "Instalando dependencias..."
sudo apt install -y git curl build-essential mongodb nodejs npm

# Instalar Node.js (si ya existe, se elimina primero)
echo "Instalando Node.js..."
sudo apt remove -y nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verificar las versiones de Node.js y npm
echo "Verificando versiones de Node.js y npm..."
if ! node -v || ! npm -v; then
    echo "Error: Node.js o npm no se instalaron correctamente."
    exit 1
fi
node -v
npm -v

# Instalar MongoDB
echo "Instalando MongoDB..."
sudo apt-get install gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod

# Verificar que MongoDB está corriendo
echo "Verificando estado de MongoDB..."
if ! sudo systemctl status mongodb; then
    echo "Error al iniciar MongoDB. Revisa los logs."
    exit 1
fi

# Instalación de GenieACS
echo "Instalando GenieACS..."
sudo npm install -g genieacs@1.2.13

# Verificar instalación de GenieACS
echo "Verificando instalación de GenieACS..."
if ! which genieacs-cwmp; then
    echo "Error: GenieACS no está instalado correctamente."
    exit 1
fi

# Crear Usuario y Directorios para GenieACS
echo "Creando usuario y directorios para GenieACS..."
sudo useradd --system --no-create-home --user-group genieacs
sudo mkdir -p /opt/genieacs/ext
sudo chown genieacs:genieacs /opt/genieacs/ext

# Crear archivo de variables de entorno
echo "Creando archivo de variables de entorno..."
cat <<EOF | sudo tee /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
EOF

# Añadir la clave JWT secreta
echo "Añadiendo clave JWT secreta..."
node -e "console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))" | sudo tee -a /opt/genieacs/genieacs.env

# Ajustar permisos del archivo de variables de entorno
sudo chown genieacs:genieacs /opt/genieacs/genieacs.env
sudo chmod 600 /opt/genieacs/genieacs.env

# Crear directorios de logs
echo "Creando directorios de logs..."
sudo mkdir -p /var/log/genieacs
sudo chown genieacs:genieacs /var/log/genieacs

# Crear servicios systemd para GenieACS
echo "Creando servicios systemd para GenieACS..."
# Crear GenieACS CWMP
sudo tee /etc/systemd/system/genieacs-cwmp.service > /dev/null <<EOF
[Unit]
Description=GenieACS CWMP
After=network.target
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-cwmp
[Install]
WantedBy=default.target
EOF

# Crear GenieACS NBI
# (similar al bloque anterior)

# Recargar systemd y habilitar servicios
echo "Recargando systemd y habilitando los servicios..."
sudo systemctl daemon-reload

# Habilitar y arrancar los servicios
echo "Habilitando y arrancando los servicios..."
sudo systemctl enable genieacs-cwmp
sudo systemctl start genieacs-cwmp

# Finalizar
echo "Instalación completada. Puedes acceder a GenieACS en http://localhost:3000"
