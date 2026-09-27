# Lab: Deploying a Flask & SQLite3 Application via Nginx

## Objective
In this lab, you will practice deploying a production-ready Python web application on an **Ubuntu Server** using **Gunicorn** as a WSGI server and **Nginx** as a reverse proxy. 

Additionally, you will inspect an unhashed, plaintext SQLite3 database backend to analyze security vulnerabilities regarding credential storage.

---

## Prerequisites
Before beginning, ensure you have the following installed on your Ubuntu target machine:
* Python 3 & `python3-venv`
* Nginx
* Git

---

## Step 1: Clone the Project and Configure the Virtual Environment

1. Clone this repository to your target directory (e.g., `/var/www/sysadmin-flask-lab`):
   ```bash
   sudo git clone <your-github-repo-url> /var/www/sysadmin-flask-lab
   ```

2. Change ownership of the directory to your standard user account so you can configure it without using `sudo` for every command:
   ```bash
   sudo chown -R $USER:$USER /var/www/sysadmin-flask-lab
   ```

3. Navigate to the directory and establish an isolated Python virtual environment:
   ```bash
   cd /var/www/sysadmin-flask-lab
   python3 -m venv .venv
   source .venv/bin/activate
   ```

4. Install the required application dependencies:
   ```bash
   pip install -r requirements.txt
   ```

---

## Step 2: Configure Systemd to Manage Gunicorn

To ensure the application runs continuously in the background and restarts automatically on system boot, you must create a systemd service file.

1. Generate a new service unit configuration:
   ```bash
   sudo nano /etc/systemd/system/flasklab.service
   ```

2. Add the following layout to the file:
   ```ini
   [Unit]
   Description=Gunicorn instance to serve the SysAdmin Flask Lab
   After=network.target

   [Service]
   User=ubuntu
   WorkingDirectory=/var/www/sysadmin-flask-lab
   Environment="PATH=/var/www/sysadmin-flask-lab/.venv/bin"
   ExecStart=/var/www/sysadmin-flask-lab/.venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 app:app

   [Install]
   WantedBy=multi-user.target
   ```
   *(Note: Modify `User=ubuntu` to match your target system username if different).*

3. Initialize, start, and enable your new systemd service block:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl start flasklab
   sudo systemctl enable flasklab
   ```

---

## Step 3: Configure Nginx as a Reverse Proxy

Now you must configure Nginx to listen on standard HTTP (Port 80) and safely route public web browser requests over to Gunicorn's local internal port (5000).

1. Open a new server block deployment profile:
   ```bash
   sudo nano /etc/nginx/sites-available/flasklab
   ```

2. Populate the profile with the following structural layout:
   ```nginx
   server {
       listen 80;
       server_name _; # Responds to any incoming IP address routing

       location / {
           proxy_pass http://127.0.0.1:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

3. Enable the routing block by linking it directly to the active sites configuration folder:
   ```bash
   sudo ln -s /etc/nginx/sites-available/flasklab /etc/nginx/sites-enabled/
   ```

4. Remove the default Nginx welcome profile to prevent routing conflicts, verify your syntax, and restart the daemon:
   ```bash
   sudo rm /etc/nginx/sites-enabled/default
   sudo nginx -t
   sudo systemctl restart nginx
   ```

---

## ⚠️ Critical Step 4: Resolving the SQLite Permission Trap

Open a web browser, target your server's IP address, and attempt to register a new account or log in using the preloaded default credentials:
* **Username:** `student_user` 
* **Password:** `abc`

### The Error:
When you attempt to commit user inputs, you will likely hit an **HTTP 500 Internal Server Error**. Checking your systemd logs (`sudo journalctl -u flasklab`) will reveal an SQLite exception: `sqlite3.OperationalError: attempt to write a readonly database`.

### The SysAdmin Fix:
SQLite databases require **write access** to both the `.db` file *and the parent directory* it sits in to create temporary rollback journals during transactions. Because Nginx runs under the `www-data` system account, you must grant it appropriate access:

```bash
# 1. Change the group ownership of the instance directory and database to the web server group
sudo chgrp -R www-data /var/www/sysadmin-flask-lab/instance

# 2. Grant group read and write permissions
sudo chmod 775 /var/www/sysadmin-flask-lab/instance
sudo chmod 664 /var/www/sysadmin-flask-lab/instance/sysadmin_lab.db
```

Verify your fix by refreshing the web browser and submitting your login profile again.

---

## 🔍 Post-Deployment Security Analysis Quiz

Once your server configuration is successfully running and handling live browser traffic, access your server's terminal and execute:
```bash
sqlite3 /var/www/sysadmin-flask-lab/instance/sysadmin_lab.db "SELECT * FROM users;"
```

### Analysis Deliverables:
1. Identify the structural hazard visible inside the terminal output.
2. In your lab report, explain the security implications of this configuration and describe what algorithmic mechanism should be implemented in a subsequent development cycle to fix it.
