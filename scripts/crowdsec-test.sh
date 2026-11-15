#!/usr/bin/env bash

set -euo pipefail

#########################################
# Farben
#########################################
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

#########################################
# Header
#########################################

clear

echo "=============================================="
echo "   CrowdSec AppSec (WAF) Test-Skript"
echo "=============================================="
echo

read -rp "Bitte gib deine Traefik-Domain ein (z.B. traefik.deinedomain.de): " DOMAIN

URL="https://${DOMAIN}"

echo
echo "Ziel-URL festgelegt auf: ${URL}"

#########################################
# Alte Bans entfernen
#########################################

echo "Bereinige Altlasten (Lösche alle bestehenden Bans)..."

docker exec -it crowdsec cscli decisions delete --all >/dev/null 2>&1 || true

echo

#########################################
# Metriken vorher
#########################################

echo "[1/4] Zeige initiale AppSec-Metriken..."
echo

docker exec -it crowdsec cscli metrics

#########################################
# Funktion
#########################################

test_attack() {

    local NAME="$1"
    local CURL="$2"

    printf "  -> Teste %-40s" "$NAME"

    CODE=$(eval "$CURL")

    if [[ "$CODE" == "403" ]]; then
        echo -e "${GREEN}Blockiert (HTTP Code: ${CODE}) ✓${RESET}"
    else
        echo -e "${RED}NICHT blockiert (HTTP Code: ${CODE}) ✗${RESET}"
    fi
}

#########################################
# Tests
#########################################

echo
echo "[2/4] Führe simulierte Angriffe gegen ${URL} aus..."
echo

echo "--- Standard Web-Angriffe (OWASP CRS IDs) ---"

test_attack \
"SQL-Injection (SQLi)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/?id=1%20UNION%20SELECT%201,2,3'"

test_attack \
"Cross-Site Scripting (XSS)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/?q=%3Cscript%3Ealert(1)%3C/script%3E'"

test_attack \
"Local File Inclusion (LFI)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/?file=../../../../etc/passwd'"

echo
echo "--- Generische Web-Angriffe (Namen-IDs) ---"

test_attack \
"WP Uploads PHP (generic-wordpress-uploads-php)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/wp-content/uploads/shell.php'"

test_attack \
"WP Uploads Listing (generic-wordpress-uploads-listing)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/wp-content/uploads/'"

echo
echo "--- Virtual Patching (CVEs & Exposures) ---"

test_attack \
"PHP CGI RCE (CVE-2024-4577)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/?%ADd+allow_url_include=1'"

test_attack \
"Exposed .env Datei (vpatch-env-access)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/.env'"

test_attack \
"Exposed Git Verzeichnis (vpatch-git-config)..." \
"curl -ks -o /dev/null -w '%{http_code}' '${URL}/.git/config'"

#########################################
# Warten
#########################################

echo
echo "[3/4] Warte 4 Sekunden auf die Verarbeitung durch CrowdSec..."
sleep 4

#########################################
# Metriken danach
#########################################

echo
echo "[4/4] Zeige aktualisierte AppSec-Metriken..."
echo

docker exec -it crowdsec cscli metrics

echo
echo "=============================================="
echo "Test beendet!"
echo "Die Metriken ('Processed' und 'Blocked') sollten nun exakt um 8 gestiegen sein."
echo "=============================================="
