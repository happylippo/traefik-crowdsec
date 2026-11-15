#!/usr/bin/env bash
set -euo pipefail

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

clear
echo "=============================================="
echo "   CrowdSec AppSec (WAF) Test-Skript"
echo "=============================================="
echo

read -rp "Bitte gib deine Traefik-Domain ein (z.B. traefik.deinedomain.de): " DOMAIN
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN%/}"
URL="https://${DOMAIN}"

echo
echo "Ziel-URL festgelegt auf: ${URL}"
echo
echo "Bereinige Altlasten (lösche alle bestehenden Bans)..."
docker exec crowdsec cscli decisions delete --all >/dev/null 2>&1 || true

echo
echo "[1/4] Zeige initiale AppSec-Metriken..."
echo
docker exec crowdsec cscli metrics

test_attack() {
    local NAME="$1"
    local PATH="$2"
    local CODE

    printf "  -> Teste %-40s" "$NAME"
    CODE=$(curl -ks -o /dev/null -w '%{http_code}' -- "${URL}${PATH}")

    if [[ "$CODE" == "403" ]]; then
        echo -e "${GREEN}Blockiert (HTTP Code: ${CODE}) ✓${RESET}"
    else
        echo -e "${RED}NICHT blockiert (HTTP Code: ${CODE}) ✗${RESET}"
    fi
}

echo
echo "[2/4] Führe simulierte Angriffe gegen ${URL} aus..."
echo
echo "--- Standard Web-Angriffe (OWASP CRS IDs) ---"
test_attack "SQL-Injection (SQLi)..." "/?id=1%20UNION%20SELECT%201,2,3"
test_attack "Cross-Site Scripting (XSS)..." "/?q=%3Cscript%3Ealert(1)%3C/script%3E"
test_attack "Local File Inclusion (LFI)..." "/?file=../../../../etc/passwd"

echo
echo "--- Generische Web-Angriffe (Namen-IDs) ---"
test_attack "WP Uploads PHP (generic-wordpress-uploads-php)..." "/wp-content/uploads/shell.php"
test_attack "WP Uploads Listing (generic-wordpress-uploads-listing)..." "/wp-content/uploads/"

echo
echo "--- Virtual Patching (CVEs & Exposures) ---"
test_attack "PHP CGI RCE (CVE-2024-4577)..." "/?%ADd+allow_url_include=1"
test_attack "Exposed .env Datei (vpatch-env-access)..." "/.env"
test_attack "Exposed Git Verzeichnis (vpatch-git-config)..." "/.git/config"

echo
echo "[3/4] Warte 4 Sekunden auf die Verarbeitung durch CrowdSec..."
sleep 4

echo
echo "[4/4] Zeige aktualisierte AppSec-Metriken..."
echo
docker exec crowdsec cscli metrics

echo
echo "=============================================="
echo "Test beendet!"
echo "Bei erfolgreichem Blockieren sollten die AppSec-Metriken ('Processed' und 'Blocked') um bis zu 8 gestiegen sein."
echo "=============================================="
