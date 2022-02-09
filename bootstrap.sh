#!/bin/bash
sudo yum update -y
sudo yum install -y amazon-linux-extras
sudo yum install httpd -y
sudo amazon-linux-extras enable php7.4
sudo yum clean metadata
sudo yum install php-cli php-pdo php-fpm php-json php-mysqlnd -y
cd /tmp
sudo wget http://wordpress.org/latest.tar.gz
sudo tar -xzvf latest.tar.gz
sudo cp -r wordpress/* /var/www/html/
sudo chown -R apache:apache /var/www/html
sudo systemctl restart httpd