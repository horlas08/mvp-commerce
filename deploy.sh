#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}          Koon Production Deployer            ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo "This script installs system prerequisites and deploys the FastAPI backend and Next.js admin using PM2."

# Ensure script is run as root or with sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this script with sudo or as root.${NC}"
  exit 1
fi

# Ask for domain configurations
echo -e "${YELLOW}Please enter configuration domains (e.g. yourdomain.com):${NC}"
read -p "API Domain (e.g. api.yourdomain.com): " API_DOMAIN
read -p "Admin Domain (e.g. admin.yourdomain.com): " ADMIN_DOMAIN

if [ -z "$API_DOMAIN" ] || [ -z "$ADMIN_DOMAIN" ]; then
  echo -e "${RED}Error: Domains are required to complete the Nginx configuration.${NC}"
  exit 1
fi

# Get the directory where the deploy script is located (root of repository)
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$ROOT_DIR"

echo -e "\n${GREEN}[1/6] Updating System Packages...${NC}"
apt-get update && apt-get upgrade -y

echo -e "\n${GREEN}[2/6] Installing Python and Virtualenv...${NC}"
apt-get install -y python3-pip python3-venv python3-dev

echo -e "\n${GREEN}[3/6] Installing Node.js, PNPM, and PM2...${NC}"
# Install Node.js LTS (v20) via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install pnpm and pm2 globally
npm install -g pnpm pm2

echo -e "\n${GREEN}[4/6] Installing Nginx and Certbot...${NC}"
apt-get install -y nginx certbot python3-certbot-nginx

# ----------------- Deploys Backend -----------------
echo -e "\n${GREEN}[5/6] Deploying FastAPI Backend...${NC}"
cd "$ROOT_DIR/backend"

# Setup python virtual environment
if [ ! -d "venv" ]; then
  echo -e "${BLUE}Creating Python virtual environment...${NC}"
  python3 -m venv venv
fi

# Install python dependencies
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Install database driver dependencies (Defaulting to SQLite, ready for PostgreSQL/MySQL)
pip install asyncpg aiomysql

# Setup basic environment variables if no .env exists
if [ ! -f ".env" ]; then
  echo -e "${BLUE}Generating default .env config...${NC}"
  JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  cat <<EOT > .env
DATABASE_URL="sqlite+aiosqlite:///./koon.db"
SECRET_KEY="$JWT_SECRET"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES=1440
EOT
  echo -e "${YELLOW}Warning: Generated default sqlite database in .env. Review .env to swap to MySQL/PostgreSQL.${NC}"
fi

# Start/Restart Backend via PM2
echo -e "${BLUE}Starting FastAPI Backend via PM2...${NC}"
# Delete previous process if it exists to avoid duplication
pm2 delete koon-backend 2>/dev/null || true
pm2 start "venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000" --name "koon-backend"
deactivate

# ----------------- Deploys Next.js Admin -----------------
echo -e "\n${GREEN}[6/6] Deploying Next.js Admin Panel...${NC}"
cd "$ROOT_DIR/admin"

# Setup default Next.js build environment variables
if [ ! -f ".env" ]; then
  cat <<EOT > .env
NEXT_PUBLIC_API_URL="https://$API_DOMAIN"
EOT
fi

echo -e "${BLUE}Installing NPM packages via PNPM...${NC}"
pnpm install

echo -e "${BLUE}Building Next.js application...${NC}"
pnpm build

# Start/Restart Admin via PM2
echo -e "${BLUE}Starting Next.js Admin via PM2...${NC}"
pm2 delete koon-admin 2>/dev/null || true
pm2 start "pnpm start" --name "koon-admin" -- --port 3000

# Save PM2 state to auto-start on server reboot
pm2 save
pm2 startup | tail -n 1 # Prints the system service command instructions

# ----------------- Nginx Reverse Proxy Setup -----------------
echo -e "\n${GREEN}Configuring Nginx Reverse Proxy...${NC}"

# Backend API site block
cat <<EOT > /etc/nginx/sites-available/koon-backend
server {
    listen 80;
    server_name $API_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOT

# Admin Dashboard site block
cat <<EOT > /etc/nginx/sites-available/koon-admin
server {
    listen 80;
    server_name $ADMIN_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOT

# Enable the configurations
ln -sf /etc/nginx/sites-available/koon-backend /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/koon-admin /etc/nginx/sites-enabled/

# Test and reload Nginx
nginx -t
systemctl restart nginx

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${GREEN}      Koon Services Deployed Successfully!    ${NC}"
echo -e "${GREEN}==============================================${NC}"
pm2 status

echo -e "\n${YELLOW}To secure your websites with Let's Encrypt SSL, run:${NC}"
echo -e "sudo certbot --nginx -d $API_DOMAIN -d $ADMIN_DOMAIN"
echo -e "\nReview backend environment config: ${BLUE}nano $ROOT_DIR/backend/.env${NC}"
echo -e "Review admin environment config: ${BLUE}nano $ROOT_DIR/admin/.env${NC}"
