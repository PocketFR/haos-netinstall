#!/bin/bash
# build-iso.sh — Construit un ISO live "installateur HAOS" néophyte (Debian live-build).
# Inclut : firmware reseau/Wi-Fi non-libres (sans les blobs GPU/audio), NetworkManager,
# assistant guide whiptail.
# NB: pas d'option --bootloaders / --uefi-secure-boot : elles n'existent pas dans
#     toutes les versions de live-build (echec sur Ubuntu). Inutiles de toute facon,
#     le defaut produit deja une ESP avec /EFI/boot/bootx64.efi (verifie via fdisk).
# Prérequis (Debian/Ubuntu, en root) : apt install live-build
# Lancer depuis un dossier contenant haos-installer.sh :  sudo ./build-iso.sh
set -euo pipefail

WORK="haos-installer-iso"
[[ -f haos-installer.sh ]] || { echo "haos-installer.sh manquant dans le dossier courant"; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Lance en root (live-build l'exige)."; exit 1; }

SRC="$(pwd)/haos-installer.sh"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"

lb config \
  --distribution trixie \
  --architecture amd64 \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free non-free-firmware" \
  --firmware-chroot false \
  --debian-installer none \
  --memtest none \
  --iso-volume "HAOS Installer" \
  --bootappend-live "boot=live components quiet toram locales=fr_FR.UTF-8 keyboard-layouts=fr timezone=Europe/Paris"

# --- Paquets : firmware reseau + outils de l'assistant (voir liste) ---
mkdir -p config/package-lists
cat > config/package-lists/haos.list.chroot <<'EOF'
# --- Firmware reseau uniquement ---
# NB: firmware-realtek fournit AUSSI les blobs Ethernet Gigabit (rtl_nic/rtl8168*)
#     omnipresents sur les PC bon marche et thin clients -> indispensable.
firmware-realtek
firmware-iwlwifi
firmware-atheros
firmware-brcm80211
# Retires volontairement (installeur en mode texte, aucun besoin GPU/audio/TV) :
#   firmware-linux, firmware-linux-nonfree, firmware-misc-nonfree
# --- Outils ---
network-manager
wpasupplicant
iw
console-setup
kbd
whiptail
pv
curl
xz-utils
util-linux
efibootmgr
EOF
# --- Assistant guidé ---
mkdir -p config/includes.chroot/usr/local/bin
cp "$SRC" config/includes.chroot/usr/local/bin/haos-installer.sh

# --- NetworkManager gère toutes les interfaces (sinon conflit avec live-config) ---
mkdir -p config/includes.chroot/etc/NetworkManager/conf.d
cat > config/includes.chroot/etc/NetworkManager/conf.d/10-live.conf <<'EOF'
[main]
plugins=keyfile
[keyfile]
unmanaged-devices=none
EOF

# --- Service : lance l'assistant au boot, plein écran sur tty1 ---
mkdir -p config/includes.chroot/etc/systemd/system
cat > config/includes.chroot/etc/systemd/system/haos-installer.service <<'EOF'
[Unit]
Description=Home Assistant OS guided installer
After=NetworkManager.service systemd-user-sessions.service
Wants=NetworkManager.service
Conflicts=getty@tty1.service
Before=getty@tty1.service

[Service]
Type=idle
Environment=TERM=linux
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
ExecStart=/usr/local/bin/haos-installer.sh
TimeoutStartSec=0
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# --- Hook : exécutable + activation services ---
mkdir -p config/hooks/live
cat > config/hooks/live/9000-haos.hook.chroot <<'EOF'
#!/bin/sh
set -e
chmod +x /usr/local/bin/haos-installer.sh
systemctl enable NetworkManager.service
systemctl enable haos-installer.service
systemctl set-default multi-user.target
EOF
chmod +x config/hooks/live/9000-haos.hook.chroot

echo ">>> Build (accès aux miroirs Debian requis)..."
lb build

ISO=$(ls -1 live-image-*.iso 2>/dev/null | head -1)
if [ -n "$ISO" ]; then
  echo ">>> ISO : $ISO  ($(du -h "$ISO" | cut -f1))"
else
  echo ">>> ISO : échec"; exit 1
fi
