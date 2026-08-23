#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Get the directory where the deploy script is located (root of repository)
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$ROOT_DIR"

# ----------------- Smart Domain Detection & Configuration -----------------
API_CONSTANTS_FILE="$ROOT_DIR/koon_mobile/lib/app/constants/api_constants.dart"
DEFAULT_BASE_DOMAIN="widdistore.com"

# Extract production host from api_constants.dart if available
if [ -f "$API_CONSTANTS_FILE" ]; then
  EXTRACTED_HOST=$(grep -oE "https?://[a-zA-Z0-9.-]+" "$API_CONSTANTS_FILE" | head -1 | sed -e 's|^https\?://||')
  if [ -n "$EXTRACTED_HOST" ]; then
    EXTRACTED_BASE=$(echo "$EXTRACTED_HOST" | sed -e 's/^api\.//')
    if [ -n "$EXTRACTED_BASE" ]; then
      DEFAULT_BASE_DOMAIN="$EXTRACTED_BASE"
    fi
  fi
fi

echo -e "\n${YELLOW}==============================================${NC}"
echo -e "${YELLOW}           Domain Configuration               ${NC}"
echo -e "${YELLOW}==============================================${NC}"

read -p "Are you configuring custom domains? (Y/n) [default: y]: " USE_CUSTOM_DOMAIN
USE_CUSTOM_DOMAIN=${USE_CUSTOM_DOMAIN:-y}

if [[ "$USE_CUSTOM_DOMAIN" =~ ^[Yy]$ ]]; then
  echo -e "Detected default base domain from api_constants.dart: ${CYAN}${DEFAULT_BASE_DOMAIN}${NC}"
  
  read -p "Enter Base Domain [default: $DEFAULT_BASE_DOMAIN]: " INPUT_BASE_DOMAIN
  BASE_DOMAIN=${INPUT_BASE_DOMAIN:-$DEFAULT_BASE_DOMAIN}

  read -p "Enter API Subdomain [default: api]: " INPUT_API_SUB
  API_SUB=${INPUT_API_SUB:-api}

  read -p "Enter Admin Subdomain [default: admin]: " INPUT_ADMIN_SUB
  ADMIN_SUB=${INPUT_ADMIN_SUB:-admin}

  # Build full domains (handling root domain '@' or empty subdomains)
  if [ -z "$API_SUB" ] || [ "$API_SUB" = "@" ]; then
    API_DOMAIN="$BASE_DOMAIN"
  else
    API_DOMAIN="${API_SUB}.${BASE_DOMAIN}"
  fi

  if [ -z "$ADMIN_SUB" ] || [ "$ADMIN_SUB" = "@" ]; then
    ADMIN_DOMAIN="$BASE_DOMAIN"
  else
    ADMIN_DOMAIN="${ADMIN_SUB}.${BASE_DOMAIN}"
  fi

  echo -e "\n${GREEN}Calculated Domain Endpoints:${NC}"
  echo -e "  • API Domain:   ${CYAN}https://${API_DOMAIN}${NC}"
  echo -e "  • Admin Domain: ${CYAN}https://${ADMIN_DOMAIN}${NC}"

  read -p "Do you want to manually override any of these domains? (y/N) [default: n]: " OVERRIDE_DOMAINS
  OVERRIDE_DOMAINS=${OVERRIDE_DOMAINS:-n}

  if [[ "$OVERRIDE_DOMAINS" =~ ^[Yy]$ ]]; then
    read -p "Enter Full API Domain [current: $API_DOMAIN]: " CUSTOM_API_DOMAIN
    API_DOMAIN=${CUSTOM_API_DOMAIN:-$API_DOMAIN}
    read -p "Enter Full Admin Domain [current: $ADMIN_DOMAIN]: " CUSTOM_ADMIN_DOMAIN
    ADMIN_DOMAIN=${CUSTOM_ADMIN_DOMAIN:-$ADMIN_DOMAIN}
  fi

  # Auto-sync api_constants.dart if the production URL changed
  if [ -f "$API_CONSTANTS_FILE" ]; then
    CURRENT_PROD_URL=$(grep -oE "https?://[^']+/api/v1" "$API_CONSTANTS_FILE" | head -1 || true)
    TARGET_PROD_URL="https://${API_DOMAIN}/api/v1"
    if [ -n "$CURRENT_PROD_URL" ] && [ "$CURRENT_PROD_URL" != "$TARGET_PROD_URL" ]; then
      echo -e "${BLUE}Syncing production URL in api_constants.dart to '${TARGET_PROD_URL}'...${NC}"
      sed -i.bak "s|$CURRENT_PROD_URL|$TARGET_PROD_URL|g" "$API_CONSTANTS_FILE" 2>/dev/null || sed -i "" "s|$CURRENT_PROD_URL|$TARGET_PROD_URL|g" "$API_CONSTANTS_FILE"
      rm -f "${API_CONSTANTS_FILE}.bak"
    fi
  fi

