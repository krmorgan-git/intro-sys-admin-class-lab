#!/bin/bash

# ANSI Color Codes for Scannable Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==================================================${NC}"
echo -e "${YELLOW}   System Administration Lab: Deployment Tester   ${NC}"
echo -e "${YELLOW}==================================================${NC}"

# Check if script is run as root (required for systemd and Nginx checks)
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run this test script with sudo:${NC}"
  echo -e "        sudo ./test_assignment.sh"
  exit 1
fi

SCORE=0
TOTAL_TESTS=5

# -------------------------------------------------------------
# TEST 1: Check systemd Service Configuration
# -------------------------------------------------------------
echo -e "\n${YELLOW}[TEST 1/5] Checking systemd service installation...${NC}"
if systemctl is-active --quiet flasklab; then
    echo -e "${GREEN}[PASS] Systemd service 'flasklab' is active and running.${NC}"
    ((SCORE++))
else
    echo -e "${RED}[FAIL] Systemd service 'flasklab' is inactive or not installed.${NC}"
    echo -e "       Run: 'sudo systemctl status flasklab' to debug."
fi

# -------------------------------------------------------------
# TEST 2: Check if Gunicorn is listening on Port 5000
# -------------------------------------------------------------
echo -e "\n${YELLOW}[TEST 2/5] Checking internal Gunicorn socket binding...${NC}"
if ss -tlnp | grep -q ":5000 "; then
    echo -e "${GREEN}[PASS] Application server is listening locally on port 5000.${NC}"
    ((SCORE++))
else
    echo -e "${RED}[FAIL] No local process is listening on port 5000.${NC}"
    echo -e "       Ensure Gunicorn is bound to 127.0.0.1:5000 in your service file."
fi

# -------------------------------------------------------------
# TEST 3: Check Nginx Reverse Proxy Server Block Configuration
# -------------------------------------------------------------
echo -e "\n${YELLOW}[TEST 3/5] Verifying Nginx server configurations...${NC}"
if [ -L "/etc/nginx/sites-enabled/flasklab" ]; then
    # Verify Nginx syntax configuration is intact
    if nginx -t > /dev/null 2>&1; then
        echo -e "${GREEN}[PASS] Nginx configuration file is active and syntax is correct.${NC}"
        ((SCORE++))
    else
        echo -e "${RED}[FAIL] Nginx syntax check failed.${NC}"
        echo -e "       Run: 'sudo nginx -t' to identify configuration syntax errors."
    fi
else
    echo -e "${RED}[FAIL] Nginx profile link 'flasklab' is missing from sites-enabled.${NC}"
    echo -e "       Ensure you created the symbolic link via 'sudo ln -s'."
fi

# -------------------------------------------------------------
# TEST 4: Check SQLite Database and Parent Directory Permissions
# -------------------------------------------------------------
echo -e "\n${YELLOW}[TEST 4/5] Checking SQLite3 database directory write permissions...${NC}"
DB_DIR="/var/www/sysadmin-flask-lab/instance"
DB_FILE="$DB_DIR/sysadmin_lab.db"

if [ -d "$DB_DIR" ] && [ -f "$DB_FILE" ]; then
    # Verify group ownership is set to www-data
    DIR_GROUP=$(stat -c '%G' "$DB_DIR")
    FILE_GROUP=$(stat -c '%G' "$DB_FILE")
    
    # Check write permission flags
    DIR_PERM=$(stat -c '%A' "$DB_DIR" | cut -c 6)
    FILE_PERM=$(stat -c '%A' "$DB_FILE" | cut -c 6)

    if [ "$DIR_GROUP" == "www-data" ] && [ "$DIR_PERM" == "w" ] && [ "$FILE_GROUP" == "www-data" ] && [ "$FILE_PERM" == "w" ]; then
        echo -e "${GREEN}[PASS] 'www-data' group has correct write permissions for SQLite database access.${NC}"
        ((SCORE++))
    else
        echo -e "${RED}[FAIL] Permission issue detected. 'www-data' group cannot write to the database environment.${NC}"
        echo -e "       Current group owner: Dir ($DIR_GROUP), File ($FILE_GROUP)"
        echo -e "       Review step 4 in the README to apply chgrp and chmod patches."
    fi
else
    echo -e "${RED}[FAIL] Database folder paths not found. Run the app once to initialize files.${NC}"
    echo -e "       Expected path: $DB_FILE"
fi

# -------------------------------------------------------------
# TEST 5: Live HTTP Status Response Routing Verification
# -------------------------------------------------------------
echo -e "\n${YELLOW}[TEST 5/5] Performing live endpoint routing check...${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0)

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo -e "${GREEN}[PASS] Nginx successfully handled port 80 routing and reached the Flask application login interface.${NC}"
    ((SCORE++))
else
    echo -e "${RED}[FAIL] HTTP target routing failure. Received HTTP Status: $HTTP_STATUS (Expected: 200).${NC}"
    echo -e "       Ensure Nginx service is running and restarted via systemctl."
fi

# -------------------------------------------------------------
# SUMMARY SCORE
# -------------------------------------------------------------
echo -e "\n${YELLOW}==================================================${NC}"
if [ "$SCORE" -eq "$TOTAL_TESTS" ]; then
    echo -e "${GREEN}LAB COMPLETE: All tests passed successfully! (${SCORE}/${TOTAL_TESTS})${NC}"
else
    echo -e "${RED}LAB INCOMPLETE: Fix highlighted configuration errors. (${SCORE}/${TOTAL_TESTS})${NC}"
fi
echo -e "${YELLOW}==================================================${NC}"
