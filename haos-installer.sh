#!/bin/bash
# haos-installer.sh — Assistant guidé d'installation de Home Assistant OS (bare-metal).
# Guided Home Assistant OS installer (bare metal).
#
# Ecrans whiptail, Wi-Fi assiste, choix du disque, verification par relecture.
# Lance au boot d'un live Debian. Bilingue FR/EN (choix au premier ecran).
set -uo pipefail          # pas de -e : on gere les erreurs pour garder l'assistant vivant
export NEWT_COLORS='root=,blue; window=,lightgray; border=blue,lightgray; title=blue,'

# Le noyau ecrit ses messages directement sur la console (pas de 'quiet' au boot,
# volontairement). Pendant le TUI ils parasitent les fenetres -> urgences seulement.
quiet_console(){ dmesg -n 1 2>/dev/null || echo 1 > /proc/sys/kernel/printk 2>/dev/null || true; }
loud_console(){  dmesg -n 7 2>/dev/null || echo 7 > /proc/sys/kernel/printk 2>/dev/null || true; }
quiet_console
trap loud_console EXIT

UI_LANG="fr"
LOG=/tmp/haos-install.log
: > "$LOG"

# ---------------------------------------------------------------------------
# Chaines. Les variables sont injectees via printf (%s) : pas d'interpolation
# a la definition, sinon $TARGET & co seraient vides a ce stade.
# ---------------------------------------------------------------------------
set_strings(){
if [ "$UI_LANG" = "fr" ]; then
  S_TITLE="Installation Home Assistant OS"
  S_WARN="⚠  AVERTISSEMENT — Installation Home Assistant OS"
  S_RESCUE="\n\nUn terminal de secours va s'ouvrir."
  S_CANCELLED="Installation annulée."
  S_OK_UEFI="OK (UEFI)"
  S_BAD_UEFI="À VÉRIFIER (mode Legacy/CSM détecté)"
  S_SB_OFF="OK (désactivé)"
  S_SB_ON="À VÉRIFIER (activé — HAOS ne démarrera pas)"
  S_SB_UNK="À VÉRIFIER (état indéterminé)"
  S_WELCOME="Bienvenue.\n\nCet outil installe la dernière version de Home Assistant OS\nsur ce PC, sans ligne de commande.\n\nÉTAT DES PRÉREQUIS :\n  Démarrage   : %s\n  Secure Boot : %s\n\nUn « À VÉRIFIER » signifie que Home Assistant risque de ne\npas démarrer après l'installation. Cela se corrige dans le\nBIOS (touche Suppr/F2 au démarrage). Rien n'est bloqué :\ntu peux continuer quand même.\n\nÀ l'étape du disque, TOUT le disque choisi sera effacé."
  S_NET_ETH="Recherche d'une connexion filaire (Ethernet)..."
  S_NET_NOWIFI="Aucune carte Wi-Fi utilisable détectée.\n\n%s\n\nBranche un câble Ethernet, ou choisis la configuration\nmanuelle à l'écran suivant."
  S_NET_SCAN="Recherche des réseaux Wi-Fi..."
  S_NET_PICK="Sélectionne ton réseau Wi-Fi :"
  S_NET_RESCAN="[ Relancer le scan ]"
  S_NET_RESCAN_D="aucun réseau trouvé ? réessayer"
  S_NET_MANUAL="[ Configuration manuelle ]"
  S_NET_MANUAL_D="SSID caché, WPA entreprise, IP fixe (nmtui)"
  S_NET_ETHRETRY="[ Réessayer l'Ethernet ]"
  S_NET_ETHRETRY_D="câble branché entre-temps"
  S_NET_QUIT="Quitter l'installateur ?\n\nAucun réseau n'est configuré : l'installation ne peut pas\ncontinuer sans accès à Internet."
  S_NET_PSK="Mot de passe du réseau « %s » :\n(affiché en clair pour éviter les fautes de frappe)"
  S_NET_CONN="Connexion à « %s »..."
  S_NET_FAIL="Échec de connexion à « %s ».\n\n%s\n\nVérifie le mot de passe, ou utilise la configuration manuelle."
  S_VER_FETCH="Recherche de la dernière version de Home Assistant OS..."
  S_VER_FAIL="Impossible de contacter GitHub pour connaître la dernière\nversion.\n\nVersion de repli proposée : %s\n(elle peut être ancienne — Home Assistant se mettra à jour\nlui-même après l'installation)\n\nContinuer avec cette version ?"
  S_VER_NOIMG="Image introuvable pour la version %s :\n%s"
  S_DISK_NONE="Aucun disque interne détecté."
  S_DISK_PICK="Sur quel disque installer Home Assistant OS ?\nTOUT son contenu sera définitivement effacé.\n\nLes disques marqués [!! USB / EXTERNE !!] sont amovibles :\nc'est probablement un disque de sauvegarde, pas la cible."
  S_DISK_SMALL="Le disque %s fait %s Go.\n\nHome Assistant demande 32 Go minimum. L'écriture risque\nd'échouer, ou de laisser trop peu de place à l'usage.\n\nRien n'a encore été effacé."
  S_DISK_CONFIRM="Le disque %s va être ENTIÈREMENT EFFACÉ.\n\nContenu actuel détecté :\n%s\n\nConfirmer l'effacement et l'installation ?"
  S_CONFIRM_T="⚠  DERNIÈRE CONFIRMATION"
  S_STOP="Arrêter (recommandé)"
  S_GOON="Continuer quand même"
  S_STOPPED="Arrêté avant toute modification."
  S_PREP="Préparation du disque %s..."
  S_WRITING="Téléchargement et écriture de HAOS %s.\nNe pas éteindre le PC."
  S_FAIL="Échec de l'installation (code %s).\n\nDétail :\n%s\n\nJournal complet : %s"
  S_VFY_ASK="Vérifier que le disque a été écrit correctement ?\n\nRelecture de %s depuis %s.\nDurée : 1 à 3 minutes selon le disque.\n\nRecommandé, surtout sur un disque ancien."
  S_VFY_RUN="Relecture et vérification du disque..."
  S_VFY_OK="Vérification réussie.\n\nLe contenu du disque correspond exactement à l'image.\n\nSHA256 : %s..."
  S_VFY_KO="ÉCHEC DE LA VÉRIFICATION\n\nLe disque ne correspond pas à l'image écrite :\n  attendu : %s...\n  lu      : %s...\n\nCauses possibles : disque défaillant, câble SATA, mémoire.\nNE PAS utiliser cette installation : recommence, et si\nl'erreur persiste, change de disque."
  S_VFY_SKIP="Empreinte de l'image non calculée : vérification impossible.\nL'installation est probablement correcte (le téléchargement\nest validé par le format compressé)."
  S_LOG_ASK="Copier le journal d'installation sur une clé USB ?\n\nIl sera perdu au redémarrage sinon. C'est le fichier à\njoindre pour signaler le problème."
  S_LOG_OK="Journal copié sur %s\n(fichier haos-install-*.log)\n\nTu peux retirer la clé."
  S_LOG_PLUG="Aucun support inscriptible détecté.\n\nBranche une clé USB (FAT32, exFAT ou ext4), attends 5\nsecondes, puis valide.\n\nSeul le journal y sera ajouté : rien d'autre n'est modifié."
  S_LOG_PLUGGED="J'ai branché la clé"
  S_LOG_ABORT="Abandonner"
  S_LOG_DETECT="Détection du support..."
  S_LOG_RETRY="Toujours rien d'inscriptible.\n\nLa clé n'est peut-être pas partitionnée, ou son format\nn'est pas reconnu. Tu peux réessayer avec une autre clé."
  S_LOG_NONE="Journal non copié.\n\nIl reste consultable dans le terminal :\n  cat %s"
  S_WIFI_PUSH="Réseau Wi-Fi « %s » pré-configuré : Home Assistant s'y\nconnectera automatiquement au premier démarrage.\n\nGarde ce PC à portée du Wi-Fi."
  S_WIFI_PUSH_FAIL="Le Wi-Fi n'a pas pu être pré-configuré dans l'image.\n\nHome Assistant démarrera sans réseau : il faudra le\nconnecter ensuite (câble Ethernet, ou clavier+écran sur\nla console HAOS)."
  S_DONE="Installation terminée.\n\nHome Assistant OS est installé sur %s.\n\nÀ SUIVRE, DANS CET ORDRE :\n 1. Valide ci-dessous : le PC redémarre.\n 2. Retire la clé USB DÈS QUE L'ÉCRAN S'ÉTEINT.\n    (ne la retire pas maintenant)\n 3. Garde le câble réseau branché.\n 4. Patiente 2 à 5 minutes (premier démarrage).\n 5. Depuis un autre appareil :  http://homeassistant.local:8123"
else
  S_TITLE="Home Assistant OS installation"
  S_WARN="⚠  WARNING — Home Assistant OS installation"
  S_RESCUE="\n\nA rescue shell will open."
  S_CANCELLED="Installation cancelled."
  S_OK_UEFI="OK (UEFI)"
  S_BAD_UEFI="CHECK THIS (Legacy/CSM mode detected)"
  S_SB_OFF="OK (disabled)"
  S_SB_ON="CHECK THIS (enabled — HAOS will not boot)"
  S_SB_UNK="CHECK THIS (state unknown)"
  S_WELCOME="Welcome.\n\nThis tool installs the latest Home Assistant OS on this PC,\nwith no command line involved.\n\nREQUIREMENTS CHECK:\n  Boot mode   : %s\n  Secure Boot : %s\n\n\"CHECK THIS\" means Home Assistant may not boot after the\ninstall. Fix it in the BIOS (Del/F2 at power-on). Nothing\nis blocked: you may continue anyway.\n\nAt the disk step, the WHOLE disk you pick will be erased."
  S_NET_ETH="Looking for a wired (Ethernet) connection..."
  S_NET_NOWIFI="No usable Wi-Fi adapter detected.\n\n%s\n\nPlug in an Ethernet cable, or use manual configuration on\nthe next screen."
  S_NET_SCAN="Scanning for Wi-Fi networks..."
  S_NET_PICK="Select your Wi-Fi network:"
  S_NET_RESCAN="[ Scan again ]"
  S_NET_RESCAN_D="no network found? retry"
  S_NET_MANUAL="[ Manual configuration ]"
  S_NET_MANUAL_D="hidden SSID, WPA enterprise, static IP (nmtui)"
  S_NET_ETHRETRY="[ Retry Ethernet ]"
  S_NET_ETHRETRY_D="cable plugged in meanwhile"
  S_NET_QUIT="Quit the installer?\n\nNo network is configured: the installation cannot continue\nwithout Internet access."
  S_NET_PSK="Password for network \"%s\":\n(shown in clear text to avoid typos)"
  S_NET_CONN="Connecting to \"%s\"..."
  S_NET_FAIL="Failed to connect to \"%s\".\n\n%s\n\nCheck the password, or use manual configuration."
  S_VER_FETCH="Looking up the latest Home Assistant OS version..."
  S_VER_FAIL="Could not reach GitHub to determine the latest version.\n\nFallback version: %s\n(it may be old — Home Assistant will update itself after\nthe install)\n\nContinue with this version?"
  S_VER_NOIMG="No image found for version %s:\n%s"
  S_DISK_NONE="No internal disk detected."
  S_DISK_PICK="Which disk should Home Assistant OS be installed on?\nALL of its contents will be permanently erased.\n\nDisks marked [!! USB / EXTERNAL !!] are removable: that is\nprobably a backup drive, not your target."
  S_DISK_SMALL="Disk %s is %s GB.\n\nHome Assistant needs 32 GB minimum. Writing may fail, or\nleave too little room to be usable.\n\nNothing has been erased yet."
  S_DISK_CONFIRM="Disk %s will be COMPLETELY ERASED.\n\nCurrent contents detected:\n%s\n\nConfirm erase and install?"
  S_CONFIRM_T="⚠  FINAL CONFIRMATION"
  S_STOP="Stop (recommended)"
  S_GOON="Continue anyway"
  S_STOPPED="Stopped before any change."
  S_PREP="Preparing disk %s..."
  S_WRITING="Downloading and writing HAOS %s.\nDo not power off the PC."
  S_FAIL="Installation failed (code %s).\n\nDetails:\n%s\n\nFull log: %s"
  S_VFY_ASK="Verify that the disk was written correctly?\n\nReads back %s from %s.\nTakes 1 to 3 minutes depending on the disk.\n\nRecommended, especially on an older disk."
  S_VFY_RUN="Reading back and verifying the disk..."
  S_VFY_OK="Verification passed.\n\nThe disk contents match the image exactly.\n\nSHA256: %s..."
  S_VFY_KO="VERIFICATION FAILED\n\nThe disk does not match the image written:\n  expected: %s...\n  read    : %s...\n\nLikely causes: failing disk, SATA cable, memory.\nDO NOT use this installation: try again, and if the error\npersists, replace the disk."
  S_VFY_SKIP="Image checksum was not computed: cannot verify.\nThe installation is most likely fine (the download is\nvalidated by the compressed format itself)."
  S_LOG_ASK="Copy the installation log to a USB stick?\n\nIt will be lost on reboot otherwise. This is the file to\nattach when reporting the problem."
  S_LOG_OK="Log copied to %s\n(file haos-install-*.log)\n\nYou can remove the stick."
  S_LOG_PLUG="No writable media detected.\n\nPlug in a USB stick (FAT32, exFAT or ext4), wait 5 seconds,\nthen confirm.\n\nOnly the log will be added: nothing else is modified."
  S_LOG_PLUGGED="I plugged it in"
  S_LOG_ABORT="Give up"
  S_LOG_DETECT="Detecting media..."
  S_LOG_RETRY="Still nothing writable.\n\nThe stick may be unpartitioned, or its format is not\nrecognised. You can try another one."
  S_LOG_NONE="Log not copied.\n\nIt is still readable from the shell:\n  cat %s"
  S_WIFI_PUSH="Wi-Fi network \"%s\" pre-configured: Home Assistant will\nconnect to it automatically on first boot.\n\nKeep this PC within Wi-Fi range."
  S_WIFI_PUSH_FAIL="Wi-Fi could not be pre-configured into the image.\n\nHome Assistant will boot with no network: you will have to\nconnect it afterwards (Ethernet cable, or keyboard+screen\non the HAOS console)."
  S_DONE="Installation complete.\n\nHome Assistant OS is installed on %s.\n\nNEXT, IN THIS ORDER:\n 1. Confirm below: the PC reboots.\n 2. Remove the USB stick AS SOON AS THE SCREEN GOES BLANK.\n    (do not remove it now)\n 3. Keep the network cable plugged in.\n 4. Wait 2 to 5 minutes (first boot).\n 5. From another device:  http://homeassistant.local:8123"
fi
}

