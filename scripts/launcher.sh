#!/usr/bin/env bash
URL=$(zenity --entry --title="All-in-One Web Scanner" --text="Target URL or domain (only scan sites you're authorized to test):" --width=420)
[ -z "$URL" ] && exit 0
xfce4-terminal --title="Scanning $URL" --hold -e "bash -lc 'bash \$HOME/.local/bin/allscan.sh \"$URL\"'"
