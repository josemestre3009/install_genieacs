#!/bin/bash

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
echo "Instalando dependencias..."
sudo apt install -y git curl build-essential gnupg

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

# Eliminar cualquier instalación previa de MongoDB
sudo apt-get purge mongodb-org* -y
sudo apt-get autoremove --purge -y
sudo rm -rf /var/lib/mongodb /var/log/mongodb /etc/mongod.conf /etc/systemd/system/mongodb.service

# Agregar la clave GPG de MongoDB
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

# Agregar el repositorio de MongoDB
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

# Actualizar los repositorios e instalar MongoDB
sudo apt-get update
sudo apt-get install -y mongodb-org

# Iniciar MongoDB
sudo systemctl start mongod

# Verificar que MongoDB está corriendo
echo "Verificando estado de MongoDB..."
#sudo systemctl status mongod

# Instalación de GenieACS
echo "Instalando GenieACS..."
sudo npm install -g genieacs@1.2.13

# Verificar instalación de GenieACS
echo "Verificando instalación de GenieACS..."
which genieacs-cwmp

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
sudo tee /etc/systemd/system/genieacs-nbi.service > /dev/null <<EOF
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

# Crear GenieACS FS
sudo tee /etc/systemd/system/genieacs-fs.service > /dev/null <<EOF
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

# Crear GenieACS UI
sudo tee /etc/systemd/system/genieacs-ui.service > /dev/null <<EOF
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

# Crear configuración para logrotate
echo "Configurando logrotate para GenieACS..."
sudo tee /etc/logrotate.d/genieacs > /dev/null <<EOF
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

# Recargar systemd y habilitar servicios
echo "Recargando systemd y habilitando los servicios..."
sudo systemctl daemon-reload

# Habilitar y arrancar los servicios
echo "Habilitando y arrancando los servicios..."

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

echo ""
read -p "¿Quieres instalar ZeroTier en este equipo? (s/n): " INSTALAR_ZT

if [[ "$INSTALAR_ZT" == "s" || "$INSTALAR_ZT" == "S" ]]; then
    echo "Instalando ZeroTier..."
    curl -s https://install.zerotier.com | sudo bash

    read -p "Introduce tu Network ID de ZeroTier: " ZTNET
    sudo zerotier-cli join $ZTNET

    echo "ZeroTier instalado y unido a la red $ZTNET."
    echo "Recuerda autorizar este dispositivo en https://my.zerotier.com"
else
    echo "ZeroTier NO se instalará."
fi




