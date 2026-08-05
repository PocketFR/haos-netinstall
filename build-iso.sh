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

# L'amorcage BIOS ne vient aujourd'hui que du DEFAUT de live-build (syslinux) :
# rien ne le fige, une evolution amont pourrait le retirer sans erreur. On le
# demande donc explicitement -- mais seulement si l'option existe, car elle est
# absente de certaines versions (cf. la note en tete de fichier : echec Ubuntu).
BOOTLOADERS_OPT=()
if lb config --help 2>&1 | grep -q -- '--bootloaders'; then
  BOOTLOADERS_OPT=(--bootloaders syslinux,grub-efi)
  echo ">>> --bootloaders supporte : amorcage BIOS+UEFI fige explicitement."
else
  echo ">>> --bootloaders absent de cette version de live-build : defaut conserve."
fi

# --iso-volume : le LABEL "HAOS Installer" est PARTAGE avec haos-installer.sh
# (constante ISO_LABEL). L'installateur s'en sert pour reconnaitre le media de
# boot et l'exclure des disques cibles -- 'toram' remplacant /run/live/medium par
# un tmpfs, c'est le seul moyen fiable de l'identifier. Garder les deux en phase.
lb config \
  ${BOOTLOADERS_OPT[@]+"${BOOTLOADERS_OPT[@]}"} \
  --distribution trixie \
  --architecture amd64 \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free non-free-firmware" \
  --firmware-chroot false \
  --debian-installer none \
  --memtest none \
  --iso-volume "HAOS Installer" \
  --bootappend-live "boot=live components toram locales=fr_FR.UTF-8 keyboard-layouts=fr timezone=Europe/Paris"

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
rfkill
wpasupplicant
iw
console-setup
kbd
whiptail
pv
curl
# jq : lecture du canal stable (version.home-assistant.io/stable.json), ou la
# cle de la carte apparait sous deux sections -> un grep renverrait la mauvaise.
jq
xz-utils
util-linux
efibootmgr
mokutil
dosfstools
parted
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

# --- Timeout des menus de boot ---
# Mecanisme officiel live-build : tout repertoire present dans config/bootloaders/
# remplace le modele de /usr/share/live/build/bootloaders/.
#   - isolinux/syslinux : "timeout 0" signifie ATTENDRE INDEFINIMENT (piege classique),
#     l'unite est le 1/10 s -> 10 = 1 seconde.
#   - grub : les modeles ne definissent aucun timeout -> GRUB attend indefiniment.
#     Sur certains ecrans (vieux portables) le menu ne s'affiche meme pas : ecran noir
#     et l'utilisateur doit appuyer sur Entree a l'aveugle. D'ou timeout_style=hidden.
# NB: lb config cree deja un config/bootloaders/ VIDE. Un "cp -r src dst" y creerait
#     dst/bootloaders/ au lieu de le remplir -> on copie le CONTENU (src/.).
mkdir -p config/bootloaders
cp -r /usr/share/live/build/bootloaders/. config/bootloaders/

for f in config/bootloaders/isolinux/isolinux.cfg \
         config/bootloaders/syslinux/syslinux.cfg \
         config/bootloaders/extlinux/extlinux.conf; do
  [ -f "$f" ] && sed -i 's/^timeout 0$/timeout 10/' "$f"
done

# GRUB : injecter le timeout dans chaque .cfg du modele
for f in config/bootloaders/grub-pc/*.cfg config/bootloaders/grub-efi/*.cfg; do
  [ -f "$f" ] || continue
  grep -q '^set timeout=' "$f" \
    && sed -i 's/^set timeout=.*/set timeout=1/' "$f" \
    || sed -i '1i set timeout=1\nset timeout_style=hidden' "$f"
done

echo ">>> Timeouts appliques :"
grep -rn '^timeout \|^set timeout' config/bootloaders/ || echo "  (aucun - a verifier)"

echo ">>> Build (accès aux miroirs Debian requis)..."
lb build

ISO=$(ls -1 live-image-*.iso 2>/dev/null | head -1)
[ -n "$ISO" ] || { echo ">>> ISO : échec"; exit 1; }

# --- Partition dediee aux journaux d'installation ---
# L'ESP de l'ISO gravee ne laisse que ~4 Ko libres : trop juste pour y deposer un
# journal. On ajoute donc une 3e partition FAT16, que l'installateur retrouve par
# son LABEL -> destination deterministe, sans heuristique RM/HOTPLUG qui pourrait
# selectionner un disque interne.
# LABEL en majuscules sans espace : 11 octets max en FAT et casse traitee
# inegalement selon les outils, or on le compare par programme.
# FAT16 et non FAT32 : ce dernier est mal a l'aise sous 32 Mo.
# xorriso et non "cat + sfdisk" : ajouter des donnees en fin d'image deplace la
# GPT de secours, dont xorriso tient la comptabilite a jour.
# NB: sous Ventoy (ISO monte en boucle) et Rufus en mode ISO, cette partition
#     n'apparaitra pas -> l'installateur garde ses replis.
LOGS_LABEL="HAOS_LOGS"
if command -v mkfs.vfat >/dev/null && command -v xorriso >/dev/null; then
  echo ">>> Ajout de la partition $LOGS_LABEL..."
  rm -f haos-logs.img
  truncate -s 16M haos-logs.img
  mkfs.vfat -F 16 -n "$LOGS_LABEL" haos-logs.img >/dev/null

  # 0x0e = FAT16 LBA. "-boot_image any replay" rejoue la configuration d'amorcage
  # de l'ISO source : sans lui, l'image de sortie ne serait plus amorcable.
  # Sortie capturee (et non tubee vers tail) : un tube ferait porter le statut du
  # 'if' sur tail et non sur xorriso.
  xorriso_out=""
  if xorriso_out=$(xorriso -indev "$ISO" -outdev "$ISO.new" \
       -boot_image any replay \
       -append_partition 3 0x0e haos-logs.img 2>&1); then
    mv -f "$ISO.new" "$ISO"
    echo ">>> Partition $LOGS_LABEL ajoutee."
  else
    rm -f "$ISO.new"
    echo ">>> ATTENTION: ajout de $LOGS_LABEL echoue, ISO conservee sans elle."
    echo "$xorriso_out" | tail -10
  fi
  rm -f haos-logs.img
else
  echo ">>> ATTENTION: mkfs.vfat ou xorriso absent -> pas de partition $LOGS_LABEL."
fi

echo ">>> ISO : $ISO  ($(du -h "$ISO" | cut -f1))"
echo ">>> Partitions :"
fdisk -l "$ISO" 2>/dev/null | tail -6 || true
