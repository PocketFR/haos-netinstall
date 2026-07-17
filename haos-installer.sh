#!/bin/bash
# haos-installer.sh — Assistant guidé d'installation de Home Assistant OS (bare-metal).
# Pensé pour les néophytes : écrans whiptail, Wi-Fi assisté, choix du disque avec
# aperçu du contenu, barre de progression. Lancé au boot d'un live Debian.
set -uo pipefail                       # pas de -e : on gère les erreurs pour garder l'assistant vivant
export NEWT_COLORS='root=,blue; window=,lightgray; border=blue,lightgray; title=blue,'

TITLE="Installation Home Assistant OS"

die(){ whiptail --title "$TITLE" --msgbox "$1\n\nUn terminal de secours va s'ouvrir." 12 72; clear; exec bash; }

# --- Version de HAOS ---
# Resolue APRES la configuration reseau (resolve_version) : en Wi-Fi, aucun reseau
# n'est disponible au lancement du script. Valeur de repli si l'API est injoignable.
HAOS_FALLBACK="18.1"
HAOS_VERSION=""
IMG_URL=""

# Média live (à exclure de la liste des cibles)
live_dev=$(findmnt -no SOURCE /run/live/medium 2>/dev/null | sed -E 's,/dev/,,; s/p?[0-9]+$//' || true)

have_net(){ curl -fsI --max-time 5 https://github.com >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Clavier : le live est configure en fr via keyboard-layouts, mais on laisse la
# main (ISO potentiellement utilise hors France, ou reglage non applique).
setup_keyboard(){
  local kb
  kb=$(whiptail --title "$TITLE" --menu \
    "Disposition du clavier :\n(teste les touches A, Q, M et les chiffres après validation)" \
    15 62 5 \
    "fr" "AZERTY  - France" \
    "be" "AZERTY  - Belgique" \
    "ch(fr)" "QWERTZ  - Suisse romande" \
    "ca" "QWERTY  - Canada" \
    "us" "QWERTY  - US / international" \
    3>&1 1>&2 2>&3) || kb="fr"
  loadkeys "$kb" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
setup_network(){
  have_net && return 0
  whiptail --title "$TITLE" --infobox "Recherche d'une connexion filaire (Ethernet)..." 7 62
  sleep 5; have_net && return 0

  # --- Diagnostic Wi-Fi : distinguer "pas de carte", "carte bloquee", "pas de reseau" ---
  rfkill unblock all 2>/dev/null || true
  nmcli radio wifi on 2>/dev/null || true
  sleep 2

  local wifi_if
  wifi_if=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
  if [ -z "$wifi_if" ]; then
    local diag
    diag=$( { echo "--- Interfaces vues par le noyau ---"; ip -br link 2>/dev/null;
              echo "--- NetworkManager ---"; nmcli dev status 2>/dev/null;
              echo "--- Blocages radio ---"; rfkill list 2>/dev/null;
              echo "--- Firmware manquant ? ---"; dmesg 2>/dev/null | grep -i firmware | tail -5; } \
            | cut -c1-64 | head -22 )
    whiptail --title "$TITLE" --msgbox \
      "Aucune carte Wi-Fi utilisable détectée.\n\n$diag\n\nBranche un câble Ethernet, ou choisis la configuration\nmanuelle à l'écran suivant." 24 72
  fi

  while true; do
    whiptail --title "$TITLE" --infobox "Recherche des réseaux Wi-Fi..." 7 62
    nmcli dev wifi rescan 2>/dev/null || true; sleep 3

    local menu=() ssid sig sec
    while IFS=$'\t' read -r ssid sig sec; do
      [ -n "$ssid" ] || continue
      menu+=("$ssid" "$(printf 'signal %3s%%   %s' "$sig" "${sec:-ouvert}")")
    done < <(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
             | awk -F: 'length($1) && !seen[$1]++ {print $1"\t"$2"\t"$3}')

    menu+=("[ Relancer le scan ]" "aucun réseau trouvé ? réessayer")
    menu+=("[ Configuration manuelle ]" "SSID caché, WPA entreprise, IP fixe (nmtui)")
    menu+=("[ Réessayer l'Ethernet ]" "câble branché entre-temps")

    local choice
    choice=$(whiptail --title "$TITLE" --menu \
      "Sélectionne ton réseau Wi-Fi :" 20 74 10 "${menu[@]}" 3>&1 1>&2 2>&3) \
      || { whiptail --title "$TITLE" --yesno \
             "Quitter l'installateur ?\n\nAucun réseau n'est configuré : l'installation ne peut pas continuer sans accès à Internet." \
             11 66 && die "Installation annulée par l'utilisateur." || continue; }

    case "$choice" in
      "[ Relancer le scan ]")        continue ;;
      "[ Configuration manuelle ]")  clear; nmtui; have_net && return 0 || continue ;;
      "[ Réessayer l'Ethernet ]")    have_net && return 0 || continue ;;
    esac

    # NOTE: --inputbox et non --passwordbox : le mot de passe reste VISIBLE.
    # Saisie a l'aveugle + risque de mauvaise disposition clavier = trop d'echecs.
    local psk
    psk=$(whiptail --title "$TITLE" --inputbox \
      "Mot de passe du réseau « $choice » :\n(affiché en clair pour éviter les fautes de frappe)" \
      10 66 3>&1 1>&2 2>&3) || continue

    whiptail --title "$TITLE" --infobox "Connexion à « $choice »..." 7 62
    local err
    err=$(nmcli dev wifi connect "$choice" password "$psk" 2>&1) && have_net && return 0
    whiptail --title "$TITLE" --msgbox \
      "Échec de connexion à « $choice ».\n\n$(echo "$err" | cut -c1-60 | head -4)\n\nVérifie le mot de passe, ou utilise la configuration manuelle." 14 68
  done
}