die(){ whiptail --title "$S_TITLE" --msgbox "$1$S_RESCUE" 12 72; save_log; loud_console; clear; exec bash; }

# ---------------------------------------------------------------------------
# ECRAN 1 : langue + clavier en une question.
# La disposition n'implique PAS la langue (un francophone peut etre en QWERTY US)
# -> chaque ligne annonce explicitement les deux, aucune deduction.
# Applique la disposition. NB: deux mondes de noms coexistent —
#   - console-setup / setupcon : noms X11 (fr, be, ch+variante fr, ca, us, gb, de)
#   - loadkeys : noms de keymaps console (fr-latin9, cf, fr_CH, uk...)
# console-setup est installe et fait autorite via /etc/default/keyboard : c'est lui
# qu'il faut piloter, sinon il reapplique sa conf par-dessus loadkeys.
apply_keymap(){
  local layout="$1" variant="${2:-}" out=""

  if [ -w /etc/default/keyboard ] && command -v setupcon >/dev/null 2>&1; then
    sed -i -e "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$layout\"/" \
           -e "s/^XKBVARIANT=.*/XKBVARIANT=\"$variant\"/" /etc/default/keyboard 2>>"$LOG"
    grep -q '^XKBLAYOUT=' /etc/default/keyboard || echo "XKBLAYOUT=\"$layout\"" >> /etc/default/keyboard
    grep -q '^XKBVARIANT=' /etc/default/keyboard || echo "XKBVARIANT=\"$variant\"" >> /etc/default/keyboard
    out=$(setupcon --force 2>&1) && return 0
  fi

  # Repli loadkeys, avec traduction vers les noms de keymaps console
  local km="$layout"
  case "$layout:$variant" in
    fr:)     km="fr-latin9" ;;
    be:)     km="be-latin1" ;;
    ch:fr)   km="fr_CH-latin1" ;;
    ca:*)    km="cf" ;;
    gb:)     km="uk" ;;
    de:)     km="de-latin1" ;;
  esac
  out="$out"$'\n'"$(loadkeys "$km" 2>&1)" && return 0

  # Ne plus echouer en silence : c'est ce qui a masque le bug precedent.
  whiptail --title "$S_TITLE" --msgbox \
    "Keyboard layout could not be applied / La disposition n'a pas pu être appliquée :\n\n$(echo "$out" | cut -c1-64 | head -6)\n\nQWERTY/AZERTY may be wrong. Use the manual config if needed." 15 72
  return 1
}

