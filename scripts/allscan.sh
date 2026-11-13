#!/usr/bin/env bash
# One tool to run them all: nmap, whatweb, wafw00f, sslscan/testssl, nikto,
# subfinder+httpx, katana, ffuf, nuclei, wapiti -> one combined HTML report.
set -u
TARGET="${1:-}"
if [ -z "$TARGET" ]; then echo "usage: allscan <url-or-domain>"; exit 1; fi
case "$TARGET" in http*://*) URL="$TARGET"; HOST=$(echo "$TARGET" | sed -E 's#^[a-z]+://##; s#/.*##; s#:.*##') ;;
  *) HOST="$TARGET"; URL="https://$TARGET" ;; esac

TS=$(date +%Y%m%d-%H%M%S)
OUT="$HOME/Desktop/scan-reports/${HOST}-${TS}"
mkdir -p "$OUT"
echo "[*] Target: $URL  ($HOST)"
echo "[*] Report folder: $OUT"
echo "[*] Only scan targets you own or are authorized to test."

run(){ # run <name> <command...>
  name="$1"; shift
  echo "=== $name ==="
  { timeout 240 "$@" ; } > "$OUT/$name.log" 2>&1
  echo "  -> $(wc -l < "$OUT/$name.log") lines"
}

run nmap          nmap -sV -T4 --top-ports 200 "$HOST"
run whatweb       whatweb -a 3 "$URL"
run wafw00f       wafw00f "$URL"
run sslscan       sslscan "$HOST"
run testssl        testssl --fast "$URL"
run nikto         nikto -h "$URL"
run nuclei        nuclei -u "$URL" -silent -severity low,medium,high,critical
run subfinder     subfinder -d "$HOST" -silent
cp "$OUT/subfinder.log" /tmp/subs.$$ 2>/dev/null
run httpx         sh -c "cat /tmp/subs.$$ 2>/dev/null | httpx -silent"
rm -f /tmp/subs.$$
run katana        katana -u "$URL" -silent -depth 2
run ffuf          ffuf -u "$URL/FUZZ" -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302,403 -of json -o "$OUT/ffuf.json"
run wapiti        wapiti -u "$URL" --flush-session

# combine into one HTML report
python3 - "$OUT" "$URL" <<'PY'
import sys, html, pathlib, datetime
out, url = sys.argv[1], sys.argv[2]
p = pathlib.Path(out)
parts = [f"<html><head><meta charset='utf-8'><title>Scan report - {html.escape(url)}</title>",
"<style>body{font-family:monospace;background:#111;color:#ddd;padding:20px}h2{color:#4fc3f7;border-bottom:1px solid #333;margin-top:30px}pre{background:#1c1c1c;padding:10px;overflow:auto;white-space:pre-wrap}</style></head><body>",
f"<h1>Scan report: {html.escape(url)}</h1><p>{datetime.datetime.utcnow().isoformat()}Z</p>"]
for f in sorted(p.glob('*.log')):
    if f.name == 'report.log': continue
    text = f.read_text(errors='replace').strip() or '(no output / tool missing)'
    parts.append(f"<h2>{html.escape(f.stem)}</h2><pre>{html.escape(text[:20000])}</pre>")
ffuf_json = p / 'ffuf.json'
if ffuf_json.exists():
    parts.append(f"<h2>ffuf</h2><pre>{html.escape(ffuf_json.read_text(errors='replace')[:20000])}</pre>")
parts.append("</body></html>")
(p / "report.html").write_text("\n".join(parts))
print(p / "report.html")
PY
echo "[*] Done. Report: $OUT/report.html"
( firefox --new-window "file://$OUT/report.html" >/dev/null 2>&1 & ) || xdg-open "$OUT/report.html" >/dev/null 2>&1 &