# ---------------------------------------------------------------------------
# A appeler UNIQUEMENT une fois le reseau operationnel.
resolve_version(){
  whiptail --title "$TITLE" --infobox "Recherche de la dernière version de Home Assistant OS..." 7 66
  HAOS_VERSION=$(curl -fsSL --max-time 15 \
    https://api.github.com/repos/home-assistant/operating-system/releases/latest \
    2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' || true)

  if [ -z "$HAOS_VERSION" ]; then
    HAOS_VERSION="$HAOS_FALLBACK"
    whiptail --title "$TITLE" --yesno \
      "Impossible de contacter GitHub pour connaître la dernière version.\n\nVersion de repli proposée : $HAOS_VERSION\n(elle peut être ancienne — Home Assistant se mettra à jour\nlui-même après l'installation)\n\nContinuer avec cette version ?" \
      15 70 || die "Installation annulée."
  fi

  IMG_URL="https://github.com/home-assistant/operating-system/releases/download/${HAOS_VERSION}/haos_generic-x86-64-${HAOS_VERSION}.img.xz"

  # Verifier que l'image existe vraiment avant d'effacer quoi que ce soit
  curl -fsI --max-time 15 "$IMG_URL" >/dev/null 2>&1 \
    || die "Image introuvable pour la version $HAOS_VERSION :\n$IMG_URL"
}

# ---------------------------------------------------------------------------
pick_disk(){
  local menu=()
  while IFS= read -r line; do
    eval "$line"                       # NAME TYPE SIZE MODEL TRAN VENDOR
    [ "${TYPE:-}" = disk ] || continue
    [ "$NAME" = "$live_dev" ] && continue        # jamais la clé de boot
    menu+=("/dev/$NAME" \
      "$(printf '%-9s %-5s %s' "${SIZE:-?}" "${TRAN:-?}" "$(echo "${VENDOR:-} ${MODEL:-?}" | xargs)")")
  done < <(lsblk -dnP -o NAME,TYPE,SIZE,MODEL,TRAN,VENDOR)

  [ ${#menu[@]} -gt 0 ] || die "Aucun disque interne détecté."

  TARGET=$(whiptail --title "$TITLE" --menu \
    "Sur quel disque installer Home Assistant OS ?\nTOUT son contenu sera définitivement effacé." \
    20 78 8 "${menu[@]}" 3>&1 1>&2 2>&3) || die "Installation annulée."

  local content
  content=$(lsblk -no NAME,SIZE,FSTYPE,LABEL "$TARGET" 2>/dev/null | sed 's/^/   /')
  whiptail --title "⚠  DERNIÈRE CONFIRMATION" --yesno \
    "Le disque $TARGET va être ENTIÈREMENT EFFACÉ.\n\nContenu actuel détecté :\n$content\n\nConfirmer l'effacement et l'installation ?" \
    20 78 || die "Installation annulée."
}

# ---------------------------------------------------------------------------
flash(){
  local LOG=/tmp/haos-install.log
  : > "$LOG"

  whiptail --title "$TITLE" --infobox "Préparation du disque $TARGET..." 7 62
  wipefs -af "$TARGET" 2>>"$LOG" || true                          # efface les signatures
  dd if=/dev/zero of="$TARGET" bs=1M count=16 conv=fsync 2>>"$LOG" || true
  local bytes seek; bytes=$(blockdev --getsize64 "$TARGET"); seek=$(( bytes/1048576 - 16 ))
  (( seek > 0 )) && dd if=/dev/zero of="$TARGET" bs=1M seek="$seek" count=16 conv=fsync 2>>"$LOG" || true

  # Taille compressée (pour la jauge) via l'en-tête HTTP après redirections
  local dl
  dl=$(curl -fsSLI "$IMG_URL" 2>>"$LOG" \
       | awk 'BEGIN{IGNORECASE=1}/^content-length/{v=$2}END{gsub(/\r/,"",v);print v}')
  [[ "$dl" =~ ^[0-9]+$ ]] && (( dl > 1000000 )) || dl=450000000     # repli si en-tête absent

  # NOTE: le stdout de whiptail est forcé sur /dev/tty. Sans cela, la substitution
  # de processus hérite du tube vers xz et y injecte les codes terminal -> flux corrompu.
  set -o pipefail
  local rc
  {
    curl -fSL "$IMG_URL" 2>>"$LOG" \
      | pv -n -s "$dl" 2> >(whiptail --title "$TITLE" --gauge \
            "Téléchargement et écriture de HAOS $HAOS_VERSION.\nNe pas éteindre le PC." \
            9 72 0 >/dev/tty) \
      | xz -dc 2>>"$LOG" \
      | dd of="$TARGET" bs=4M conv=fsync 2>>"$LOG"
  }
  rc=$?
  sync
  wait 2>/dev/null || true

  if [ $rc -ne 0 ]; then
    local detail
    detail=$(tail -n 12 "$LOG" 2>/dev/null | cut -c1-70)
    whiptail --title "$TITLE" --msgbox \
      "Échec de l'installation (code $rc).\n\nDétail :\n${detail:-aucun message}\n\nJournal complet : $LOG\nUn terminal de secours va s'ouvrir." \
      22 74
    clear; exec bash
  fi
}

# ---------------------------------------------------------------------------
finalize(){
  # L'image contient déjà \EFI\BOOT\bootx64.efi ; filet pour firmwares capricieux
  if command -v efibootmgr >/dev/null && [ -d /sys/firmware/efi ]; then
    efibootmgr --create --disk "$TARGET" --part 1 \
      --label "HAOS" --loader '\EFI\BOOT\bootx64.efi' >/dev/null 2>&1 || true
  fi
  # NOTE: le live tourne depuis la clé USB. La retirer avant le reboot provoque
  # des I/O errors (racine arrachée). Sauf boot en "toram", on redémarre d'abord.
  whiptail --title "$TITLE" --msgbox \
    "Installation terminée.\n\nHome Assistant OS est installé sur $TARGET.\n\nÀ SUIVRE, DANS CET ORDRE :\n 1. Valide ci-dessous : le PC redémarre.\n 2. Retire la clé USB DÈS QUE L'ÉCRAN S'ÉTEINT.\n    (ne la retire pas maintenant)\n 3. Garde le câble réseau branché.\n 4. Patiente 2 à 5 minutes (premier démarrage).\n 5. Depuis un autre appareil :  http://homeassistant.local:8123" \
    19 74
  clear; reboot
}

# ---------------------------------------------------------------------------
whiptail --title "$TITLE" --msgbox \
  "Bienvenue.\n\nCet outil installe la dernière version de Home Assistant OS\nsur ce PC, sans ligne de commande.\n\nAVANT DE CONTINUER — dans le BIOS/UEFI (touche Suppr/F2 au démarrage) :\n   • Mode de démarrage : UEFI\n   • Secure Boot : DÉSACTIVÉ  (obligatoire pour HAOS)\n\nÀ l'étape suivante, TOUT le disque que tu choisiras sera effacé." \
  17 74

setup_keyboard
setup_network
resolve_version    # NECESSITE le reseau : doit rester apres setup_network
pick_disk
flash
finalize