# ---------------------------------------------------------------------------
# ECRAN 1 : langue + clavier en une question.
# La disposition n'implique PAS la langue (un francophone peut etre en QWERTY US)
# -> chaque ligne annonce explicitement les deux, aucune deduction.
choose_lang_keyboard(){
  local sel
  sel=$(whiptail --title "Language & keyboard / Langue et clavier" --menu \
    "Choose language and keyboard layout\nChoisissez la langue et la disposition du clavier" \
    18 66 8 \
    "fr|fr|"    "Français  |  AZERTY   (France)" \
    "fr|be|"    "Français  |  AZERTY   (Belgique)" \
    "fr|ch|fr"  "Français  |  QWERTZ   (Suisse)" \
    "fr|ca|"    "Français  |  QWERTY   (Canada)" \
    "fr|us|"    "Français  |  QWERTY   (US)" \
    "en|us|"    "English   |  QWERTY   (US)" \
    "en|gb|"    "English   |  QWERTY   (UK)" \
    "en|de|"    "English   |  QWERTZ   (DE)" \
    3>&1 1>&2 2>&3) || sel="fr|fr|"

  UI_LANG="${sel%%|*}"
  local rest="${sel#*|}"
  apply_keymap "${rest%%|*}" "${rest#*|}"
  set_strings
}

