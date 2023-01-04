FROM ubuntu:18.04

ENV TZ=Europe/Minsk

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt update && \
    apt install -y software-properties-common \
        gnupg

RUN add-apt-repository ppa:ondrej/php && \
    apt update && \
    apt install -y \
        net-tools \
        supervisor \
        git \
        php-xml \
        php-fpm \
        libapache2-mod-php \
        php-mysql \
        php-gd \
        php-imap \
        php-curl \
        php-mbstring \
        php8.1-fpm \
        php8.1-mysql \
        sudo

RUN a2enmod proxy_fcgi setenvif && \
    service apache2 restart && \
    a2enconf php8.1-fpm

RUN if [ -d mutillidae ]; then rm -rf mutillidae ; fi ; \
    if [ -d "/var/www/html/mutillidae" ]; then rm -rf /var/www/html/mutillidae ; fi ; \
    mkdir -p /var/www/html/mutillidae
#COPY mutillidae/ /var/www/html/mutillidae/
COPY . /var/www/html/mutillidae/

RUN chown -R www-data:www-data /var/www/html/mutillidae/ && \
    groupadd -r mysql && \
    useradd -r -g mysql mysql && \
    useradd -ms /bin/bash mutillidae && \
    echo "mutillidae:mutillidae" | chpasswd && \
    usermod -a -G mysql mutillidae && \
    usermod -a -G sudo mutillidae && \
    usermod -a -G www-data mutillidae && \
    usermod -a -G adm mutillidae

#Install MySQL
RUN echo mysql-community-server mysql-community-server/root-pass password '' | debconf-set-selections && \
    echo mysql-community-server mysql-community-server/re-root-poss password '' | debconf-set-selections && \
    apt install -y mysql-server && \
    mkdir -p /var/lib/mysql /var/run/mysqld && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld && \
    chmod 770 /var/lib/mysql ; \
    mkdir -p /var/log/supervisor

#RUN sed -i -e "s/localhost/$MYSQL_PORT_3306_TCP_ADDR/g" /var/www/html/mutillidae/classes/MySQLHandler.php
RUN sed -i 's/bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf ; \
    if [ -e /etc/php/8.1/apache2/php.ini ]; then sed -i -e "s/allow_url_include = Off/allow_url_include = On/g" /etc/php/8.1/apache2/php.ini; fi; \
    if [ -e /etc/php/8.2/apache2/php.ini ]; then sed -i -e "s/allow_url_include = Off/allow_url_include = On/g" /etc/php/8.2/apache2/php.ini; fi; \
    sed -i 's/^;extension=mysqli/extension=mysqli/' /etc/php/8.1/fpm/php.ini 

RUN sed -i "s/\$mMySQLDatabaseUsername = .*/\$mMySQLDatabaseUsername = 'root';/g" /var/www/html/mutillidae/classes/MySQLHandler.php ; \
    sed -i "s/\$mMySQLDatabasePassword = .*/\$mMySQLDatabasePassword = 'mutillidae';/g" /var/www/html/mutillidae/classes/MySQLHandler.php 

#RUN check=$(wget -O - -T 2 "http://127.0.0.1:3306" 2>&1 | grep -o mariadb); while [ -z $check ]; do echo "Waiting for DB to come up..."; sleep 5s; check=$(wget -O - -T 2 "http://127.0.0.1:3306" 2>&1 | grep -o mariadb); done && \

RUN if [ ! -e /etc/sudoers.d ]; then mkdir -p /etc/sudoers.d;fi; echo "Cmnd_Alias USER_SERVICES = /usr/bin/supervisord, /etc/init.d/mysql start, /etc/init.d/mysql stop, /etc/init.d/mysql restart, /etc/init.d/php8.1-fpm start, /etc/init.d/php8.1-fpm stop, /etc/init.d/php8.1-fpm restart, /etc/init.d/apache2 stop, /etc/init.d/apache2 start, /etc/init.d/apache2 restart" > /etc/sudoers.d/mutillidae && \
    echo "mutillidae ALL=(ALL) NOPASSWD: USER_SERVICES" >> /etc/sudoers.d/mutillidae && \
    chmod 0440 /etc/sudoers.d/mutillidae 

RUN file="/etc/mysql/mysql.conf.d/mysqld.cnf"; if [ -w "$file" ]; then echo "Setting default collation to UTF-8 in $file"; sed -i -e 's/\[mysqld\]/[mysqld]\nskip-grant-tables\ncollation-server = utf8_unicode_ci\ninit-connect='\''SET NAMES utf8'\''\ncharacter-set-server = utf8\n\n/' $file;else echo "Can't write to $file. ry running the script with 'sudo'.";fi;

RUN service mysql start && \
    echo "update user set authentication_string=PASSWORD('mutillidae') where user='root';" | mysql -u root -v mysql && \
    echo "update user set plugin='mysql_native_password' where user='root';" | mysql -u root -v mysql ; \
    chown -R www-data: /var/log/apache2/ ; \
    chmod -R 777 /var/log/apache2/

#COPY my_wrapper_script.sh /my_wrapper_script.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

#USER mutillidae

EXPOSE 80 3306

CMD ["/usr/bin/supervisord"]
