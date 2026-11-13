#!/usr/bin/env bash
# Web/security scanners. Each install is best-effort so one failure never blocks the desktop.
set -u
log(){ echo "[tools] $*"; }
sudo apt-get update -y >/dev/null 2>&1
for p in nmap nikto whatweb sqlmap sslscan dirb gobuster ffuf wafw00f wapiti dnsutils whois jq unzip git curl python3-pip openjdk-17-jre ruby ruby-dev build-essential libcurl4-openssl-dev libxml2-dev libxslt1-dev zlib1g-dev; do
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 && log "apt ok: $p" || log "apt SKIP: $p"
done

# ProjectDiscovery: nuclei (template-based vuln scanner), httpx, subfinder, katana
for t in nuclei httpx subfinder katana; do
  url=$(curl -fsSL -H "Authorization: Bearer ${GH_TOKEN:-}" "https://api.github.com/repos/projectdiscovery/$t/releases/latest" | jq -r '.assets[].browser_download_url | select(test("linux_amd64\\.zip$"))' | head -1)
  if [ -n "$url" ] && curl -fsSL "$url" -o "/tmp/$t.zip" && sudo unzip -oq "/tmp/$t.zip" "$t" -d /usr/local/bin; then
    sudo chmod +x "/usr/local/bin/$t"; log "ok: $t"
  else log "SKIP: $t"; fi
done
nuclei -update-templates >/dev/null 2>&1 && log "nuclei templates updated" || log "nuclei templates SKIP"

# OWASP ZAP (GUI + CLI)
zurl=$(curl -fsSL -H "Authorization: Bearer ${GH_TOKEN:-}" https://api.github.com/repos/zaproxy/zaproxy/releases/latest | jq -r '.assets[].browser_download_url | select(test("Linux\\.tar\\.gz$"))' | head -1)
if [ -n "$zurl" ] && curl -fsSL "$zurl" -o /tmp/zap.tgz; then
  sudo mkdir -p /opt/zap && sudo tar xzf /tmp/zap.tgz -C /opt/zap --strip-components=1 && sudo ln -sf /opt/zap/zap.sh /usr/local/bin/zap && log "ok: zap"
else log "SKIP: zap"; fi

# testssl.sh
sudo git clone -q --depth 1 https://github.com/drwetter/testssl.sh /opt/testssl && sudo ln -sf /opt/testssl/testssl.sh /usr/local/bin/testssl && log "ok: testssl" || log "SKIP: testssl"

# WPScan
sudo gem install wpscan --no-document >/dev/null 2>&1 && log "ok: wpscan" || log "SKIP: wpscan"

# Desktop notes + ZAP launcher
mkdir -p "$HOME/Desktop"
cat > "$HOME/Desktop/SCAN-TOOLS.txt" <<'TXT'
Open Terminal and use:
  nmap -sV -sC target          ports + services + default scripts
  nikto -h https://target      web server misconfig/known issues
  nuclei -u https://target     template-based vuln scanner
  whatweb target               tech fingerprint
  wafw00f https://target       detect WAF
  sslscan target / testssl target   TLS checks
  ffuf / gobuster / dirb       directory + file discovery
  subfinder -d domain | httpx  subdomains -> live hosts
  katana -u https://target     crawler
  wapiti -u https://target     web app scanner
  wpscan --url https://target  WordPress
  sqlmap -u "URL?id=1" --batch SQL injection testing
  zap                          OWASP ZAP (GUI)
Only scan systems you own or have written permission to test.
TXT
printf '[Desktop Entry]\nType=Application\nName=OWASP ZAP\nExec=/usr/local/bin/zap\nTerminal=false\n' > "$HOME/Desktop/ZAP.desktop"; chmod +x "$HOME/Desktop/ZAP.desktop"
log "done"