have_net(){ curl -fsI --max-time 5 https://github.com >/dev/null 2>&1; }

boot_status(){ [ -d /sys/firmware/efi ] && echo "$S_OK_UEFI" || echo "$S_BAD_UEFI"; }

secureboot_status(){
  # mokutil gere les cas tordus (efivarfs absent, GUID multiples).
  # Repli : lecture brute de l'efivar (4 octets d'attributs, puis la valeur).
  local out sb f
  if command -v mokutil >/dev/null 2>&1; then
    out=$(mokutil --sb-state 2>/dev/null)
    case "$out" in
      *disabled*|*désactivé*) echo "$S_SB_OFF"; return ;;
      *enabled*)              echo "$S_SB_ON";  return ;;
    esac
  fi
  for f in /sys/firmware/efi/efivars/SecureBoot-*; do
    [ -e "$f" ] || continue
    sb=$(od -An -t u1 -j4 -N1 "$f" 2>/dev/null | tr -d ' '); break
  done
  case "${sb:-}" in
    0) echo "$S_SB_OFF" ;;
    1) echo "$S_SB_ON" ;;
    *) echo "$S_SB_UNK" ;;
  esac
}

# ---------------------------------------------------------------------------
# Journal : /tmp meurt avec le live. On NE CREE PAS de partition sur le media
# d'installation (fragile s'il est monte, casse Ventoy, impossible sur CD,
# perdu au prochain flash). Inutile : une cle gravee expose deja son ESP en FAT.
try_write_log(){
  local src="$1" part fstype dest=""
  while read -r part fstype; do
    [ -n "$part" ] || continue
    case "$fstype" in iso9660|udf|"") continue ;; esac    # RO par conception
    mkdir -p /mnt/logdest 2>/dev/null
    mount -o rw "/dev/$part" /mnt/logdest 2>/dev/null || continue
    cp "$src" "/mnt/logdest/haos-install-$(date +%Y%m%d-%H%M).log" 2>/dev/null \
      && { sync; dest="/dev/$part"; }
    umount /mnt/logdest 2>/dev/null || true
    [ -n "$dest" ] && { echo "$dest"; return 0; }
  done < <(lsblk -nro NAME,FSTYPE,TYPE,RM,HOTPLUG \
           | awk '$3=="part" && ($4==1 || $5==1) {print $1, $2}')
  return 1
}

