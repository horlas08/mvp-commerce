# Koon Commerce Project

Koon is a modern cross-platform e-commerce solution featuring a FastAPI backend and a Flutter mobile application. The mobile app integrates web view scraping engines for platforms like AliExpress, Alibaba, Shein, Amazon, and iHerb.

---

## Codebase Directory Structure

* [/backend](file:///Users/user/project/koon/backend): FastAPI-based REST API backend server.
* [/koon_mobile](file:///Users/user/project/koon/koon_mobile): Flutter-based mobile application.
* [/store_source](file:///Users/user/project/koon/store_source): HTML source dumps used for parsing and webview testing.
* [deploy.sh](file:///Users/user/project/koon/deploy.sh): Bash script to automate installation and deployment of both backend and admin via PM2 on a fresh VPS.

---

## Database Switching Guide (SQLite to PostgreSQL/MySQL)

The backend uses **SQLAlchemy ORM** to manage data models. By default, it connects to a local SQLite instance (`koon.db`). Switching to a production-ready database on your VPS requires no changes to the Python codebase.

### 1. Install Async Drivers on VPS
Because the FastAPI app runs database queries asynchronously, you must install the corresponding async client driver:

* **PostgreSQL (Recommended)**
  ```bash
  pip install asyncpg
  ```
* **MySQL**
  ```bash
  pip install aiomysql
  ```

### 2. Database Server Setup on VPS

#### Option A: PostgreSQL Setup
1. Log in to PostgreSQL:
   ```bash
   sudo -u postgres psql
   ```
2. Create the database, user, and grant privileges:
   ```sql
   CREATE DATABASE koon_db;
   CREATE USER koon_user WITH PASSWORD 'your_secure_password';
   GRANT ALL PRIVILEGES ON DATABASE koon_db TO koon_user;
   \q
   ```

#### Option B: MySQL Setup
1. Log in to MySQL:
   ```bash
   mysql -u root -p
   ```
2. Create the database, user, and grant privileges:
   ```sql
   CREATE DATABASE koon_db;
   CREATE USER 'koon_user'@'localhost' IDENTIFIED BY 'your_secure_password';
   GRANT ALL PRIVILEGES ON koon_db.* TO 'koon_user'@'localhost';
   FLUSH PRIVILEGES;
   EXIT;
   ```

### 3. Update the Environment Variables
Configure the `DATABASE_URL` environment variable on your VPS. The app will automatically connect to the target database and build the required tables upon starting.

* **For PostgreSQL:**
  ```env
  DATABASE_URL="postgresql+asyncpg://koon_user:your_secure_password@localhost/koon_db"
  ```
* **For MySQL:**
  ```env
  DATABASE_URL="mysql+aiomysql://koon_user:your_secure_password@localhost/koon_db"
  ```

---

## Sub-System Documentation

For detailed deployment guides and feature specifications, refer to the following files:

1. **[Backend Deployment Guide](file:///Users/user/project/koon/deploy.md):** Step-by-step instructions on setting up Gunicorn, PM2/Systemd process management, Nginx reverse proxy, and Let's Encrypt SSL on a Linux VPS.
2. **[Cart Auto-Update Specification](file:///Users/user/project/koon/cart_autoupdate_readme.md):** Information regarding cart auto-updating when users return to the application after product modifications or price updates.
