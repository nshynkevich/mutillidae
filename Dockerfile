FROM ubuntu:18.04

ENV TZ=Europe/Minsk
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update && apt install -y software-properties-common gnupg
RUN add-apt-repository ppa:ondrej/php 
RUN apt update && \
    apt install git php-xml php-fpm libapache2-mod-php php-mysql php-gd php-imap php-curl php-mbstring php8.1-fpm -y

RUN a2enmod proxy_fcgi setenvif
RUN service apache2 restart
RUN a2enconf php8.1-fpm

RUN if [ -d mutillidae ]; then rm -rf mutillidae ; fi
RUN if [ -d "/var/www/html/mutillidae" ]; then rm -rf /var/www/html/mutillidae ; fi

RUN mkdir -p /var/www/html/mutillidae
COPY mutillidae/ /var/www/html/mutillidae/

RUN chown -R www-data:www-data /var/www/html/mutillidae/



RUN groupadd -r mysql && useradd -r -g mysql mysql && \
    groupadd -r mutillidae && useradd -r -g mysql mutillidae

#Install MySQL
RUN echo mysql-community-server mysql-community-server/root-pass password '' | debconf-set-selections
RUN echo mysql-community-server mysql-community-server/re-root-poss password '' | debconf-set-selections && \
    apt install -y mysql-server \
    && mkdir -p /var/lib/mysql /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
    && chmod 777 /var/run/mysqld

RUN sed -i 's/bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf

#RUN sed -i -e "s/localhost/$MYSQL_PORT_3306_TCP_ADDR/g" /var/www/html/mutillidae/classes/MySQLHandler.php
RUN sed -i -e "s/allow_url_include = Off/allow_url_include = On/g" /etc/php/8.1/apache2/php.ini

#RUN sed -i "s/\$mMySQLDatabaseUsername = .*/\$mMySQLDatabaseUsername = 'root';/g" /var/www/html/mutillidae/classes/MySQLHandler.php
#RUN sed -i "s/\$mMySQLDatabasePassword = .*/\$mMySQLDatabasePassword = 'mutillidae';/g" /var/www/html/mutillidae/classes/MySQLHandler.php 

RUN mkdir -p /run/php-fpm/

#RUN check=$(wget -O - -T 2 "http://127.0.0.1:3306" 2>&1 | grep -o mariadb); while [ -z $check ]; do echo "Waiting for DB to come up..."; sleep 5s; check=$(wget -O - -T 2 "http://127.0.0.1:3306" 2>&1 | grep -o mariadb); done && \

RUN  service mysql start && \
    echo "update user set authentication_string=PASSWORD('mutillidae') where user='root';" | mysql -u root -v mysql && \
    echo "update user set plugin='mysql_native_password' where user='root';" | mysql -u root -v mysql 

USER mutillidae

EXPOSE 80 3306

CMD ["bash", "-c", "service mysql start ; service php8.1-fpm start ; service apache2 start ; sleep infinity & wait"] 