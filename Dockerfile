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

RUN a2enmod proxy_fcgi setenvif ; \
    service apache2 restart ; \
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
    apt install -y mysql-server ; \
    if [ ! -e /var/lib/mysql ]; then mkdir -p /var/lib/mysql ; fi ; \ 
    if [ ! -e /var/run/mysqld ]; then mkdir -p /var/run/mysqld ; fi ; \
    if [ ! -e /run/php ]; then mkdir -p /run/php ; fi ; \
    chmod -R 777 /var/run/ && \
    chmod -R 777 /var/log/ && \
    chmod 770 /var/lib/mysql ; \
    chown -R mysql:mysql /var/lib/mysql

#RUN sed -i -e "s/localhost/$MYSQL_PORT_3306_TCP_ADDR/g" /var/www/html/mutillidae/classes/MySQLHandler.php
RUN sed -i 's/bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf ; \
    if [ -e /etc/php/8.1/apache2/php.ini ]; then sed -i -e "s/allow_url_include = Off/allow_url_include = On/g" /etc/php/8.1/apache2/php.ini; fi; \
    if [ -e /etc/php/8.2/apache2/php.ini ]; then sed -i -e "s/allow_url_include = Off/allow_url_include = On/g" /etc/php/8.2/apache2/php.ini; fi; \
    sed -i 's/^;extension=mysqli/extension=mysqli/' /etc/php/8.1/fpm/php.ini ; \
    sed -E -i 's/user = .*$/user = mutillidae/' /etc/php/8.1/fpm/pool.d/www.conf ; \
    sed -E -i 's/;listen.mode = .*$/listen.mode = 0777/' /etc/php/8.1/fpm/pool.d/www.conf ; \
    sed -E -i 's/listen.owner = .*$/listen.owner = mutillidae/' /etc/php/8.1/fpm/pool.d/www.conf

RUN sed -i "s/\$mMySQLDatabaseUsername = .*/\$mMySQLDatabaseUsername = 'root';/g" /var/www/html/mutillidae/classes/MySQLHandler.php ; \
    sed -i "s/\$mMySQLDatabasePassword = .*/\$mMySQLDatabasePassword = 'mutillidae';/g" /var/www/html/mutillidae/classes/MySQLHandler.php 

#RUN check=$(wget -O - -T 2 "http://127.0.0.1:3306" 2>&1 | grep -o mariadb); while [ -z $check ]; do echo "Waiting for DB to come up..."; sleep 5s; check=$(wget -O - -T 2 "http://127.0.0.1:3306" 2>&1 | grep -o mariadb); done && \

RUN if [ ! -e /etc/sudoers.d ]; then mkdir -p /etc/sudoers.d; fi ; \
    echo "mutillidae ALL=(ALL) NOPASSWD: /usr/sbin/service *,/run-services.sh" >> /etc/sudoers.d/mutillidae && \
    chmod 644 /etc/sudoers.d/mutillidae 

RUN file="/etc/mysql/mysql.conf.d/mysqld.cnf"; if [ -w "$file" ]; then echo "Setting default collation to UTF-8 in $file"; sed -i -e 's/\[mysqld\]/[mysqld]\nskip-grant-tables\ncollation-server = utf8_unicode_ci\ninit-connect='\''SET NAMES utf8'\''\ncharacter-set-server = utf8\n\n/' $file;else echo "Can't write to $file. ry running the script with 'sudo'.";fi;

RUN service mysql start && \
    echo "update user set authentication_string=PASSWORD('mutillidae') where user='root';" | mysql -u root -v mysql && \
    echo "update user set plugin='mysql_native_password' where user='root';" | mysql -u root -v mysql ; \
    chown -R www-data: /var/log/apache2/ ; \
    chmod -R 777 /var/log/apache2/ ; \
    chmod -R 777 /run/php/ 

#    chown -R mutillidae /etc/supervisor/ ; \
#    touch /supervisord.log ; \
#    chown mutillidae: /supervisord.log ; \
#    touch /supervisord.pid ; \
#    chown mutillidae: /supervisord.pid

#COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY run-services.sh /run-services.sh

USER mutillidae

EXPOSE 80 3306

#ENTRYPOINT ["/bin/bash"]
#CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-u", "mutillidae"]
CMD ["sudo", "/run-services.sh"]
