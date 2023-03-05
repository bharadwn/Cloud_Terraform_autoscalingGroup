#!/bin/bash
sudo su
sudo yum update -y
sudo amazon-linux-extras install nginx1 -y
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx
echo "newer NGINX Server v2 " > /usr/share/nginx/html/index.html