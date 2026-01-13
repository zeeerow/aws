
#!/bin/bash
# EC2-2 (food) bootstrap
set -euo pipefail

# Update packages
sudo apt-get update -y || sudo yum update -y

# Install nginx
sudo apt-get install -y nginx || sudo amazon-linux-extras install -y nginx1

# Simple site content
echo "Hello from EC2-2 (food)" | sudo tee /usr/share/nginx/html/index.html

# Start service
sudo systemctl enable nginx
sudo systemctl start nginx