save_log(){
  local dest
  [ -s "$LOG" ] || return 0
  whiptail --title "$S_TITLE" --yesno "$S_LOG_ASK" 11 68 || return 0

  if dest=$(try_write_log "$LOG"); then
    whiptail --title "$S_TITLE" --msgbox "$(printf "$S_LOG_OK" "$dest")" 10 64; return 0
  fi

  while true; do
    whiptail --title "$S_TITLE" --yesno \
      --yes-button "$S_LOG_PLUGGED" --no-button "$S_LOG_ABORT" "$S_LOG_PLUG" 13 70 || break
    whiptail --title "$S_TITLE" --infobox "$S_LOG_DETECT" 7 62
    udevadm settle 2>/dev/null || sleep 3
    partprobe 2>/dev/null || true; sleep 1
    if dest=$(try_write_log "$LOG"); then
      whiptail --title "$S_TITLE" --msgbox "$(printf "$S_LOG_OK" "$dest")" 10 64; return 0
    fi
    whiptail --title "$S_TITLE" --msgbox "$S_LOG_RETRY" 12 68
  done
  whiptail --title "$S_TITLE" --msgbox "$(printf "$S_LOG_NONE" "$LOG")" 11 66
}

# ---------------------------------------------------------------------------
# PIEGE nmcli : apres un echec, un profil nomme d'apres le SSID subsiste avec le
# mauvais mot de passe. Un nouvel appel "dev wifi connect ... password ..."
# REACTIVE ce profil et IGNORE le mot de passe fourni -> la 2e tentative echoue
# avec l'ancien. On supprime donc tout profil existant pour ce SSID.
forget_profile(){
  local ssid="$1" name
  nmcli connection delete "$ssid" >/dev/null 2>&1 || true
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null)" = "$ssid" ]; then
      nmcli connection delete "$name" >/dev/null 2>&1 || true
    fi
  done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2 ~ /wireless/ {print $1}')
}

