#!/usr/bin/env bash
set -u
export DISPLAY=:99
log(){ echo "[$(date -u +%T)] $*"; }

Xvfb :99 -screen 0 1366x768x24 -ac >xvfb.log 2>&1 &
sleep 2
dbus-launch --exit-with-session startxfce4 >xfce.log 2>&1 &
sleep 6
x11vnc -display :99 -passwd "$VNC_PASSWORD" -forever -shared -rfbport 5900 -noxdamage -bg -o x11vnc.log
websockify --web /usr/share/novnc 6080 localhost:5900 >ws.log 2>&1 &
sleep 2
discord --no-sandbox --disable-gpu >discord.log 2>&1 &
sleep 3
log "desktop up: Xvfb=$(pgrep -c Xvfb) xfce=$(pgrep -c xfce4-session) discord=$(pgrep -fc /usr/share/discord)"

start_tunnel(){
  pkill cloudflared 2>/dev/null || true
  : > cf.log
  ./cloudflared tunnel --url http://localhost:6080 --no-autoupdate >cf.log 2>&1 &
  URL=""
  for i in $(seq 1 40); do
    URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' cf.log | head -1)
    [ -n "$URL" ] && break
    sleep 2
  done
  if [ -z "$URL" ]; then log "no tunnel url yet"; return 1; fi
  LINK="$URL/vnc.html?autoconnect=true&resize=scale"
  log "LINK $LINK"
  echo "::notice title=Desktop link::$LINK"
  printf '### Linux Desktop link\n\n%s\n' "$LINK" >> "$GITHUB_STEP_SUMMARY"
  printf '**Link:** %s\n\nPassword = VNC_PASSWORD secret. Started: %s UTC. Restarts itself before the 6h limit.\n' "$LINK" "$(date -u '+%F %T')" > issue.md
  gh issue edit "$ISSUE" --repo "$GITHUB_REPOSITORY" --body-file issue.md || log "issue update failed"
}
start_tunnel

DISPATCH=$((START + 330*60)); END=$((START + 350*60)); SENT=0
while [ "$(date +%s)" -lt "$END" ]; do
  now=$(date +%s)
  if [ "$SENT" = 0 ] && [ "$now" -ge "$DISPATCH" ]; then
    gh workflow run desktop.yml --repo "$GITHUB_REPOSITORY" && SENT=1
  fi
  pgrep Xvfb >/dev/null || { log "Xvfb died"; break; }
  pgrep -f "cloudflared tunnel" >/dev/null || { log "tunnel died, restarting"; start_tunnel; }
  sleep 20
done
if [ "$SENT" = 0 ] && [ "$(date +%s)" -ge $((START + 300*60)) ]; then
  gh workflow run desktop.yml --repo "$GITHUB_REPOSITORY"
fi
log "loop ended"
