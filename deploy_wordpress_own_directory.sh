#!/bin/bash

# --- Configuracion y Variables ---
# ADVERTENCIA: Este script requiere que se ejecute con permisos de superusuario (sudo).

# Directorio raiz de Apache
APACHE_ROOT_DIR="/var/www/html"

# URL de la ultima version de WordPress
WP_DOWNLOAD_URL="https://wordpress.org/latest.tar.gz"

# Archivo de configuracion de ejemplo que usaremos como plantilla
WP_CONFIG_SAMPLE="wp-config-sample.php"

# Archivo final de configuracion
WP_CONFIG_FILE="wp-config.php"

# 1. Verificar permisos de superusuario
if [ "$(id -u)" != "0" ]; then
   echo "ERROR: Este script debe ejecutarse con 'sudo'." 1>&2
   exit 1
fi

# 2. Verificar la disponibilidad de wget o curl
if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    echo "ERROR: Se requiere 'wget' o 'curl' para descargar WordPress."
    echo "Por favor, instalalo (e.g., sudo apt install wget)."
    exit 1
fi

# 3. Solicitar el nombre del subdirectorio
echo "--- Configuracion del Directorio de Instalacion ---"
read -p "Introduce el nombre del subdirectorio para WordPress (e.g., blog, wp, wordpress): " WP_SUBDIR
if [ -z "$WP_SUBDIR" ]; then
    echo "ERROR: El nombre del subdirectorio no puede estar vacio."
    exit 1
fi

# Directorio de destino final de WordPress
WP_DEST_DIR="$APACHE_ROOT_DIR/$WP_SUBDIR"

# 4. Solicitar detalles de la base de datos
echo "--- Introduce los detalles de la Base de Datos para WordPress ---"
read -p "Nombre de la Base de Datos: " DB_NAME
read -p "Usuario de la Base de Datos: " DB_USER
read -s -p "Contrasena de la Base de Datos: " DB_PASSWORD
echo "" # Nueva linea despues de la contrasena

# 5. Crear y limpiar el directorio de instalacion
echo "Creando el directorio de destino: $WP_DEST_DIR"
mkdir -p "$WP_DEST_DIR"

if [ "$(ls -A $WP_DEST_DIR)" ]; then
    echo "ADVERTENCIA: El directorio $WP_DEST_DIR no esta vacio. Se moveran los archivos existentes a una copia de seguridad."
    mkdir -p /tmp/wp_backup_$(date +%Y%m%d%H%M%S)
    mv ${WP_DEST_DIR}/* /tmp/wp_backup_$(date +%Y%m%d%H%M%S)/ 2>/dev/null
fi


# 6. Descargar y descomprimir WordPress
echo "Descargando la ultima version de WordPress..."
if command -v wget &> /dev/null; then
    wget -q -O /tmp/latest.tar.gz $WP_DOWNLOAD_URL
else
    curl -s -o /tmp/latest.tar.gz $WP_DOWNLOAD_URL
fi

echo "Descomprimiendo archivos en $WP_DEST_DIR..."
tar -xzf /tmp/latest.tar.gz -C /tmp/
# Mover el contenido del directorio 'wordpress' al directorio de destino
mv /tmp/wordpress/* "$WP_DEST_DIR/"
rm -rf /tmp/wordpress /tmp/latest.tar.gz


# 7. Configurar el archivo wp-config.php
echo "Creando el archivo de configuracion wp-config.php..."

# Copiar el archivo de muestra
cp ${WP_DEST_DIR}/${WP_CONFIG_SAMPLE} ${WP_DEST_DIR}/${WP_CONFIG_FILE}

# Reemplazar los marcadores de posicion de la base de datos
sed -i "s/database_name_here/$DB_NAME/g" ${WP_DEST_DIR}/${WP_CONFIG_FILE}
sed -i "s/username_here/$DB_USER/g" ${WP_DEST_DIR}/${WP_CONFIG_FILE}
sed -i "s/password_here/$DB_PASSWORD/g" ${WP_DEST_DIR}/${WP_CONFIG_FILE}

# Generar y anadir las claves de seguridad unicas (Salts)
echo "Generando claves de seguridad (Salts)..."
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
# Buscar la linea que marca donde insertar las salts y sustituir el bloque
sed -i "/define('AUTH_KEY',/r /dev/stdin" ${WP_DEST_DIR}/${WP_CONFIG_FILE} <<< "$SALTS"
# Eliminar las lineas de salts originales/placeholder
sed -i "/put your unique phrase here/d" ${WP_DEST_DIR}/${WP_CONFIG_FILE}


# 8. Asignar los permisos correctos
echo "Asignando permisos de archivo..."

# En sistemas Debian/Ubuntu, el usuario de Apache es 'www-data'
APACHE_USER="www-data" 
APACHE_GROUP="www-data"

# Cambiar el propietario y grupo de todos los archivos al usuario de Apache
chown -R $APACHE_USER:$APACHE_GROUP $WP_DEST_DIR

# Asignar permisos de escritura/lectura seguros (directorios 755, archivos 644)
find $WP_DEST_DIR -type d -exec chmod 755 {} \;
find $WP_DEST_DIR -type f -exec chmod 644 {} \;


# 9. Finalizacion
echo "---"
echo "INSTALACION DE WORDPRESS COMPLETADA."
echo "Ahora puedes finalizar la instalacion visitando la URL de tu nuevo directorio."
echo "URL: http://tu_dominio_o_ip/$WP_SUBDIR/"
echo "NOTA: Recuerda crear la base de datos '$DB_NAME' y el usuario '$DB_USER' en tu servidor MySQL/MariaDB antes de acceder."
echo "---"

exit 0