setup_network(){
  have_net && return 0
  whiptail --title "$S_TITLE" --infobox "$S_NET_ETH" 7 62
  sleep 5; have_net && return 0

  rfkill unblock all 2>/dev/null || true
  nmcli radio wifi on 2>/dev/null || true
  sleep 2

  local wifi_if
  wifi_if=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
  if [ -z "$wifi_if" ]; then
    local diag
    diag=$( { ip -br link 2>/dev/null; nmcli dev status 2>/dev/null;
              rfkill list 2>/dev/null; dmesg 2>/dev/null | grep -i firmware | tail -4; } \
            | cut -c1-62 | head -18 )
    whiptail --title "$S_TITLE" --msgbox "$(printf "$S_NET_NOWIFI" "$diag")" 24 70
  fi

  while true; do
    whiptail --title "$S_TITLE" --infobox "$S_NET_SCAN" 7 62
    nmcli dev wifi rescan 2>/dev/null || true; sleep 3

    local menu=() ssid sig sec
    while IFS=$'\t' read -r ssid sig sec; do
      [ -n "$ssid" ] || continue
      menu+=("$ssid" "$(printf 'signal %3s%%   %s' "$sig" "${sec:-open}")")
    done < <(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
             | awk -F: 'length($1) && !seen[$1]++ {print $1"\t"$2"\t"$3}')

    menu+=("$S_NET_RESCAN" "$S_NET_RESCAN_D")
    menu+=("$S_NET_MANUAL" "$S_NET_MANUAL_D")
    menu+=("$S_NET_ETHRETRY" "$S_NET_ETHRETRY_D")

    local choice
    choice=$(whiptail --title "$S_TITLE" --menu "$S_NET_PICK" 20 74 10 "${menu[@]}" 3>&1 1>&2 2>&3) \
      || { whiptail --title "$S_TITLE" --yesno "$S_NET_QUIT" 11 66 && die "$S_CANCELLED" || continue; }

    case "$choice" in
      "$S_NET_RESCAN")    continue ;;
      "$S_NET_MANUAL")    clear; nmtui; clear; have_net && return 0 || continue ;;
      "$S_NET_ETHRETRY")  have_net && return 0 || continue ;;
    esac

    # --inputbox et non --passwordbox : saisie a l'aveugle + clavier eventuellement
    # mal mappe = trop d'echecs. La machine est en cours d'installation.
    local psk
    psk=$(whiptail --title "$S_TITLE" --inputbox "$(printf "$S_NET_PSK" "$choice")" 10 66 3>&1 1>&2 2>&3) || continue

    whiptail --title "$S_TITLE" --infobox "$(printf "$S_NET_CONN" "$choice")" 7 62
    forget_profile "$choice"
    local err
    if err=$(nmcli dev wifi connect "$choice" password "$psk" 2>&1) && have_net; then
      WIFI_SSID="$choice"          # memorise pour push_wifi_config (installation Wi-Fi)
      return 0
    fi
    whiptail --title "$S_TITLE" --msgbox \
      "$(printf "$S_NET_FAIL" "$choice" "$(echo "$err" | cut -c1-58 | head -3)")" 14 68
  done
}

# ---------------------------------------------------------------------------
# NECESSITE le reseau : en Wi-Fi, rien n'est joignable avant setup_network.
resolve_version(){
  whiptail --title "$S_TITLE" --infobox "$S_VER_FETCH" 7 66
  HAOS_VERSION=$(curl -fsSL --max-time 15 \
    https://api.github.com/repos/home-assistant/operating-system/releases/latest \
    2>>"$LOG" | grep -oP '"tag_name":\s*"\K[^"]+' || true)
  # NB: /releases/latest exclut les pre-releases (RC) par construction.

  if [ -z "$HAOS_VERSION" ]; then
    HAOS_VERSION="$HAOS_FALLBACK"
    whiptail --title "$S_TITLE" --yesno "$(printf "$S_VER_FAIL" "$HAOS_VERSION")" 15 70 \
      || die "$S_CANCELLED"
  fi

  IMG_URL="https://github.com/home-assistant/operating-system/releases/download/${HAOS_VERSION}/haos_generic-x86-64-${HAOS_VERSION}.img.xz"
  curl -fsI --max-time 15 "$IMG_URL" >/dev/null 2>>"$LOG" \
    || die "$(printf "$S_VER_NOIMG" "$HAOS_VERSION" "$IMG_URL")"
}