else
  # IP / Local testing mode
  DETECTED_IP=$(curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
  read -p "Enter Server IP / Hostname [default: $DETECTED_IP]: " INPUT_SERVER_IP
  SERVER_IP=${INPUT_SERVER_IP:-$DETECTED_IP}
  API_DOMAIN="$SERVER_IP"
  ADMIN_DOMAIN="$SERVER_IP"
fi

if [ -z "$API_DOMAIN" ] || [ -z "$ADMIN_DOMAIN" ]; then
  echo -e "${RED}Error: Valid domains or IP addresses are required to complete the configuration.${NC}"
  exit 1
fi

# Helper function to generate a secure random password
generate_random_password() {
  if command -v python3 &>/dev/null; then
    python3 -c "import secrets; print(secrets.token_urlsafe(16))"
  else
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20
  fi
}

# ----------------- Database Selection & Setup -----------------
echo -e "\n${CYAN}==============================================${NC}"
echo -e "${CYAN}          Select Database Engine              ${NC}"
echo -e "${CYAN}==============================================${NC}"
echo "1) SQLite      (File-based, zero setup, self-contained)"
echo "2) PostgreSQL  (Recommended for high concurrency / production)"
echo "3) MySQL / MariaDB (High performance relational database)"
echo -e "----------------------------------------------"

read -p "Select option [1-3] (Default: 1): " DB_CHOICE
DB_CHOICE=${DB_CHOICE:-1}

DATABASE_TYPE="sqlite"
DATABASE_URL="sqlite+aiosqlite:///./koon.db"
DB_NAME=""
DB_USER=""
DB_PASS=""
DB_HOST="127.0.0.1"
DB_PORT=""

case "$DB_CHOICE" in
  2)
    DATABASE_TYPE="postgresql"
    DB_PORT="5432"
    echo -e "\n${GREEN}Configuring PostgreSQL Database...${NC}"
    
    echo "1) Install and configure local PostgreSQL on this server (Default)"
    echo "2) Connect to an existing / remote PostgreSQL instance"
    read -p "Choose installation mode [1-2] (Default: 1): " PG_MODE
    PG_MODE=${PG_MODE:-1}

    DEFAULT_PASS=$(generate_random_password)
    
    read -p "Database Name [default: koon_db]: " INPUT_DB_NAME
    DB_NAME=${INPUT_DB_NAME:-koon_db}

    read -p "Database Username [default: koon_user]: " INPUT_DB_USER
    DB_USER=${INPUT_DB_USER:-koon_user}

    read -p "Database Password [default: $DEFAULT_PASS]: " INPUT_DB_PASS
    DB_PASS=${INPUT_DB_PASS:-$DEFAULT_PASS}

    if [ "$PG_MODE" = "2" ]; then
      read -p "Database Host [default: 127.0.0.1]: " INPUT_DB_HOST
      DB_HOST=${INPUT_DB_HOST:-127.0.0.1}

      read -p "Database Port [default: 5432]: " INPUT_DB_PORT
      DB_PORT=${INPUT_DB_PORT:-5432}
    else
      DB_HOST="127.0.0.1"
      DB_PORT="5432"
    fi

    DATABASE_URL="postgresql+asyncpg://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    ;;

  3)
    DATABASE_TYPE="mysql"
    DB_PORT="3306"
    echo -e "\n${GREEN}Configuring MySQL / MariaDB Database...${NC}"
    
    echo "1) Install and configure local MariaDB/MySQL on this server (Default)"
    echo "2) Connect to an existing / remote MySQL instance"
    read -p "Choose installation mode [1-2] (Default: 1): " MYSQL_MODE
    MYSQL_MODE=${MYSQL_MODE:-1}

    DEFAULT_PASS=$(generate_random_password)

    read -p "Database Name [default: koon_db]: " INPUT_DB_NAME
    DB_NAME=${INPUT_DB_NAME:-koon_db}

    read -p "Database Username [default: koon_user]: " INPUT_DB_USER
    DB_USER=${INPUT_DB_USER:-koon_user}

    read -p "Database Password [default: $DEFAULT_PASS]: " INPUT_DB_PASS
    DB_PASS=${INPUT_DB_PASS:-$DEFAULT_PASS}

    if [ "$MYSQL_MODE" = "2" ]; then
      read -p "Database Host [default: 127.0.0.1]: " INPUT_DB_HOST
      DB_HOST=${INPUT_DB_HOST:-127.0.0.1}

      read -p "Database Port [default: 3306]: " INPUT_DB_PORT
      DB_PORT=${INPUT_DB_PORT:-3306}
    else
      DB_HOST="127.0.0.1"
      DB_PORT="3306"
    fi

    DATABASE_URL="mysql+aiomysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}?charset=utf8mb4"
    ;;

  *)
    DATABASE_TYPE="sqlite"
    DATABASE_URL="sqlite+aiosqlite:///./koon.db"
    echo -e "\n${GREEN}Selected SQLite file database: ./koon.db${NC}"
    ;;
