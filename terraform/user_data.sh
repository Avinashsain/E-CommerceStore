#!/bin/bash
# ─────────────────────────────────────────
# user_data.sh
# Runs on EC2 first boot:
#   1. Installs Docker
#   2. Clones repo from GitHub
#   3. Pulls images from DockerHub
#   4. Runs all containers
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

# ── Write docker-compose.yml using DockerHub images ──
cat > docker-compose.yml << COMPOSEEOF
services:

  user-service:
    image: ${dockerhub_username}/user-service:latest
    container_name: user-service
    restart: unless-stopped
    ports:
      - "3001:3001"
    environment:
      - PORT=3001
      - NODE_ENV=production
      - MONGODB_URI=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_users
      - JWT_SECRET=${jwt_secret}
    networks:
      - ecommerce-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3001/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 15s

  product-service:
    image: ${dockerhub_username}/product-service:latest
    container_name: product-service
    restart: unless-stopped
    ports:
      - "3002:3002"
    environment:
      - PORT=3002
      - NODE_ENV=production
      - MONGODB_URI=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_products
    networks:
      - ecommerce-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3002/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 15s

  cart-service:
    image: ${dockerhub_username}/cart-service:latest
    container_name: cart-service
    restart: unless-stopped
    ports:
      - "3003:3003"
    environment:
      - PORT=3003
      - NODE_ENV=production
      - MONGODB_URI=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_carts
      - PRODUCT_SERVICE_URL=http://product-service:3002
      - USER_SERVICE_URL=http://user-service:3001
    depends_on:
      user-service:
        condition: service_healthy
      product-service:
        condition: service_healthy
    networks:
      - ecommerce-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3003/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 15s

  order-service:
    image: ${dockerhub_username}/order-service:latest
    container_name: order-service
    restart: unless-stopped
    ports:
      - "3004:3004"
    environment:
      - PORT=3004
      - NODE_ENV=production
      - MONGODB_URI=mongodb+srv://avinashsain65_db_user:TGyVdGAv1aYyOgqi@herocluster1.csewjfm.mongodb.net/ecommerce_orders
      - CART_SERVICE_URL=http://cart-service:3003
      - PRODUCT_SERVICE_URL=http://product-service:3002
      - USER_SERVICE_URL=http://user-service:3001
    depends_on:
      cart-service:
        condition: service_healthy
      product-service:
        condition: service_healthy
    networks:
      - ecommerce-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3004/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 15s

  frontend-service:
    image: ${dockerhub_username}/frontend:latest
    container_name: frontend-service
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - NODE_ENV=production
      - REACT_APP_USER_SERVICE_URL=http://$PUBLIC_IP:3001
      - REACT_APP_PRODUCT_SERVICE_URL=http://$PUBLIC_IP:3002
      - REACT_APP_CART_SERVICE_URL=http://$PUBLIC_IP:3003
      - REACT_APP_ORDER_SERVICE_URL=http://$PUBLIC_IP:3004
    depends_on:
      user-service:
        condition: service_healthy
      product-service:
        condition: service_healthy
      cart-service:
        condition: service_healthy
      order-service:
        condition: service_healthy
    networks:
      - ecommerce-network

networks:
  ecommerce-network:
    driver: bridge
COMPOSEEOF

echo "--- docker-compose.yml written ---"

# ── Pull images from DockerHub ────────────
echo "--- Pulling images from DockerHub ---"
docker pull ${dockerhub_username}/user-service:latest
docker pull ${dockerhub_username}/product-service:latest
docker pull ${dockerhub_username}/cart-service:latest
docker pull ${dockerhub_username}/order-service:latest
docker pull ${dockerhub_username}/frontend:latest

echo "--- All images pulled ---"

# ── Start all containers ──────────────────
echo "--- Starting containers ---"
docker compose up -d

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