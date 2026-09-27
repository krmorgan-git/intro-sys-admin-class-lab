from flask import Flask, render_template, request, redirect, url_for, session, flash
import os
import sqlite3

app = Flask(__name__)
app.secret_key = 'sysadmin_secret_key_for_lab'

# Ensure the database directory exists
DB_DIR = os.path.join(app.root_path, 'instance')
os.makedirs(DB_DIR, exist_ok=True)
DB_PATH = os.path.join(DB_DIR, 'sysadmin_lab.db')

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Create Users Table (Plain text passwords intentional for lab learning)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL
        )
    ''')
    
    # 2. Create Generic IT Assets Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS it_inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hostname TEXT UNIQUE NOT NULL,
            ip_address TEXT NOT NULL,
            os_type TEXT NOT NULL,
            status TEXT NOT NULL,
            location TEXT NOT NULL
        )
    ''')
    
    # 3. Seed Hardcoded Instructor and Student Accounts
    default_users = [
        ('instructor_admin', 'password123', 'Instructor'),
        ('student_user', 'abc', 'Student')
    ]
    for username, password, role in default_users:
        try:
            cursor.execute(
                'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
                (username, password, role)
            )
        except sqlite3.IntegrityError:
            pass # Already seeded
            
    # 4. Seed Generic IT Assets Sample Data
    default_assets = [
        ('core-router-01', '192.168.200.1', 'Cisco IOS', 'Online', 'Main Rack A'),
        ('ubuntu-web-srv', '192.168.200.10', 'Ubuntu Server 24.04', 'Online', 'Server Room Box 1'),
        ('backup-nas', '192.168.200.50', 'TrueNAS', 'Offline', 'Storage Vault'),
        ('helpdesk-win11', '192.168.200.101', 'Windows 11 Pro', 'Online', 'IT Helpdesk')
    ]
    for hostname, ip, os_type, status, loc in default_assets:
        try:
            cursor.execute(
                'INSERT INTO it_inventory (hostname, ip_address, os_type, status, location) VALUES (?, ?, ?, ?, ?)',
                (hostname, ip, os_type, status, loc)
            )
        except sqlite3.IntegrityError:
            pass # Already seeded

    conn.commit()
    conn.close()

# Initialize the database layout immediately on application start
init_db()

@app.route('/')
def index():
    if 'username' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password'] # Intentional plain text check
        
        conn = get_db_connection()
        user = conn.execute(
            'SELECT * FROM users WHERE username = ? AND password = ?', 
            (username, password)
        ).fetchone()
        conn.close()
        
        if user:
            session['username'] = user['username']
            session['role'] = user['role']
            return redirect(url_for('dashboard'))
        else:
            flash('Invalid username or password configuration.', 'danger')
            
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password'] # Short, plain text passwords allowed
        
        if not username or not password:
            flash('Fields cannot be left blank.', 'danger')
            return render_template('register.html')
            
        conn = get_db_connection()
        try:
            conn.execute(
                'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
                (username, password, 'Student')
            )
            conn.commit()
            flash('Account created successfully! You can now log in.', 'success')
            return redirect(url_for('login'))
        except sqlite3.IntegrityError:
            flash('Username already exists in the system database.', 'danger')
        finally:
            conn.close()
            
    return render_template('register.html')

@app.route('/dashboard')
def dashboard():
    if 'username' not in session:
        flash('Authentication required. Please log in first.', 'warning')
        return redirect(url_for('login'))
        
    conn = get_db_connection()
    assets = conn.execute('SELECT * FROM it_inventory').fetchall()
    conn.close()
    return render_template('dashboard.html', assets=assets)

@app.route('/logout')
def logout():
    session.clear()
    flash('Logged out successfully.', 'info')
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
