# LAMP
#!/bin/bash
# Actualiza paquetes
sudo apt update && sudo apt upgrade -y

# Instala Apache
sudo apt install apache2 -y

# Instala MySQL
sudo apt install mysql-server -y

# Instala PHP y módulos comunes
sudo apt install php libapache2-mod-php php-mysql -y

# Reinicia Apache
sudo systemctl restart apache2
