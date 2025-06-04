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
node -v
npm -v

# Instalar MongoDB
echo "Instalando MongoDB..."
sudo apt install -y mongodb

# Verificar que MongoDB esté corriendo
echo "Verificando estado de MongoDB..."
sudo systemctl status mongodb

# Instalar GenieACS
echo "Instalando GenieACS..."
sudo npm install -g genieacs@1.2.13

# Verificar que GenieACS se instaló correctamente
echo "Verificando instalación de GenieACS..."
which genieacs-cwmp

# Crear usuario y directorios necesarios
echo "Creando usuario y directorios para GenieACS..."
sudo useradd --system --no-create-home --user-group genieacs
sudo mkdir -p /opt/genieacs/ext
sudo chown genieacs:genieacs /opt/genieacs/ext

# Crear archivo de variables de entorno
echo "Creando archivo de variables de entorno..."
echo "GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext" | sudo tee /opt/genieacs/genieacs.env

# Añadir clave JWT secreta
echo "Añadiendo clave JWT secreta..."
node -e "console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))" | sudo tee -a /opt/genieacs/genieacs.env

# Ajustar permisos del archivo de variables de entorno
sudo chown genieacs:genieacs /opt/genieacs/genieacs.env
sudo chmod 600 /opt/genieacs/genieacs.env

# Crear directorios de logs
echo "Creando directorios de logs..."
sudo mkdir /var/log/genieacs
sudo chown genieacs:genieacs /var/log/genieacs

# Crear servicios systemd para GenieACS
echo "Creando servicios systemd..."
sudo systemctl edit --force --full genieacs-cwmp <<EOF
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

sudo systemctl edit --force --full genieacs-nbi <<EOF
[Unit]
Description=GenieACS NBI
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-nbi

[Install]
WantedBy=default.target
EOF

sudo systemctl edit --force --full genieacs-fs <<EOF
[Unit]
Description=GenieACS FS
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-fs

[Install]
WantedBy=default.target
EOF

sudo systemctl edit --force --full genieacs-ui <<EOF
[Unit]
Description=GenieACS UI
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-ui

[Install]
WantedBy=default.target
EOF

# Configurar logrotate para los logs de GenieACS
echo "Configurando logrotate para GenieACS..."
echo "/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
   daily
   rotate 30
   compress
   delaycompress
   dateext
}" | sudo tee /etc/logrotate.d/genieacs

# Inicializar y habilitar los servicios
echo "Inicializando los servicios..."
sudo systemctl enable genieacs-cwmp
sudo systemctl start genieacs-cwmp
sudo systemctl status genieacs-cwmp

sudo systemctl enable genieacs-nbi
sudo systemctl start genieacs-nbi
sudo systemctl status genieacs-nbi

sudo systemctl enable genieacs-fs
sudo systemctl start genieacs-fs
sudo systemctl status genieacs-fs

sudo systemctl enable genieacs-ui
sudo systemctl start genieacs-ui
sudo systemctl status genieacs-ui

echo "Instalación completada. Puedes acceder a GenieACS en http://localhost:3000"