esac

# ----------------- 1. System Package Updates -----------------
echo -e "\n${GREEN}[1/6] Updating System Packages...${NC}"
apt-get update && apt-get upgrade -y

# ----------------- 2. Python & Build Prerequisites -----------------
echo -e "\n${GREEN}[2/6] Installing Python and System Tools...${NC}"
apt-get install -y python3-pip python3-venv python3-dev build-essential libssl-dev libffi-dev curl wget git

# ----------------- 3. Database Server Installation (If Local) -----------------
if [ "$DATABASE_TYPE" = "postgresql" ] && [ "$PG_MODE" = "1" ]; then
  echo -e "\n${BLUE}Installing & Configuring local PostgreSQL server...${NC}"
  apt-get install -y postgresql postgresql-contrib
  systemctl enable postgresql
  systemctl start postgresql

  echo -e "${BLUE}Provisioning PostgreSQL user & database...${NC}"
  sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}'; ELSE ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}'; END IF; END \$\$;"
  sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
  sudo -u postgres psql -d "${DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" 2>/dev/null || true
  echo -e "${GREEN}✓ PostgreSQL database '${DB_NAME}' created successfully.${NC}"

elif [ "$DATABASE_TYPE" = "mysql" ] && [ "$MYSQL_MODE" = "1" ]; then
  echo -e "\n${BLUE}Installing & Configuring local MariaDB/MySQL server...${NC}"
  apt-get install -y mariadb-server mariadb-client || apt-get install -y mysql-server mysql-client
  systemctl enable mariadb 2>/dev/null || systemctl enable mysql 2>/dev/null || true
  systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null || true

  echo -e "${BLUE}Provisioning MySQL user & database...${NC}"
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1'; FLUSH PRIVILEGES;"
  echo -e "${GREEN}✓ MySQL/MariaDB database '${DB_NAME}' created successfully.${NC}"
fi

# ----------------- 4. Node.js, PNPM, PM2, Nginx, Certbot -----------------
echo -e "\n${GREEN}[3/6] Installing Node.js LTS, PNPM, and PM2...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g pnpm pm2

echo -e "\n${GREEN}[4/6] Installing Nginx and Certbot...${NC}"
apt-get install -y nginx certbot python3-certbot-nginx

# ----------------- 5. Deploys Backend -----------------
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

# Ensure DB-specific async drivers are installed
if [ "$DATABASE_TYPE" = "postgresql" ]; then
  pip install asyncpg
elif [ "$DATABASE_TYPE" = "mysql" ]; then
  pip install aiomysql cryptography
elif [ "$DATABASE_TYPE" = "sqlite" ]; then
  pip install aiosqlite
fi

# Generate JWT secret key
JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# Backup existing .env if present
if [ -f ".env" ]; then
  cp .env ".env.backup.$(date +%s)"
fi

