#!/bin/bash

# --- Configuración Inicial ---
# ADVERTENCIA: Este script requiere que se ejecute con permisos de superusuario (sudo).

# Nombre del directorio de configuración de Apache (puede variar en algunas distribuciones)
APACHE_CONF_DIR="/etc/apache2/sites-available"

# 1. Verificar permisos de superusuario
if [ "$(id -u)" != "0" ]; then
   echo "Este script debe ejecutarse con 'sudo'." 1>&2
   exit 1
fi

# 2. Verificar la disponibilidad de Certbot
if ! command -v certbot &> /dev/null; then
    echo "Certbot no está instalado. Por favor, instálalo primero (e.g., sudo apt install certbot python3-certbot-apache)."
    exit 1
fi

# 3. Solicitar el dominio principal
read -p "Introduce el dominio principal (e.g., ejemplo.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "Dominio no puede estar vacío."
    exit 1
fi

# 4. Solicitar dominios adicionales (opcional)
read -p "Introduce dominios alternativos separados por comas (e.g., www.ejemplo.com,sub.ejemplo.com) o déjalo vacío: " ALT_DOMAINS

# Construir la lista completa de dominios para Certbot
if [ -n "$ALT_DOMAINS" ]; then
    # Reemplazar comas por la opción de dominio de Certbot (-d)
    CERTBOT_DOMAINS="-d $DOMAIN -d $(echo $ALT_DOMAINS | tr ',' ' ' | sed 's/ / -d /g')"
else
    CERTBOT_DOMAINS="-d $DOMAIN"
fi

echo "---"
echo "Dominio(s) a procesar: $DOMAIN $([ -n "$ALT_DOMAINS" ] && echo ", $ALT_DOMAINS")"
echo "---"

# 5. Ejecutar Certbot para obtener el certificado y configurar Apache
echo "Ejecutando Certbot para obtener el certificado SSL y configurar Apache..."

# Usamos el plugin 'apache' para que Certbot se encargue automáticamente
# de editar los Virtual Hosts y recargar Apache.
# --non-interactive: No pide interacción.
# --agree-tos: Acepta los términos de servicio.
# --hsts: Habilita el encabezado Strict-Transport-Security.
# --redirect: Fuerza la redirección HTTP a HTTPS.
# --staple-ocsp: Habilita OCSP Stapling (mejora el rendimiento y la privacidad).

certbot --apache \
        $CERTBOT_DOMAINS \
        --non-interactive \
        --agree-tos \
        --hsts \
        --redirect \
        --staple-ocsp \
        --email hostmaster@$DOMAIN

# 6. Comprobación del resultado
if [ $? -eq 0 ]; then
    echo "---"
    echo "¡ÉXITO! El certificado Let's Encrypt se ha obtenido y configurado en Apache."
    echo "Tu sitio ahora está disponible en https://$DOMAIN"
    echo "---"
    
    # 7. Verificar y programar la renovación automática
    echo "Verificando la configuración de renovación..."
    if systemctl is-enabled certbot.timer &> /dev/null; then
        echo "El temporizador de renovación automática de Certbot está habilitado."
    else
        echo "Advertencia: El temporizador de renovación automática no parece estar habilitado."
        echo "    Asegúrate de que el paquete 'certbot' o 'python3-certbot-apache' haya instalado y habilitado el cronjob/timer de renovación."
    fi
else
    echo "---"
    echo "FALLO: Certbot no pudo obtener/configurar el certificado."
    echo "   Revisa los logs de Certbot para más detalles (usualmente en /var/log/letsencrypt/)."
    echo "   Asegúrate de que el Virtual Host para $DOMAIN exista y que el puerto 80 esté accesible desde internet."
    echo "---"
fi

exit 0
