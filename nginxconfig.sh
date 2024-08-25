#!/bin/bash
#Author: shirley_gwata
#Date: 25/08/2024
#Last_modified: 25/08/2024
#Purpose: install nginx and set up reverse proxy

sudo apt-get update
sudo apt-get upgrade -y

#install nginx and start the service
sudo apt-get install -y nginx
sudo systemctl enable nginx

echo -e '<h1>Congrats! you have installed nginx</h1>
<h3>You have succesfully configured a proxey server as well</h3>
<h3>Your configurations include the following</h3>
<ol>
  <li>VPC and 3 subnets, 2 route tables and 2 route table attachements</li>
  <li>Load balancer and listener</li>
  <li>Target group</li>
  <li>2 Security groups</li>
  <li>Internet Gateway</li>
  <li>NAT Gateway</li>
  <li>EC2</li>
  <li>EIP for the NAT Gateway</li>
  <li>Shell script to run at boot time for the Ec2</li>
  <li>5 SSM Parameter resources</li>
</ol>
<ul>
  <li><a href="https://github.com/shirley-007">Github</a></li>
  <li><a href="https://github.com/shirley-007">LinkedIn</a></li>
</ul>
<h6>Great Job. cc shirley_gwata</h6>' > /var/www/html/index.html


# Remove the default site available
sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default

# Set up a reverse proxy in NGINX to forward requests to the local server
#local_server="http://localhost:80"
sudo tee /etc/nginx/sites-available/reverse_proxy.conf <<EOF
server {
  listen 80;

  location / {
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_cache_bypass http_upgrade;
    ProxyPass http://localhost:80/;
  }
}

#create a link of the available site in the sites-enabled directory
ln -s /etc/nginx/sites-available/reverse_proxy.conf /etc/nginx/sites-enabled/

sudo systemctl restart nginx
