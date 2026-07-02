# Backend & Admin VPS Deployment Guide

This guide covers deploying both the FastAPI backend and the Next.js admin panel on a Linux VPS. 

---

## ⚡ Quick Start: Automated Deployment (Recommended)

If you are using a fresh Ubuntu/Debian VPS with nothing installed, we have provided an automated deployment script in the project root:

1. **Clone the code to your VPS** (usually in `/var/www/koon`):
   ```bash
   cd /var/www
   git clone <your-repo-url> koon
   cd koon
   ```
2. **Run the deployment script:**
   ```bash
   sudo ./deploy.sh
   ```
3. **Follow the prompts** to enter your domains (e.g. `api.yourdomain.com` and `admin.yourdomain.com`). 
4. The script will automatically install Node.js, Python, Nginx, Certbot, PNPM, and PM2, compile the code, configure Nginx reverse proxies, and start both applications inside PM2.

---

## Manual Deployment Guide

If you prefer to configure components manually, follow the sections below.

---

## 1. Server Preparation

Connect to your VPS via SSH and install the system prerequisites:

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install Python, pip, virtualenv, and Nginx
sudo apt install python3-pip python3-venv nginx certbot python3-certbot-nginx git -y
```

### Clone and Setup Codebase
```bash
# Clone the project (replace with your repository URL)
cd /var/www
sudo git clone https://github.com/username/koon.git
sudo chown -R $USER:$USER /var/www/koon

# Navigate to the backend directory
cd /var/www/koon/backend

# Create a virtual environment
python3 -m venv venv

# Activate and install dependencies
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Create a `.env` file inside `/var/www/koon/backend/` and configure your environment variables (Database URL, Secret Key, etc.).

---

## 2. Process Management (Choose Option A or B)

To keep your FastAPI backend running in the background and automatically restart on crashes or server reboots, choose one of these two options:

### Option A: Using PM2 (Easiest if you already use PM2)
PM2 is not just for Node.js; it can manage any process, including Python scripts.

1. **Start the FastAPI backend with PM2:**
   Make sure you are in `/var/www/koon/backend/` and run:
   ```bash
   pm2 start "venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000" --name "koon-backend"
   ```
   *(Replace `main:app` with the path to your FastAPI entrypoint if your runner file is named differently, e.g. `app.main:app`).*

2. **Save PM2 status and enable restart on VPS reboot:**
   ```bash
   pm2 save
   pm2 startup
   ```
   *(Follow the screen prompt command output by `pm2 startup` to configure the system service).*

3. **Useful PM2 Commands:**
   ```bash
   pm2 status
   pm2 logs koon-backend
   pm2 restart koon-backend
   pm2 stop koon-backend
   ```

---

### Option B: Using Systemd (Recommended for Python production environments)
Systemd is the native system service manager built into Ubuntu/Debian Linux.

1. **Create the systemd service file:**
   ```bash
   sudo nano /etc/systemd/system/koon-backend.service
   ```

2. **Paste the following configuration:**
   ```ini
   [Unit]
   Description=FastAPI Koon Backend Service
   After=network.target

   [Service]
   User=ubuntu
   WorkingDirectory=/var/www/koon/backend
   ExecStart=/var/www/koon/backend/venv/bin/gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app --bind 127.0.0.1:8000
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```
   *(Notes: Adjust `User` if your VPS user is not `ubuntu`. The command runs 4 parallel Uvicorn workers via Gunicorn for high performance).*

3. **Start and enable the service:**
   ```bash
   # Reload systemd configuration
   sudo systemctl daemon-reload

   # Start the service
   sudo systemctl start koon-backend

   # Enable it to start automatically on VPS boot
   sudo systemctl enable koon-backend
   ```

4. **Useful Systemd Commands:**
   ```bash
   # Check logs
   sudo journalctl -u koon-backend -f

   # Check status
   sudo systemctl status koon-backend

   # Restart service
   sudo systemctl restart koon-backend
   ```

---

## 3. Nginx Reverse Proxy Setup

Nginx receives public HTTP/HTTPS requests on port 80/443 and forwards them to port 8000 (where the backend runs locally).

1. **Create a new Nginx block:**
   ```bash
   sudo nano /etc/nginx/sites-available/koon-backend
   ```

2. **Paste the Nginx configuration:**
   ```nginx
   server {
       listen 80;
       server_name api.yourdomain.com; # Replace with your API domain/IP

       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

3. **Enable configuration and restart Nginx:**
   ```bash
   # Create a symlink to sites-enabled
   sudo ln -s /etc/nginx/sites-available/koon-backend /etc/nginx/sites-enabled/

   # Test configuration for syntax errors
   sudo nginx -t

   # Restart Nginx
   sudo systemctl restart nginx
   ```

---

## 4. Secure Nginx with SSL (HTTPS)

Secure the connection using a free SSL certificate from Let's Encrypt via Certbot.

```bash
# Run Certbot to generate and configure SSL automatically
sudo certbot --nginx -d api.yourdomain.com
```

- Follow the interactive prompts (enter email, agree to terms).
- Certbot will automatically edit your Nginx configuration to add SSL certificates and redirect all HTTP traffic to HTTPS.
- Let's Encrypt certificates last for 90 days, but Certbot automatically installs a cron job to renew them automatically. You can test renewal with:
  ```bash
  sudo certbot renew --dry-run
  ```