# ---------------------------------------------------------------------------
pick_disk(){
  local menu=()
  # whiptail ne sait pas colorer un item de menu -> marquage textuel en tete.
  while IFS= read -r line; do
    eval "$line"                                   # NAME TYPE SIZE MODEL TRAN VENDOR RM HOTPLUG
    [ "${TYPE:-}" = disk ] || continue
    [ "$NAME" = "$live_dev" ] && continue          # jamais le media de boot
    local tag=""
    if [ "${RM:-0}" = "1" ] || [ "${HOTPLUG:-0}" = "1" ] || [ "${TRAN:-}" = "usb" ]; then
      tag="[!! USB / EXTERNE !!] "
      [ "$UI_LANG" = "en" ] && tag="[!! USB / EXTERNAL !!] "
    fi
    menu+=("/dev/$NAME" "$(printf '%s%-9s %-5s %s' "$tag" "${SIZE:-?}" "${TRAN:-?}" \
           "$(echo "${VENDOR:-} ${MODEL:-?}" | xargs)")")
  done < <(lsblk -dnP -o NAME,TYPE,SIZE,MODEL,TRAN,VENDOR,RM,HOTPLUG)

  [ ${#menu[@]} -gt 0 ] || die "$S_DISK_NONE"

  TARGET=$(whiptail --title "$S_TITLE" --menu "$S_DISK_PICK" 22 78 8 "${menu[@]}" 3>&1 1>&2 2>&3) \
    || die "$S_CANCELLED"

  # 32 Go : sous ce seuil le dd mourrait "No space left" APRES avoir efface.
  local bytes gb
  bytes=$(blockdev --getsize64 "$TARGET" 2>/dev/null || echo 0)
  gb=$(( bytes / 1000000000 ))
  if [ "$gb" -lt 32 ]; then
    whiptail --title "$S_WARN" --yesno --yes-button "$S_STOP" --no-button "$S_GOON" \
      "$(printf "$S_DISK_SMALL" "$TARGET" "$gb")" 15 70 && die "$S_STOPPED"
  fi

  local content
  content=$(lsblk -no NAME,SIZE,FSTYPE,LABEL "$TARGET" 2>/dev/null | sed 's/^/   /')
  whiptail --title "$S_CONFIRM_T" --yesno "$(printf "$S_DISK_CONFIRM" "$TARGET" "$content")" 20 78 \
    || die "$S_CANCELLED"
}

# ---------------------------------------------------------------------------
flash(){
  whiptail --title "$S_TITLE" --infobox "$(printf "$S_PREP" "$TARGET")" 7 62
  wipefs -af "$TARGET" 2>>"$LOG" || true
  dd if=/dev/zero of="$TARGET" bs=1M count=16 conv=fsync 2>>"$LOG" || true
  local bytes seek; bytes=$(blockdev --getsize64 "$TARGET"); seek=$(( bytes/1048576 - 16 ))
  (( seek > 0 )) && dd if=/dev/zero of="$TARGET" bs=1M seek="$seek" count=16 conv=fsync 2>>"$LOG" || true

  local dl
  dl=$(curl -fsSLI "$IMG_URL" 2>>"$LOG" \
       | awk 'BEGIN{IGNORECASE=1}/^content-length/{v=$2}END{gsub(/\r/,"",v);print v}')
  [[ "$dl" =~ ^[0-9]+$ ]] && (( dl > 1000000 )) || dl=560000000     # repli si en-tete absent

  # Le stdout de whiptail est force sur /dev/tty : sinon la substitution de
  # processus herite du tube vers xz et y injecte les codes terminal.
  set -o pipefail
  local rc
  {
    curl -fSL "$IMG_URL" 2>>"$LOG" \
      | pv -n -s "$dl" 2> >(whiptail --title "$S_TITLE" --gauge \
            "$(printf "$S_WRITING" "$HAOS_VERSION")" 9 72 0 >/dev/tty) \
      | xz -dc 2>>"$LOG" \
      | tee >(sha256sum | cut -d' ' -f1 > /tmp/haos-img.sha256) \
            >(wc -c > /tmp/haos-img.size) \
      | dd of="$TARGET" bs=4M conv=fsync 2>>"$LOG"
  }
  rc=$?
  sync; wait 2>/dev/null || true

  if [ $rc -ne 0 ]; then
    die "$(printf "$S_FAIL" "$rc" "$(tail -n 10 "$LOG" 2>/dev/null | cut -c1-66)" "$LOG")"
  fi
}

# ---------------------------------------------------------------------------
# xz valide deja l'integrite du TELECHARGEMENT (sommes de controle du format).
# Ici on valide l'ECRITURE : secteur defaillant, SSD en fin de vie, cable douteux.
verify(){
  local expect size actual
  expect=$(cat /tmp/haos-img.sha256 2>/dev/null)
  size=$(cat /tmp/haos-img.size 2>/dev/null)

  if ! [[ "$size" =~ ^[0-9]+$ ]] || [ -z "$expect" ]; then
    whiptail --title "$S_TITLE" --msgbox "$S_VFY_SKIP" 11 68; return 0
  fi

  whiptail --title "$S_TITLE" --yesno \
    "$(printf "$S_VFY_ASK" "$(numfmt --to=iec "$size" 2>/dev/null || echo "$size")" "$TARGET")" \
    14 70 || return 0

  # Vider le cache : sinon on relit la RAM, pas le disque -> verification inutile.
  sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

  actual=$(head -c "$size" "$TARGET" 2>>"$LOG" \
    | pv -n -s "$size" 2> >(whiptail --title "$S_TITLE" --gauge "$S_VFY_RUN" 8 68 0 >/dev/tty) \
    | sha256sum | cut -d' ' -f1)

  if [ "$actual" = "$expect" ]; then
    whiptail --title "$S_TITLE" --msgbox "$(printf "$S_VFY_OK" "${expect:0:32}")" 12 70
  else
    whiptail --title "$S_WARN" --msgbox \
      "$(printf "$S_VFY_KO" "${expect:0:24}" "${actual:0:24}")" 18 72
    die "$S_CANCELLED"
  fi
}

# ---------------------------------------------------------------------------
# Installation en Wi-Fi : HAOS oublie tout au premier boot et attend un reseau.
# On lui depose le profil NetworkManager que l'on vient d'utiliser, dans
# CONFIG/network/my-network de la partition hassos-boot (p1, FAT), ce que HAOS
# importe au demarrage. On reutilise le keyfile deja cree par nmcli plutot que
# de reconstruire le PSK.
push_wifi_config(){
  [ -n "${WIFI_SSID:-}" ] || return 0          # installation filaire : rien a faire

  local src part mnt=/mnt/hassos-boot ok=0
  # Le profil keyfile ecrit par NetworkManager pour ce SSID
  src=$(grep -rl "^ssid=$WIFI_SSID\$" /etc/NetworkManager/system-connections/ 2>>"$LOG" | head -1)
  [ -f "$src" ] || return 1

  # hassos-boot = 1re partition de l'image ecrite (label hassos-boot, sinon p1)
  part=$(lsblk -nro NAME,LABEL "$TARGET" 2>/dev/null | awk '$2=="hassos-boot"{print $1; exit}')
  [ -n "$part" ] || part=$(lsblk -nro NAME "$TARGET" 2>/dev/null | sed -n '2p')
  [ -n "$part" ] || return 1

  mkdir -p "$mnt"
  mount "/dev/$part" "$mnt" 2>>"$LOG" || return 1

  mkdir -p "$mnt/CONFIG/network"
  # Copie + durcissement : UUID4 fixe (sinon IP change a chaque boot, cf. doc HA),
  # et fins de ligne UNIX imperatives.
  {
    sed -e "s/^uuid=.*/uuid=$(cat /proc/sys/kernel/random/uuid)/" "$src"
  } | sed 's/\r$//' > "$mnt/CONFIG/network/my-network" 2>>"$LOG" && ok=1

  # Pas de secret laisse en clair sur une partition FAT au-dela du necessaire :
  chmod 600 "$mnt/CONFIG/network/my-network" 2>/dev/null || true
  sync; umount "$mnt" 2>>"$LOG" || true
  [ "$ok" = 1 ] || return 1
  return 0
}

# ---------------------------------------------------------------------------
finalize(){
  # Installation Wi-Fi : injecter le profil pour que HAOS se reconnecte seul.
  if [ -n "${WIFI_SSID:-}" ]; then
    if push_wifi_config; then
      whiptail --title "$S_TITLE" --msgbox "$(printf "$S_WIFI_PUSH" "$WIFI_SSID")" 11 66
    else
      whiptail --title "$S_WARN" --msgbox "$S_WIFI_PUSH_FAIL" 12 68
    fi
  fi

  # L'image contient deja \EFI\BOOT\bootx64.efi ; filet pour firmwares capricieux.
  if command -v efibootmgr >/dev/null && [ -d /sys/firmware/efi ]; then
    efibootmgr --create --disk "$TARGET" --part 1 \
      --label "HAOS" --loader '\EFI\BOOT\bootx64.efi' >/dev/null 2>&1 || true
  fi
  # Le live tourne depuis la cle : la retirer avant le reboot = I/O errors.
  whiptail --title "$S_TITLE" --msgbox "$(printf "$S_DONE" "$TARGET")" 19 74
  clear; reboot
}

# ---------------------------------------------------------------------------
HAOS_FALLBACK="18.1"
HAOS_VERSION=""
IMG_URL=""
TARGET=""
WIFI_SSID=""
live_dev=$(findmnt -no SOURCE /run/live/medium 2>/dev/null | sed -E 's,/dev/,,; s/p?[0-9]+$//' || true)

set_strings                 # defauts FR, remplaces par le choix de l'ecran 1
choose_lang_keyboard
whiptail --title "$S_TITLE" --msgbox \
  "$(printf "$S_WELCOME" "$(boot_status)" "$(secureboot_status)")" 22 74
setup_network
resolve_version             # NECESSITE le reseau : doit rester apres setup_network
pick_disk
flash
verify
finalize
