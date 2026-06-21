#!/bin/bash
# ─────────────────────────────────────────
# user_data.sh
# Runs on EC2 first boot:
#   1. Installs Docker
#   2. Clones repo from GitHub
#   3. Builds and runs all containers
# ─────────────────────────────────────────

set -e
exec > /var/log/user-data.log 2>&1

echo "======================================="
echo " E-Commerce Store Bootstrap Starting"
echo "======================================="

# ── Get EC2 public IP from metadata ──────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "--- Public IP: $PUBLIC_IP ---"

# ── Update system ────────────────────────
apt-get update -y
apt-get upgrade -y

# ── Install Docker ───────────────────────
echo "--- Installing Docker ---"
apt-get install -y ca-certificates curl gnupg git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

echo "--- Docker installed: $(docker --version) ---"

# ── Clone repo from GitHub ───────────────
echo "--- Cloning repository ---"
cd /home/ubuntu
git clone https://github.com/Avinashsain/E-CommerceStore.git app
cd app

# ── Write .env file with public IP ───────
cat > .env << ENVEOF
NODE_ENV=production
JWT_SECRET=${jwt_secret}

# MongoDB Atlas
MONGODB_URI_USERS=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_users
MONGODB_URI_PRODUCTS=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_products
MONGODB_URI_CARTS=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_carts
MONGODB_URI_ORDERS=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_orders

# Inter-service URLs (Docker network)
USER_SERVICE_URL=http://user-service:3001
PRODUCT_SERVICE_URL=http://product-service:3002
CART_SERVICE_URL=http://cart-service:3003
ORDER_SERVICE_URL=http://order-service:3004

# Frontend URLs (uses EC2 public IP)
REACT_APP_USER_SERVICE_URL=http://$PUBLIC_IP:3001
REACT_APP_PRODUCT_SERVICE_URL=http://$PUBLIC_IP:3002
REACT_APP_CART_SERVICE_URL=http://$PUBLIC_IP:3003
REACT_APP_ORDER_SERVICE_URL=http://$PUBLIC_IP:3004
ENVEOF

echo "--- .env written with PUBLIC_IP=$PUBLIC_IP ---"
cat .env

# ── Build and start all containers ───────
echo "--- Building and starting containers ---"
docker compose up --build -d

# ── Wait for containers to start ─────────
echo "--- Waiting for services to start ---"
sleep 30

# ── Verify all containers running ────────
echo "--- Container status ---"
docker ps

echo "======================================="
echo " Bootstrap Complete!"
echo " Frontend : http://$PUBLIC_IP:3000"
echo " User API : http://$PUBLIC_IP:3001"
echo " Product  : http://$PUBLIC_IP:3002"
echo " Cart     : http://$PUBLIC_IP:3003"
echo " Orders   : http://$PUBLIC_IP:3004"
echo "======================================="