# Write .env configuration
cat <<EOT > .env
DATABASE_URL="$DATABASE_URL"
SECRET_KEY="$JWT_SECRET"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES=1440
EOT

echo -e "${GREEN}✓ Backend .env generated with DATABASE_URL=${DATABASE_URL}${NC}"

# Start/Restart Backend via PM2
echo -e "${BLUE}Starting FastAPI Backend via PM2...${NC}"
pm2 delete koon-backend 2>/dev/null || true
pm2 start "venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000" --name "koon-backend"
deactivate

# ----------------- 6. Deploys Next.js Admin -----------------
echo -e "\n${GREEN}[6/6] Deploying Next.js Admin Panel...${NC}"
cd "$ROOT_DIR/admin"

# Setup Next.js environment variables
if [[ "$USE_CUSTOM_DOMAIN" =~ ^[Yy]$ ]]; then
  ADMIN_API_ENDPOINT="https://$API_DOMAIN"
else
  ADMIN_API_ENDPOINT="http://$API_DOMAIN:8000"
fi

cat <<EOT > .env
NEXT_PUBLIC_API_URL="$ADMIN_API_ENDPOINT"
EOT

echo -e "${BLUE}Installing NPM packages via PNPM...${NC}"
pnpm install

echo -e "${BLUE}Building Next.js application...${NC}"
pnpm build

# Start/Restart Admin via PM2
echo -e "${BLUE}Starting Next.js Admin via PM2...${NC}"
pm2 delete koon-admin 2>/dev/null || true
pm2 start "node_modules/.bin/next start -p 3000" --name "koon-admin" || pm2 start "pnpm start -- -p 3000" --name "koon-admin"

# Save PM2 state to auto-start on server reboot
pm2 save
pm2 startup | tail -n 1 || true

# ----------------- 7. Nginx Reverse Proxy Setup -----------------
echo -e "\n${GREEN}Configuring Nginx Reverse Proxy...${NC}"

# Disable default Nginx welcome site to prevent it from capturing traffic
rm -f /etc/nginx/sites-enabled/default

# Backend API site block
cat <<EOT > /etc/nginx/sites-available/koon-backend
server {
    listen 80;
    server_name $API_DOMAIN;

    client_max_body_size 50M;

    location / {
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '\$http_origin' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, PATCH, DELETE, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
            add_header 'Access-Control-Allow-Credentials' 'true' always;
            add_header 'Access-Control-Max-Age' 1728000 always;
            add_header 'Content-Type' 'text/plain; charset=utf-8' always;
            add_header 'Content-Length' 0 always;
            return 204;
        }

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

    client_max_body_size 50M;

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
systemctl reload nginx || systemctl restart nginx

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}        Koon Services Deployed Successfully!          ${NC}"
echo -e "${GREEN}======================================================${NC}"
pm2 status

echo -e "\n${CYAN}----------------- Deployment Summary -----------------${NC}"
echo -e "API Domain:       ${BLUE}https://$API_DOMAIN${NC}"
echo -e "Admin Domain:     ${BLUE}https://$ADMIN_DOMAIN${NC}"
echo -e "Database Engine:  ${YELLOW}${DATABASE_TYPE^^}${NC}"
if [ "$DATABASE_TYPE" != "sqlite" ]; then
  echo -e "Database Name:    ${GREEN}$DB_NAME${NC}"
  echo -e "Database User:    ${GREEN}$DB_USER${NC}"
  echo -e "Database Pass:    ${GREEN}$DB_PASS${NC}"
  echo -e "Database Host:    ${GREEN}$DB_HOST:$DB_PORT${NC}"
fi
echo -e "Database URL:     ${YELLOW}$DATABASE_URL${NC}"
echo -e "${CYAN}------------------------------------------------------${NC}"

if [[ "$USE_CUSTOM_DOMAIN" =~ ^[Yy]$ ]]; then
  echo -e "\n${YELLOW}To secure your websites with Let's Encrypt SSL, run:${NC}"
  echo -e "sudo certbot --nginx -d $API_DOMAIN -d $ADMIN_DOMAIN"
fi

echo -e "\nReview backend environment config: ${BLUE}nano $ROOT_DIR/backend/.env${NC}"
echo -e "Review admin environment config:   ${BLUE}nano $ROOT_DIR/admin/.env${NC}"
