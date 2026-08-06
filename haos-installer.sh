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

# Trace explicite des decisions. Les 21 redirections "2>>$LOG" du script ne
# capturent que des stderr d'echec : sans ces lignes, le journal d'une
# installation REUSSIE est vide, donc inutile a archiver et a joindre a un
# rapport de bug. Jamais de secret ici (le PSK Wi-Fi n'y passe pas).
logx(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# ---------------------------------------------------------------------------
# Chaines. Les variables sont injectees via printf (%s) : pas d'interpolation
# a la definition, sinon $TARGET & co seraient vides a ce stade.
# ---------------------------------------------------------------------------
set_strings(){
if [ "$UI_LANG" = "fr" ]; then
  S_TITLE="Installation Home Assistant OS"
  S_WARN="⚠  AVERTISSEMENT — Installation Home Assistant OS"
  S_RESCUE="\n\nTu vas pouvoir sauvegarder le journal, puis éteindre le PC."
  S_HALT_ASK="Que faire maintenant ?\n\nRien ne sera modifié : l'installation est terminée, en échec.\nÉteindre est le choix normal.\n\nLe terminal n'est utile que si tu sais t'en servir."
  S_HALT_OFF="Éteindre le PC"
  S_HALT_SHELL="Ouvrir un terminal"
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
  S_VER_FAIL="Impossible de déterminer la version de Home Assistant OS.\n\nLes deux sources ont été tentées sans succès :\n  version.home-assistant.io  (canal stable)\n  api.github.com             (dernière publication)\n\nL'installation ne peut pas continuer : sans version, il n'y\na pas d'image à télécharger.\n\nVérifie l'accès à Internet et la résolution DNS, puis\nrelance l'installateur."
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
  S_FAIL="Échec de l'installation (code %s).\n\nCause la plus fréquente : une coupure de la connexion Internet\npendant le téléchargement. Le disque a déjà été effacé ;\nrelancer l'installation depuis le début est sans danger.\n\nDétail :\n%s\n\nJournal complet : %s"
  S_VFY_ASK="Vérifier que le disque a été écrit correctement ?\n\nRelecture de %s depuis %s.\nDurée : 1 à 3 minutes selon le disque.\n\nRecommandé, surtout sur un disque ancien."
  S_VFY_RUN="Relecture et vérification du disque..."
  S_VFY_OK="Vérification réussie.\n\nLe contenu du disque correspond exactement à l'image.\n\nSHA256 : %s..."
  S_VFY_KO="ÉCHEC DE LA VÉRIFICATION\n\nLe disque ne correspond pas à l'image écrite :\n  attendu : %s...\n  lu      : %s...\n\nCauses possibles : disque défaillant, câble SATA, mémoire.\nNE PAS utiliser cette installation : recommence, et si\nl'erreur persiste, change de disque."
  S_VFY_SKIP="Empreinte de l'image non calculée : vérification impossible.\nL'installation est probablement correcte (le téléchargement\nest validé par le format compressé)."
  S_LOG_ASK="Copier le journal d'installation sur une clé USB ?\n\nIl sera perdu au redémarrage sinon. C'est le fichier à\njoindre pour signaler le problème."
  S_LOG_OK="Journal copié sur %s\n(fichier haos-install-*.log)\n\nTu peux retirer la clé."
  S_LOG_MENU="Où sauvegarder le journal d'installation ?\n\nAucun support inscriptible n'a été trouvé automatiquement.\nChoisis une solution :"
  S_LOG_M_USB="Brancher une clé USB"
  S_LOG_M_USB_D="branche-la, attends 5 s, puis valide"
  S_LOG_M_FMT="Reformater la clé d'installation"
  S_LOG_M_FMT_D="efface l'installateur, la clé redevient normale"
  S_LOG_M_SHOW="Afficher le journal à l'écran"
  S_LOG_M_SHOW_D="pour le photographier — marche toujours"
  S_LOG_M_NONE="Ne pas sauvegarder"
  S_LOG_M_NONE_D="le journal sera perdu au redémarrage"
  S_LOG_VTOY="La clé est reconnue, mais réservée par le système de\ndémarrage, et la libérer automatiquement a échoué.\n\nC'est le cas avec Ventoy : l'image d'installation est un\nfichier de cette clé.\n\n➜ DÉBRANCHE puis REBRANCHE la clé, attends 5 secondes, et\n  choisis « Brancher une clé USB » ci-dessous.\n\nL'installateur tourne en mémoire : la débrancher est sans\nconséquence."
  S_LOG_RO="Un support a été trouvé, mais il est en lecture seule.\n\nC'est le cas avec Ventoy : le système d'installation utilise\ncette partition, elle n'est donc pas modifiable.\n\nDébrancher puis rebrancher la clé la libère, ou choisis une\nautre solution."
  S_LOG_DETECT="Détection du support..."
  S_LOG_RETRY="Toujours rien d'inscriptible.\n\nLa clé n'est peut-être pas partitionnée, ou son format\nn'est pas reconnu. Tu peux réessayer avec une autre clé."
  S_LOG_FULL="Un support a bien été trouvé, mais il est plein.\n\nLa place manque pour y écrire le journal. Branche une\nautre clé USB, ou affiche le journal à l'écran à l'étape\nsuivante pour le photographier."
  S_LOG_NONE="Journal non copié.\n\nIl reste consultable dans le terminal :\n  cat %s"
  S_WIFI_PUSH="Réseau Wi-Fi « %s » pré-configuré.\n\nHome Assistant tentera de s'y connecter au premier\ndémarrage — MAIS seulement si ta carte Wi-Fi fait partie\nde celles qu'il prend en charge (sa liste est plus\nrestreinte que celle de cet installateur).\n\nSi Home Assistant n'apparaît pas en ligne après 5 min :\n • branche un câble Ethernet (recommandé), ou\n • signale ta carte au projet Home Assistant OS.\n\nGarde ce PC à portée du Wi-Fi."
  S_WIFI_PUSH_FAIL="Le Wi-Fi n'a pas pu être pré-configuré dans l'image.\n\nHome Assistant démarrera sans réseau : il faudra le\nconnecter ensuite (câble Ethernet, ou clavier+écran sur\nla console HAOS)."
  S_WIFI_PUSH_SKIP="Ce réseau Wi-Fi ne peut pas être pré-configuré.\n\nIl s'appuie sur des certificats ou un mode que Home\nAssistant ne pourra pas reprendre tel quel. Rien n'a été\nécrit : mieux vaut cela qu'un réseau qui ne monte jamais.\n\nÀ FAIRE APRÈS L'INSTALLATION :\n • branche un câble Ethernet (le plus simple), ou\n • configure le Wi-Fi depuis la console de Home Assistant\n   (clavier + écran sur le PC).\n\nLe détail figure dans le journal d'installation."
  S_DONE_LOG="\n\nLa clé a été reformatée : elle redevient une clé USB normale,\net le journal d'installation y a été copié."
  S_FMT_ASK="Reformater la clé USB d'installation ?\n\n%s\n\nElle redeviendrait une clé ordinaire (FAT32), utilisable\npartout, et le journal d'installation y serait copié.\n\n⚠  L'INSTALLATEUR SERA EFFACÉ : pour réinstaller, il faudra\nregraver la clé depuis un autre ordinateur.\n\nL'installation de Home Assistant déjà écrite sur le disque\nn'est pas concernée."
  S_FMT_YES="Reformater la clé"
  S_FMT_NO="Garder l'installateur"
  S_FMT_FAIL="La clé n'a pas pu être reformatée.\n\nRien n'a été touché : elle reste utilisable comme\ninstallateur. Le détail figure dans le journal."
  S_FMT_BROKEN="Le reformatage de la clé a échoué en cours de route.\n\n⚠  La clé n'est plus amorçable : il faudra la regraver pour\ns'en resservir comme installateur.\n\nL'installation de Home Assistant sur le disque n'est pas\nconcernée, elle est terminée."
  S_DONE="Installation terminée.\n\nHome Assistant OS est installé sur %s.\n\n➜ RETIRE LA CLÉ USB MAINTENANT, avant de valider.\n  (l'installateur tourne en mémoire : la clé ne sert plus)\n\nÀ SUIVRE :\n 1. Valide ci-dessous : le PC redémarre sur Home Assistant.\n 2. Garde le câble réseau branché.\n 3. Patiente 2 à 5 minutes (premier démarrage).\n 4. Depuis un autre appareil :  http://homeassistant.local"
else
  S_TITLE="Home Assistant OS installation"
  S_WARN="⚠  WARNING — Home Assistant OS installation"
  S_RESCUE="\n\nYou will be able to save the log, then power the PC off."
  S_HALT_ASK="What now?\n\nNothing more will change: the installation ended in failure.\nPowering off is the normal choice.\n\nThe terminal is only useful if you know your way around it."
  S_HALT_OFF="Power off"
  S_HALT_SHELL="Open a terminal"
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
  S_VER_FAIL="Could not determine the Home Assistant OS version.\n\nBoth sources were tried without success:\n  version.home-assistant.io  (stable channel)\n  api.github.com             (latest release)\n\nThe installation cannot continue: with no version there is\nno image to download.\n\nCheck Internet access and DNS resolution, then start the\ninstaller again."
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
  S_FAIL="Installation failed (code %s).\n\nMost common cause: the Internet connection dropped during the\ndownload. The disk has already been erased; starting the\ninstallation over from scratch is safe.\n\nDetails:\n%s\n\nFull log: %s"
  S_VFY_ASK="Verify that the disk was written correctly?\n\nReads back %s from %s.\nTakes 1 to 3 minutes depending on the disk.\n\nRecommended, especially on an older disk."
  S_VFY_RUN="Reading back and verifying the disk..."
  S_VFY_OK="Verification passed.\n\nThe disk contents match the image exactly.\n\nSHA256: %s..."
  S_VFY_KO="VERIFICATION FAILED\n\nThe disk does not match the image written:\n  expected: %s...\n  read    : %s...\n\nLikely causes: failing disk, SATA cable, memory.\nDO NOT use this installation: try again, and if the error\npersists, replace the disk."
  S_VFY_SKIP="Image checksum was not computed: cannot verify.\nThe installation is most likely fine (the download is\nvalidated by the compressed format itself)."
  S_LOG_ASK="Copy the installation log to a USB stick?\n\nIt will be lost on reboot otherwise. This is the file to\nattach when reporting the problem."
  S_LOG_OK="Log copied to %s\n(file haos-install-*.log)\n\nYou can remove the stick."
  S_LOG_MENU="Where should the installation log be saved?\n\nNo writable medium was found automatically.\nPick an option:"
  S_LOG_M_USB="Plug in a USB stick"
  S_LOG_M_USB_D="plug it in, wait 5 s, then confirm"
  S_LOG_M_FMT="Reformat the installer stick"
  S_LOG_M_FMT_D="erases the installer, the stick becomes normal"
  S_LOG_M_SHOW="Show the log on screen"
  S_LOG_M_SHOW_D="to photograph it — always works"
  S_LOG_M_NONE="Do not save"
  S_LOG_M_NONE_D="the log will be lost on reboot"
  S_LOG_VTOY="The stick is recognised, but reserved by the boot system,\nand releasing it automatically failed.\n\nThis happens with Ventoy: the installation image is a file on\nthis stick.\n\n➜ UNPLUG then REPLUG the stick, wait 5 seconds, and pick\n  \"Plug in a USB stick\" below.\n\nThe installer runs from memory: unplugging it is harmless."
  S_LOG_RO="A medium was found, but it is read-only.\n\nThis happens with Ventoy: the install system is using that\npartition, so it cannot be modified.\n\nUnplugging and replugging the stick frees it, or pick another\noption."
  S_LOG_DETECT="Detecting media..."
  S_LOG_RETRY="Still nothing writable.\n\nThe stick may be unpartitioned, or its format is not\nrecognised. You can try another one."
  S_LOG_FULL="A medium was found, but it is full.\n\nThere is not enough room to write the log. Plug in another\nUSB stick, or display the log on screen at the next step to\nphotograph it."
  S_LOG_NONE="Log not copied.\n\nIt is still readable from the shell:\n  cat %s"
  S_WIFI_PUSH="Wi-Fi network \"%s\" pre-configured.\n\nHome Assistant will try to connect on first boot — BUT\nonly if your Wi-Fi card is among those it supports (its\nlist is narrower than this installer's).\n\nIf Home Assistant is not online after 5 min:\n • plug in an Ethernet cable (recommended), or\n • report your card to the Home Assistant OS project.\n\nKeep this PC within Wi-Fi range."
  S_WIFI_PUSH_FAIL="Wi-Fi could not be pre-configured into the image.\n\nHome Assistant will boot with no network: you will have to\nconnect it afterwards (Ethernet cable, or keyboard+screen\non the HAOS console)."
  S_WIFI_PUSH_SKIP="This Wi-Fi network cannot be pre-configured.\n\nIt relies on certificates or a mode Home Assistant could not\npick up as-is. Nothing was written: better that than a\nnetwork that never comes up.\n\nTO DO AFTER THE INSTALL:\n • plug in an Ethernet cable (simplest), or\n • configure Wi-Fi from the Home Assistant console\n   (keyboard + screen on the PC).\n\nDetails are in the installation log."
  S_DONE_LOG="\n\nThe stick was reformatted: it is a normal USB stick again,\nand the installation log was copied onto it."
  S_FMT_ASK="Reformat the installer USB stick?\n\n%s\n\nIt would become an ordinary FAT32 stick, usable anywhere,\nand the installation log would be copied onto it.\n\n⚠  THE INSTALLER WILL BE ERASED: to reinstall, you would\nhave to write the stick again from another computer.\n\nThe Home Assistant installation already written to the disk\nis not affected."
  S_FMT_YES="Reformat the stick"
  S_FMT_NO="Keep the installer"
  S_FMT_FAIL="The stick could not be reformatted.\n\nNothing was touched: it is still usable as an installer.\nDetails are in the log."
  S_FMT_BROKEN="Reformatting the stick failed partway through.\n\n⚠  The stick is no longer bootable: you will have to write it\nagain to reuse it as an installer.\n\nThe Home Assistant installation on the disk is not affected,\nit is complete."
  S_DONE="Installation complete.\n\nHome Assistant OS is installed on %s.\n\n➜ REMOVE THE USB STICK NOW, before confirming.\n  (the installer runs from memory: the stick is no longer used)\n\nNEXT:\n 1. Confirm below: the PC reboots into Home Assistant.\n 2. Keep the network cable plugged in.\n 3. Wait 2 to 5 minutes (first boot).\n 4. From another device:  http://homeassistant.local"
fi
}

# ---------------------------------------------------------------------------
# whiptail ne redimensionne rien et ne fait pas defiler : un texte plus haut que
# la boite est coupe en silence. On calcule donc la geometrie depuis le texte.
# Les chaines portent des \n litteraux (whiptail les interprete lui-meme) : on
# mesure sur une copie developpee, mais on passe l'original a whiptail pour ne
# pas alterer d'eventuels antislashs venus du journal.
wt_dims(){                                  # <texte> -> WT_H, WT_W, WT_SCROLL
  local body line len inner lines=0 max=0 rows cols
  body=$(printf '%b' "$1")
  rows=$(tput lines 2>/dev/null) || rows=24
  cols=$(tput cols  2>/dev/null) || cols=80
  [[ "$rows" =~ ^[0-9]+$ ]] || rows=24
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80

  while IFS= read -r line; do
    len=${#line}; (( len > max )) && max=$len
  done <<< "$body"

  WT_W=$(( max + 6 ))
  (( WT_W < 40 ))        && WT_W=40
  (( WT_W > cols - 4 ))  && WT_W=$(( cols - 4 ))

  inner=$(( WT_W - 4 )); (( inner < 1 )) && inner=1
  while IFS= read -r line; do
    len=${#line}
    (( len < 1 )) && len=1                  # une ligne vide occupe quand meme 1 ligne
    lines=$(( lines + (len + inner - 1) / inner ))
  done <<< "$body"

  WT_SCROLL=""
  WT_H=$(( lines + 7 ))                     # marge de la convention du script
  if (( WT_H > rows - 2 )); then            # trop haut pour l'ecran -> ascenseur
    WT_H=$(( rows - 2 )); WT_SCROLL="--scrolltext"
  fi
}

wt_msg(){                                   # <titre> <texte>
  wt_dims "$2"
  whiptail --title "$1" $WT_SCROLL --msgbox "$2" "$WT_H" "$WT_W"
}

wt_yesno(){                                 # <titre> <texte> [args whiptail...]
  local title="$1" text="$2"; shift 2
  wt_dims "$text"
  whiptail --title "$title" $WT_SCROLL "$@" --yesno "$text" "$WT_H" "$WT_W"
}

# Fin de parcours sur erreur. On ETEINT par defaut plutot que de rendre un shell :
# une invite bash ne veut rien dire pour le public visé. Le terminal reste
# accessible via le second bouton -- et non via Ctrl+Alt+F2, dont la
# disponibilite depend d'un getty et d'un mot de passe qu'on ne maitrise pas
# (le service occupe tty1 et le live bascule en multi-user.target).
die(){
  wt_msg "$S_TITLE" "$1$S_RESCUE"
  save_log
  loud_console
  if wt_yesno "$S_TITLE" "$S_HALT_ASK" --yes-button "$S_HALT_OFF" --no-button "$S_HALT_SHELL"; then
    clear; poweroff
  fi
  clear; exec bash
}

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
  wt_msg "$S_TITLE" \
    "Keyboard layout could not be applied / La disposition n'a pas pu être appliquée :\n\n$(echo "$out" | cut -c1-64 | head -6)\n\nQWERTY/AZERTY may be wrong. Use the manual config if needed."
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

# UUID de la connexion Wi-Fi ACTIVE, quel qu'ait ete son mode de creation
# (parcours guide ou nmtui). Vide s'il n'y en a pas.
active_wifi_uuid(){
  nmcli -t -f UUID,TYPE connection show --active 2>/dev/null \
    | awk -F: '$2=="802-11-wireless" || $2=="wifi" {print $1; exit}'
}

# Detail du lien Wi-Fi : bande, generation 802.11 et chiffrement.
# Pourquoi ca compte :
#   - bande : le 6 GHz exige noyau, firmware ET domaine reglementaire recents.
#     Ca marche ici et pas forcement sous HAOS -> vecteur d'echec reel.
#   - chiffrement : c'est ce que le profil depose sur hassos-boot doit
#     reproduire. Un ecart (WPA3 pur, reseau ouvert, 802.1X) et HAOS ne se
#     connecte pas, alors que l'installateur annonce un succes.
#
# ATTENTION, deux pieges corriges ici apres un faux diagnostic en test reel :
#   1. l'AP courant est marque par un '*' dans IN-USE, PAS par "yes" dans
#      ACTIVE -- un filtre sur ACTIVE ne matche jamais et tout ressort vide ;
#   2. une valeur indeterminee ne doit JAMAIS devenir une affirmation. Un
#      "${sec:-AUCUN (reseau ouvert)}" a fait passer un WPA2 pour un reseau
#      ouvert. On distingue donc trois etats : detecte / ouvert confirme /
#      indetermine, et on n'avertit que sur une detection positive.
# Source autoritative : le key-mgmt de la connexion active, qui ne depend
# d'aucun marqueur d'affichage.
# Ni le SSID ni le BSSID ne sont journalises : 'iw link' les expose, on n'en
# extrait que la frequence et le jeton de generation.
log_wifi_link(){
  # km initialise : sinon 'set -u' fait echouer le script quand aucune connexion
  # Wi-Fi active n'est trouvee et que le bloc d'affectation est saute.
  local dev="$1" drv="${2:-}" iwout freq band gen km="" sec uuid

  iwout=$(iw dev "$dev" link 2>/dev/null)
  freq=$(printf '%s\n' "$iwout" \
         | sed -n 's/^[[:space:]]*freq:[[:space:]]*\([0-9]\{3,\}\).*/\1/p' | head -1)

  band="indeterminee"
  if [ -n "$freq" ]; then
    if   [ "$freq" -lt 3000 ]; then band="2.4 GHz"
    elif [ "$freq" -lt 5925 ]; then band="5 GHz"
    else                            band="6 GHz"
    fi
  fi

  # Generation deduite du jeton de debit : EHT=Wi-Fi 7, HE=6, VHT=5, HT/MCS=4.
  case "$iwout" in
    *EHT-MCS*) gen="802.11be (Wi-Fi 7)" ;;
    *HE-MCS*)  gen="802.11ax (Wi-Fi 6)" ;;
    *VHT-MCS*) gen="802.11ac (Wi-Fi 5)" ;;
    *MCS*)     gen="802.11n (Wi-Fi 4)"  ;;
    "")        gen="indeterminee"       ;;   # iw muet : ne rien inventer
    *)         gen="legacy a/b/g"       ;;
  esac

  # key-mgmt effectif de la connexion active. Trois etats a distinguer.
  uuid=$(active_wifi_uuid)
  if [ -n "$uuid" ]; then
    km=$(nmcli -g 802-11-wireless-security.key-mgmt connection show "$uuid" 2>/dev/null)
  fi
  # Chaine annoncee par l'AP, en complement : '*' dans IN-USE designe l'AP courant.
  sec=$(nmcli -t -f IN-USE,SECURITY dev wifi list 2>/dev/null \
        | awk -F: '$1=="*"{print $2; exit}')

  logx "reseau : Wi-Fi $gen, bande ${band}${freq:+ (${freq} MHz)}"
  logx "reseau : lien Wi-Fi -- verifier que HAOS embarque le pilote ${drv:-?}"

  if [ -n "$km" ]; then
    logx "reseau : chiffrement key-mgmt=$km${sec:+ (AP annonce : $sec)}"
    # Avertissements uniquement sur detection POSITIVE.
    case "$km" in
      sae)     logx "reseau : WPA3 pur (SAE) -- le profil injecte doit porter key-mgmt=sae" ;;
      wpa-eap|wpa-eap-suite-b-192)
               logx "reseau : ATTENTION 802.1X (entreprise) -- profil injectable seulement sans certificats" ;;
      none)    logx "reseau : ATTENTION WEP ou sans chiffrement -- verifier le profil injecte" ;;
    esac
  elif [ -n "$uuid" ]; then
    logx "reseau : chiffrement AUCUN (reseau ouvert confirme)"
    logx "reseau : ATTENTION reseau ouvert -- le profil injecte ne doit porter aucun secret"
  else
    # Aucune connexion Wi-Fi active identifiee : on ne conclut rien.
    logx "reseau : chiffrement indetermine (aucune connexion Wi-Fi active vue par nmcli)"
  fi
}

# Journalise le type de lien retenu (Ethernet ou Wi-Fi) et le MATERIEL utilise.
# C'est le renseignement le plus utile du journal : la couverture des cartes
# Wi-Fi par HAOS est plus etroite que celle de cet installateur, donc quand HAOS
# demarre sans reseau apres une installation reussie, c'est le nom du PILOTE
# qu'il faut connaitre pour trancher.
# Appele UNE fois apres setup_network : cette derniere a cinq points de sortie
# (Ethernet immediat, Ethernet apres attente, Wi-Fi, nmtui, reprise Ethernet),
# les instrumenter separement serait fragile.
# Ni lspci ni ethtool dans l'ISO -> nmcli, qui expose deja vendeur/produit/pilote,
# avec repli sysfs (le modalias porte les identifiants PCI/USB du composant).
log_active_net(){
  local dev typ vendor product driver modalias found=0
  while IFS= read -r dev; do
    [ -n "$dev" ] || continue
    typ=$(nmcli -g GENERAL.TYPE device show "$dev" 2>/dev/null | head -1)
    case "$typ" in ethernet|wifi) ;; *) continue ;; esac
    found=1
    vendor=$(nmcli -g GENERAL.VENDOR  device show "$dev" 2>/dev/null | head -1)
    product=$(nmcli -g GENERAL.PRODUCT device show "$dev" 2>/dev/null | head -1)
    driver=$(nmcli -g GENERAL.DRIVER  device show "$dev" 2>/dev/null | head -1)
    # Replis sysfs, utiles si nmcli reste muet (carte non geree, udev incomplet).
    # On teste que le lien existe : sinon readlink -f pourrait rendre un chemin
    # fabrique et basename en tirerait un faux nom de pilote.
    if [ -z "$driver" ] && [ -L "/sys/class/net/$dev/device/driver" ]; then
      driver=$(basename "$(readlink -f "/sys/class/net/$dev/device/driver")")
    fi
    modalias=$(cat "/sys/class/net/$dev/device/modalias" 2>/dev/null)
    logx "reseau : $typ via $dev -- $(echo "${vendor:-?} ${product:-?}" | xargs)"
    logx "reseau : pilote=${driver:-inconnu} modalias=${modalias:-inconnu}"
    [ "$typ" = "wifi" ] && log_wifi_link "$dev" "$driver"
  done < <(nmcli -t -f DEVICE,STATE device status 2>/dev/null \
           | awk -F: '$2=="connected"{print $1}')
  [ "$found" -eq 1 ] || logx "reseau : aucune interface connectee identifiee par nmcli"
}

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
# Copie le journal sur une partition. 0 = ecrit, 1 = montage impossible,
# 2 = montee mais trop petite (ou copie refusee).
# NB: on interroge lsblk UNE COLONNE A LA FOIS. En multi-colonnes, une valeur
#     vide (TRAN, FSTYPE...) fait glisser les champs suivants a la lecture.
# La partition est-elle retenue par un device-mapper ? C'est le cas sous Ventoy :
# l'ISO est un FICHIER de la partition exFAT, que Ventoy expose en dm-linear. La
# partition est donc reclamee par dm et refuse un montage en ecriture -- d'ou le
# contournement "debrancher/rebrancher", qui detruit ce mappage.
dm_holds(){
  local p="$1" s
  for s in /sys/block/dm-*/slaves/*; do
    [ -e "$s" ] || continue
    [ "$(basename "$s")" = "$p" ] && return 0
  done
  return 1
}

# Libere la partition retenue par le mappage de demarrage (Ventoy), pour pouvoir
# y ecrire le journal sans demander a l'utilisateur de debrancher la cle.
#
# CONDITION DE SURETE ABSOLUE : ne rien retirer si le live lit encore le media.
# 'toram' est SILENCIEUSEMENT IGNORE par live-boot quand la RAM est insuffisante ;
# dans ce cas le systeme de fichiers racine vient toujours du mappage, et le
# supprimer tuerait l'installateur en pleine execution. La preuve que toram a
# pris effet : /run/live/medium est un tmpfs. Au moindre doute on renonce et on
# retombe sur l'instruction manuelle.
release_boot_medium(){
  local p="$1" fs dm base name holders mp disk
  fs=$(findmnt -no FSTYPE /run/live/medium 2>/dev/null || true)
  if [ -n "$fs" ] && [ "$fs" != "tmpfs" ]; then
    logx "liberation refusee : le live lit encore le media ($fs), toram inactif"
    return 1
  fi
  command -v dmsetup >/dev/null 2>&1 || { logx "liberation impossible : dmsetup absent"; return 1; }

  for dm in /sys/block/dm-*; do
    [ -e "$dm/slaves/$p" ] || continue
    base=$(basename "$dm")
    name=$(cat "$dm/dm/name" 2>/dev/null)
    # Un mappage empile par-dessus interdit le retrait.
    holders=$(find "$dm/holders" -mindepth 1 2>/dev/null | wc -l)
    if [ "${holders:-0}" -gt 0 ]; then
      logx "liberation refusee : ${name:-$base} a des dependants"
      return 1
    fi
    # Demonter le mappage s'il l'est encore : avec toram l'ISO ne sert plus.
    # "|| [ -n "$mp" ]" : sans cela une sortie sans retour chariot final ferait
    # SAUTER la derniere ligne, donc un point de montage non demonte.
    while read -r mp || [ -n "$mp" ]; do
      [ -n "$mp" ] || continue
      umount "$mp" 2>>"$LOG" || { logx "liberation : $mp non demontable"; return 1; }
    done < <(findmnt -rn -S "/dev/$base" -o TARGET 2>/dev/null)
    dmsetup remove "${name:-$base}" 2>>"$LOG" \
      || { logx "liberation : dmsetup remove a echoue sur ${name:-$base}"; return 1; }
    logx "mappage de demarrage ${name:-$base} retire, /dev/$p libere"
  done

  # Ventoy protege parfois le peripherique en lecture seule.
  disk=$(lsblk -no PKNAME "/dev/$p" 2>/dev/null | head -1 | tr -d ' ')
  [ -n "$disk" ] && { blockdev --setrw "/dev/$disk" 2>>"$LOG" || true; }
  partprobe "/dev/${disk:-$p}" 2>>"$LOG" || true
  udevadm settle 2>/dev/null || sleep 2
  return 0
}

write_log_to(){
  local p="$1" src="$2" need="$3" mp avail owned=0 rc

  # Retenue par un mappage de demarrage ? Tenter de le liberer plutot que
  # d'imposer un debranchement. Si cela echoue, la suite renverra 4 et
  # l'utilisateur recevra l'instruction manuelle.
  if dm_holds "$p"; then
    release_boot_medium "$p" || true
  fi
  # PIEGE (constate sous Ventoy) : si la partition est DEJA montee en lecture
  # seule -- Ventoy tient sa partition de donnees pour y lire l'ISO -- alors
  # "mount -o rw" reutilise le superbloc en lecture seule et reussit malgre tout.
  # Le cp echouait ensuite, et etait rapporte comme un manque de place. On detecte
  # donc le montage existant, on tente de le repasser en ecriture, et on ne
  # DEMONTE JAMAIS ce qu'on n'a pas monte : le live peut en dependre.
  # On TENTE d'abord, sans rien presumer : dm_holds ne sert qu'a EXPLIQUER un
  # echec (code 4), jamais a refuser d'essayer -- une configuration ou cela
  # fonctionnerait quand meme ne doit pas etre ecartee.
  mp=$(findmnt -rn -S "/dev/$p" -o TARGET 2>/dev/null | head -1)
  if [ -n "$mp" ]; then
    if ! touch "$mp/.haos-wtest" 2>/dev/null; then
      if ! mount -o remount,rw "$mp" 2>>"$LOG" || ! touch "$mp/.haos-wtest" 2>/dev/null; then
        dm_holds "$p" && { logx "journal : /dev/$p retenu par device-mapper (Ventoy)"; return 4; }
        return 3
      fi
    fi
    rm -f "$mp/.haos-wtest" 2>/dev/null || true
  else
    mp=/mnt/logdest
    mkdir -p "$mp" 2>/dev/null
    if ! mount -o rw "/dev/$p" "$mp" 2>>"$LOG"; then
      dm_holds "$p" && { logx "journal : /dev/$p retenu par device-mapper (Ventoy)"; return 4; }
      return 1
    fi
    owned=1
  fi

  rc=0
  avail=$(df --output=avail -k "$mp" 2>/dev/null | tail -1 | tr -d ' ')
  if [ "${avail:-0}" -lt "$need" ]; then
    rc=2
  elif cp "$src" "$mp/haos-install-$(date +%Y%m%d-%H%M).log" 2>>"$LOG"; then
    sync
  else
    rc=3                      # monte mais non inscriptible : ce n'est PAS "plein"
  fi
  [ "$owned" -eq 1 ] && { umount "$mp" 2>/dev/null || true; }
  return $rc
}

# Tente d'ecrire le journal. Affiche le peripherique utilise, ou renvoie :
#   1 = aucun support inscriptible trouve
#   2 = support trouve mais sans place
#   3 = support trouve mais non inscriptible (monte en lecture seule)
#   4 = support retenu par le systeme de demarrage (Ventoy) : debrancher/rebrancher
try_write_log(){
  local src="$1" part st need rc=1
  need=$(( ($(stat -c%s "$src" 2>/dev/null || echo 0) / 1024) + 64 ))   # Ko + marge

  # Partitions des disques amovibles. TRAN est porte par le DISQUE, pas par la
  # partition -> on etablit d'abord la liste des disques amovibles, puis on filtre
  # les partitions par leur PKNAME. HOTPLUG seul ne suffirait pas : les NVMe et
  # les baies SATA hot-swap le rapportent aussi, on ecrirait alors sur un disque
  # interne. La cle d'installation elle-meme n'offre pas de cible : son ESP ne
  # laisse que ~10 Ko libres et l'ISO9660 est en lecture seule -- d'ou l'offre de
  # reformatage (reformat_stick) comme voie principale.
  local usb_disks="" d
  while read -r d; do
    [ -n "$d" ] || continue
    if [ "$(lsblk -dno TRAN "/dev/$d" 2>/dev/null | tr -d ' ')" = "usb" ] \
       || [ "$(lsblk -dno RM "/dev/$d" 2>/dev/null | tr -d ' ')" = "1" ]; then
      usb_disks="$usb_disks $d"
    fi
  done < <(lsblk -dno NAME 2>/dev/null | tr -d ' ')

  local fstype pk type_ target_disk=""
  [ -n "${TARGET:-}" ] && target_disk=$(basename "$TARGET")
  while read -r part type_; do
    [ "$type_" = "part" ] || continue
    fstype=$(lsblk -no FSTYPE "/dev/$part" 2>/dev/null | tr -d ' ')
    case "$fstype" in iso9660|udf|"") continue ;; esac       # RO par conception
    pk=$(lsblk -no PKNAME "/dev/$part" 2>/dev/null | head -1 | tr -d ' ')
    case " $usb_disks " in *" $pk "*) ;; *) continue ;; esac
    # Jamais le disque cible : un die() posterieur au flash ecrirait dans le
    # hassos-boot tout juste installe.
    [ -n "$target_disk" ] && [ "$pk" = "$target_disk" ] && continue
    write_log_to "$part" "$src" "$need"; st=$?
    [ $st -eq 0 ] && { echo "/dev/$part"; return 0; }
    # On retient le diagnostic le plus informatif : "plein" ou "lecture seule"
    # valent mieux que "aucun support", qui laisserait croire a un defaut de
    # detection alors qu'un support a bien ete trouve.
    # 4 (retenu par Ventoy) est le diagnostic le plus actionnable : il prime.
    case $st in 4) rc=4 ;; 2|3) [ "$rc" -eq 4 ] || rc=$st ;; esac
  done < <(lsblk -lno NAME,TYPE 2>/dev/null)

  return $rc
}

# Description lisible d'une partition : "/dev/sdb3 (SanDisk Ultra 32G)".
# Multi-colonnes admis ici : on affiche, on ne relit pas de champs.
describe_part(){
  local p pk info
  p=$(basename "$1")
  pk=$(lsblk -no PKNAME "/dev/$p" 2>/dev/null | head -1 | tr -d ' ')
  info=$(lsblk -dno VENDOR,MODEL,SIZE "/dev/${pk:-$p}" 2>/dev/null | xargs)
  if [ -n "$info" ]; then printf '/dev/%s (%s)' "$p" "$info"
  else                    printf '/dev/%s' "$p"
  fi
}

# Reformate la CLE D'INSTALLATION en une seule partition FAT32 couvrant tout
# l'espace, puis y depose le journal.
#
# Deux problemes resolus d'un coup :
#   - le journal atterrit sur une partition UNIQUE, donc visible partout ;
#     Windows 11 n'expose que la 1re partition d'un support amovible, ce qui
#     rendait invisible une partition dediee ajoutee a l'ISO ;
#   - la cle redevient reutilisable. Windows ne sait pas reformater seul une cle
#     gravee par Etcher (il faut diskpart en PowerShell administrateur), la
#     disposition isohybrid deroutant son outil de formatage.
#
# 'toram' ayant recopie le live en RAM, le media n'est plus monte et peut donc
# etre repartitionne. On le VERIFIE malgre tout avant d'ecrire : au moindre doute
# on renonce SANS RIEN EFFACER, sur une cle qui est peut-etre le seul moyen de
# reessayer.
# Codes : 0 = reformatee | 1 = refus de l'utilisateur
#         2 = renonce AVANT toute ecriture, la cle est intacte
#         3 = echec APRES le debut de l'effacement : la cle n'est plus amorcable
# La distinction 2/3 n'est pas cosmetique : elle decide si l'on peut dire a
# l'utilisateur que sa cle sert encore d'installateur.
reformat_stick(){
  local dev="$1" p mnt=/mnt/newstick
  [ -n "$dev" ] || { logx "reformatage impossible : media de boot non identifie"; return 2; }
  [ -b "/dev/$dev" ] || { logx "reformatage impossible : /dev/$dev absent"; return 2; }
  # JAMAIS un peripherique virtuel : sous Ventoy l'ISO est exposee via
  # device-mapper (/dev/dm-0), et l'effacer reviendrait a ecrire dans les secteurs
  # du fichier ISO sur la cle. to_physical_disk doit avoir remonte au vrai disque ;
  # si ce n'est pas le cas, on renonce.
  case "$dev" in
    dm-*|loop*|md*) logx "reformatage refuse : $dev est un peripherique virtuel"; return 2 ;;
  esac
  # Doit etre un DISQUE entier, pas une partition.
  [ "$(lsblk -dno TYPE "/dev/$dev" 2>/dev/null | tr -d ' ')" = "disk" ] \
    || { logx "reformatage refuse : $dev n'est pas un disque entier"; return 2; }
  # Jamais le disque qu'on vient d'installer.
  [ -n "${TARGET:-}" ] && [ "$dev" = "$(basename "$TARGET")" ] && {
    logx "reformatage refuse : $dev est le disque d'installation"; return 2; }

  # Aucune partition du peripherique ne doit etre montee.
  for p in $(lsblk -lno NAME "/dev/$dev" 2>/dev/null); do
    if findmnt -rn -S "/dev/$p" >/dev/null 2>&1; then
      logx "reformatage impossible : /dev/$p est monte"
      return 2
    fi
  done

  # --defaultno : l'action EFFACE la cle, le bouton par defaut doit donc etre
  # « garder l'installateur ». Valider sans lire ne doit rien detruire.
  wt_yesno "$S_WARN" "$(printf "$S_FMT_ASK" "$(describe_part "/dev/$dev")")" \
    --defaultno --yes-button "$S_FMT_YES" --no-button "$S_FMT_NO" \
    || { logx "reformatage refuse par l'utilisateur"; return 1; }

  # ---- A PARTIR D'ICI LA CLE EST MODIFIEE : tout echec renvoie 3, pas 2. ----
  # 0x0c = FAT32 LBA, demarrage a 1 MiB (alignement).
  wipefs -af "/dev/$dev" 2>>"$LOG" || true
  printf 'label: dos\nstart=2048, type=0c, bootable\n' \
    | sfdisk --quiet --force "/dev/$dev" 2>>"$LOG" || {
        logx "reformatage : sfdisk en echec, cle plus amorcable"; return 3; }
  partprobe "/dev/$dev" 2>>"$LOG" || true; udevadm settle 2>/dev/null || sleep 2

  p=$(lsblk -lno NAME,TYPE "/dev/$dev" 2>/dev/null | awk '$2=="part"{print $1; exit}')
  [ -n "$p" ] || { logx "reformatage : aucune partition apres sfdisk"; return 3; }
  # mkfs.vfat -F 32 formate au-dela de 32 Go, la ou l'outil de Windows refuse.
  mkfs.vfat -F 32 -n "$LOGS_LABEL" "/dev/$p" >/dev/null 2>>"$LOG" || {
      logx "reformatage : mkfs.vfat en echec sur /dev/$p"; return 3; }

  mkdir -p "$mnt"
  mount "/dev/$p" "$mnt" 2>>"$LOG" || { logx "reformatage : montage de /dev/$p impossible"; return 3; }
  cp "$LOG" "$mnt/haos-install-$(date +%Y%m%d-%H%M).log" 2>>"$LOG" || true
  sync; umount "$mnt" 2>>"$LOG" || true
  logx "cle $dev reformatee en FAT32 ($LOGS_LABEL), journal copie"
  return 0
}

# Sauvegarde du journal. Un MENU explicite, et non un enchainement de questions :
# dans la version precedente, atteindre le reformatage imposait de repondre
# "Abandonner" a la question sur la seconde cle -- un bouton qui semblait tout
# arreter alors qu'il donnait acces aux autres solutions. Chaque destination est
# desormais nommee et choisie directement.
save_log(){
  local dest st choice items=()
  [ -s "$LOG" ] || return 0
  wt_yesno "$S_TITLE" "$S_LOG_ASK" || return 0

  # Premiere tentative automatique : si une cle inscriptible est deja la, inutile
  # d'imposer un menu.
  dest=$(try_write_log "$LOG"); st=$?
  if [ $st -eq 0 ]; then
    wt_msg "$S_TITLE" "$(printf "$S_LOG_OK" "$(describe_part "$dest")")"; return 0
  fi
  case $st in
    2) wt_msg "$S_WARN" "$S_LOG_FULL" ;;
    3) wt_msg "$S_WARN" "$S_LOG_RO" ;;
    4) wt_msg "$S_WARN" "$S_LOG_VTOY" ;;   # retenu par dm : instruction precise
  esac

  while true; do
    items=("$S_LOG_M_USB" "$S_LOG_M_USB_D")
    # Le reformatage n'est propose que si l'on a identifie la cle de boot.
    [ -n "${live_dev:-}" ] && items+=("$S_LOG_M_FMT" "$S_LOG_M_FMT_D")
    items+=("$S_LOG_M_SHOW" "$S_LOG_M_SHOW_D" "$S_LOG_M_NONE" "$S_LOG_M_NONE_D")

    choice=$(whiptail --title "$S_TITLE" --menu "$S_LOG_MENU" 20 74 4 \
             "${items[@]}" 3>&1 1>&2 2>&3) || choice="$S_LOG_M_NONE"

    case "$choice" in
      "$S_LOG_M_USB")
        whiptail --title "$S_TITLE" --infobox "$S_LOG_DETECT" 7 62
        udevadm settle 2>/dev/null || sleep 3
        partprobe 2>/dev/null || true; sleep 1
        dest=$(try_write_log "$LOG"); st=$?
        case $st in
          0) wt_msg "$S_TITLE" "$(printf "$S_LOG_OK" "$(describe_part "$dest")")"; return 0 ;;
          2) wt_msg "$S_WARN" "$S_LOG_FULL" ;;
          3) wt_msg "$S_WARN" "$S_LOG_RO" ;;
          4) wt_msg "$S_WARN" "$S_LOG_VTOY" ;;
          *) wt_msg "$S_TITLE" "$S_LOG_RETRY" ;;
        esac ;;
      "$S_LOG_M_FMT")
        reformat_stick "${live_dev:-}"
        case $? in
          0) wt_msg "$S_TITLE" "$(printf "$S_LOG_OK" "$(describe_part "/dev/$live_dev")")"; return 0 ;;
          2) wt_msg "$S_WARN" "$S_FMT_FAIL" ;;
          3) wt_msg "$S_WARN" "$S_FMT_BROKEN" ;;
        esac ;;                                  # 1 = refus, on revient au menu
      "$S_LOG_M_SHOW")
        # Toujours disponible, sans aucun support : wt_msg bascule seul en
        # --scrolltext pour que le journal defile.
        wt_msg "$S_TITLE" "$(cat "$LOG")" ;;
      *) break ;;
    esac
  done
  wt_msg "$S_TITLE" "$(printf "$S_LOG_NONE" "$LOG")"
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
    wt_msg "$S_TITLE" "$(printf "$S_NET_NOWIFI" "$diag")"
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
      || { wt_yesno "$S_TITLE" "$S_NET_QUIT" && die "$S_CANCELLED" || continue; }

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
      WIFI_SSID="$choice"; WIFI_PSK="$psk"   # memorises pour push_wifi_config
      return 0
    fi
    wt_msg "$S_TITLE" \
      "$(printf "$S_NET_FAIL" "$choice" "$(echo "$err" | cut -c1-58 | head -3)")"
  done
}

# ---------------------------------------------------------------------------
# NECESSITE le reseau : en Wi-Fi, rien n'est joignable avant setup_network.
resolve_version(){
  whiptail --title "$S_TITLE" --infobox "$S_VER_FETCH" 7 66

  # Source de verite : le canal stable du Supervisor. L'API GitHub ignore les
  # retrogradations de canal (une release stable peut etre retiree apres coup,
  # cf. HAOS 18.0 et le firmware RPi/Yellow) et proposerait alors une version
  # que Home Assistant ne considere plus courante.
  # jq et non grep : la cle de la carte existe AUSSI sous "homeassistant"
  # (version de HA Core) -> un grep renverrait cette valeur-la.
  HAOS_VERSION=$(curl -fsSL --max-time 15 https://version.home-assistant.io/stable.json 2>>"$LOG" \
    | jq -r --arg b "$HAOS_BOARD" '.hassos[$b] // empty' 2>>"$LOG" || true)
  [[ "$HAOS_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || HAOS_VERSION=""
  VER_SRC="canal stable"

  # Repli : l'API GitHub, qui exclut les pre-releases (RC) par construction.
  # Volontairement laisse en grep : si jq disparaissait de la liste de paquets,
  # l'etape precedente rendrait vide et ce chemin resterait fonctionnel.
  if [ -z "$HAOS_VERSION" ]; then
    HAOS_VERSION=$(curl -fsSL --max-time 15 \
      https://api.github.com/repos/home-assistant/operating-system/releases/latest \
      2>>"$LOG" | grep -oP '"tag_name":\s*"\K[^"]+' || true)
    [[ "$HAOS_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || HAOS_VERSION=""
    VER_SRC="repli API GitHub"
    logx "canal stable injoignable ou muet, repli sur l'API GitHub"
  fi

  # Pas de version en dur en dernier recours : elle ne servirait que si les deux
  # sources etaient injoignables ALORS QUE le telechargement de l'image depuis
  # GitHub fonctionne -- scenario quasi vide. Elle imposerait en revanche d'editer
  # le script et de reconstruire l'ISO a chaque version de HAOS. Echec franc.
  [ -n "$HAOS_VERSION" ] || die "$S_VER_FAIL"

  IMG_URL="https://github.com/home-assistant/operating-system/releases/download/${HAOS_VERSION}/haos_${HAOS_BOARD}-${HAOS_VERSION}.img.xz"
  logx "version resolue : $HAOS_VERSION (carte $HAOS_BOARD, source $VER_SRC)"
  logx "image : $IMG_URL"
  curl -fsI --max-time 15 "$IMG_URL" >/dev/null 2>>"$LOG" \
    || die "$(printf "$S_VER_NOIMG" "$HAOS_VERSION" "$IMG_URL")"
}

# ---------------------------------------------------------------------------
pick_disk(){
  local menu=() name size model tran vendor rm_ hp tag
  # whiptail ne sait pas colorer un item de menu -> marquage textuel en tete.
  # Pas d'eval sur la sortie de lsblk : un champ MODEL contenant un guillemet
  # casserait le parsing. Une colonne a la fois, sinon un champ vide decale les
  # suivants a la lecture.
  while read -r name; do
    [ -n "$name" ] || continue
    [ -n "$live_dev" ] && [ "$name" = "$live_dev" ] && continue   # jamais le media de boot
    # Ceinture et bretelles : tout disque portant un iso9660 (lui-meme ou une de
    # ses partitions) est un media d'installation, jamais une cible. Couvre les
    # gravures ou le LABEL ne serait pas celui attendu (dd d'un autre ISO).
    lsblk -no FSTYPE "/dev/$name" 2>/dev/null | grep -qx iso9660 && continue
    # Cle Ventoy : elle ne porte PAS d'iso9660 (l'ISO est un fichier sur sa
    # partition exFAT, expose via device-mapper), donc le test precedent la
    # laissait passer. Sa 2e partition porte l'etiquette VTOYEFI : signal fiable.
    lsblk -no LABEL "/dev/$name" 2>/dev/null | grep -qix 'VTOYEFI' && continue

    size=$(lsblk -dno SIZE    "/dev/$name" 2>/dev/null | xargs)
    model=$(lsblk -dno MODEL  "/dev/$name" 2>/dev/null | xargs)
    vendor=$(lsblk -dno VENDOR "/dev/$name" 2>/dev/null | xargs)
    tran=$(lsblk -dno TRAN    "/dev/$name" 2>/dev/null | xargs)
    rm_=$(lsblk -dno RM       "/dev/$name" 2>/dev/null | xargs)
    hp=$(lsblk -dno HOTPLUG   "/dev/$name" 2>/dev/null | xargs)

    tag=""
    if [ "${rm_:-0}" = "1" ] || [ "${hp:-0}" = "1" ] || [ "$tran" = "usb" ]; then
      tag="[!! USB / EXTERNE !!] "
      [ "$UI_LANG" = "en" ] && tag="[!! USB / EXTERNAL !!] "
    fi
    menu+=("/dev/$name" "$(printf '%s%-9s %-5s %s' "$tag" "${size:-?}" "${tran:-?}" \
           "$(echo "$vendor ${model:-?}" | xargs)")")
  done < <(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')

  [ ${#menu[@]} -gt 0 ] || die "$S_DISK_NONE"

  TARGET=$(whiptail --title "$S_TITLE" --menu "$S_DISK_PICK" 22 78 8 "${menu[@]}" 3>&1 1>&2 2>&3) \
    || die "$S_CANCELLED"

  # 32 Go : sous ce seuil le dd mourrait "No space left" APRES avoir efface.
  local bytes gb
  bytes=$(blockdev --getsize64 "$TARGET" 2>/dev/null || echo 0)
  gb=$(( bytes / 1000000000 ))
  if [ "$gb" -lt 32 ]; then
    wt_yesno "$S_WARN" "$(printf "$S_DISK_SMALL" "$TARGET" "$gb")" \
      --yes-button "$S_STOP" --no-button "$S_GOON" && die "$S_STOPPED"
  fi

  local content
  content=$(lsblk -no NAME,SIZE,FSTYPE,LABEL "$TARGET" 2>/dev/null | sed 's/^/   /')
  wt_yesno "$S_CONFIRM_T" "$(printf "$S_DISK_CONFIRM" "$TARGET" "$content")" \
    || die "$S_CANCELLED"
  logx "cible confirmee : $(describe_part "$TARGET"), ${gb} Go"
  logx "media du live exclu : ${live_dev:-<non identifie>}"
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
    # --speed-limit/--speed-time : sans eux, une coupure reseau laissait curl
    # attendre selon les temporisations TCP, 'pv -n' reemettre le dernier
    # pourcentage, et la jauge se figer indefiniment -- l'utilisateur ne pouvait
    # pas distinguer "lent" de "mort". Sous 1 Ko/s pendant 30 s, curl abandonne.
    # Pas de --retry ici : sans -C - la reprise recommence a zero et reinjecte les
    # octets dans le flux xz, ce qui le corrompt ; et -C - est inutilisable sur un
    # tube, curl ne pouvant s'y repositionner.
    curl -fSL --speed-limit 1024 --speed-time 30 "$IMG_URL" 2>>"$LOG" \
      | pv -n -s "$dl" 2> >(whiptail --title "$S_TITLE" --gauge \
            "$(printf "$S_WRITING" "$HAOS_VERSION")" 9 72 0 >/dev/tty) \
      | xz -dc 2>>"$LOG" \
      | tee >(sha256sum | cut -d' ' -f1 > /tmp/haos-img.sha256) \
            >(wc -c > /tmp/haos-img.size) \
      | dd of="$TARGET" bs=4M conv=fsync 2>>"$LOG"
  }
  rc=$?
  sync; wait 2>/dev/null || true
  logx "ecriture terminee sur $TARGET (code $rc)"

  if [ $rc -ne 0 ]; then
    die "$(printf "$S_FAIL" "$rc" "$(tail -n 10 "$LOG" 2>/dev/null | cut -c1-66)" "$LOG")"
  fi
}

# ---------------------------------------------------------------------------
# xz valide deja l'integrite du TELECHARGEMENT (sommes de controle du format).
# Ici on valide l'ECRITURE : secteur defaillant, SSD en fin de vie, cable douteux.
verify(){
  local expect size actual i
  # Ces deux fichiers sont ecrits par les substitutions de processus de flash(),
  # que 'wait' ne garantit pas d'attendre selon les versions de bash. Un fichier
  # partiel donnerait une somme tronquee, donc une FAUSSE alerte de disque
  # defaillant : on patiente brievement jusqu'a obtenir des valeurs completes.
  for i in {1..20}; do
    expect=$(tr -d ' \n' < /tmp/haos-img.sha256 2>/dev/null)
    size=$(tr -d ' \n' < /tmp/haos-img.size 2>/dev/null)
    [[ "$expect" =~ ^[0-9a-f]{64}$ ]] && [[ "$size" =~ ^[0-9]+$ ]] && break
    sleep 1
  done

  if ! [[ "$size" =~ ^[0-9]+$ ]] || ! [[ "$expect" =~ ^[0-9a-f]{64}$ ]]; then
    logx "verification impossible : somme ou taille de reference indisponible"
    wt_msg "$S_TITLE" "$S_VFY_SKIP"; return 0
  fi

  wt_yesno "$S_TITLE" \
    "$(printf "$S_VFY_ASK" "$(numfmt --to=iec "$size" 2>/dev/null || echo "$size")" "$TARGET")" \
    || return 0

  # Vider le cache : sinon on relit la RAM, pas le disque -> verification inutile.
  sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

  actual=$(head -c "$size" "$TARGET" 2>>"$LOG" \
    | pv -n -s "$size" 2> >(whiptail --title "$S_TITLE" --gauge "$S_VFY_RUN" 8 68 0 >/dev/tty) \
    | sha256sum | cut -d' ' -f1)

  if [ "$actual" = "$expect" ]; then
    logx "verification OK : sha256 du disque conforme a l'image ($expect)"
    wt_msg "$S_TITLE" "$(printf "$S_VFY_OK" "${expect:0:32}")"
  else
    logx "VERIFICATION EN ECHEC : attendu $expect, lu $actual"
    wt_msg "$S_WARN" \
      "$(printf "$S_VFY_KO" "${expect:0:24}" "${actual:0:24}")"
    die "$S_CANCELLED"
  fi
}

# ---------------------------------------------------------------------------
# Localise le fichier keyfile d'une connexion. nmcli expose connection.filename
# dans les versions recentes ; sinon on le retrouve par son UUID, l'emplacement
# etant deterministe.
nm_profile_path(){
  local uuid="$1" f
  f=$(nmcli -g connection.filename connection show "$uuid" 2>/dev/null | head -1)
  [ -f "$f" ] && { printf '%s' "$f"; return 0; }
  f=$(grep -ls "^uuid=$uuid" /etc/NetworkManager/system-connections/* 2>/dev/null | head -1)
  [ -f "$f" ] && { printf '%s' "$f"; return 0; }
  return 1
}

# Profil ecrit a la main, employe SEULEMENT en repli. key-mgmt derive du
# chiffrement reellement detecte : le forcer a wpa-psk (ancien comportement)
# produit un profil inoperant en WPA3 pur ou sur un reseau ouvert.
# UUID tire au sort mais fixe dans le fichier : sinon l'IP change a chaque boot.
# Fins de ligne UNIX (LF) imperatives.
write_fallback_profile(){
  local dst="$1" km="$2" hidden=""
  nmcli -g 802-11-wireless.hidden connection show "$WIFI_SSID" 2>/dev/null | grep -qi yes \
    && hidden="hidden=true"
  {
    printf '[connection]\n'
    printf 'id=%s\n' "$WIFI_SSID"
    printf 'uuid=%s\n' "$(cat /proc/sys/kernel/random/uuid)"
    printf 'type=802-11-wireless\n\n'
    printf '[802-11-wireless]\n'
    printf 'mode=infrastructure\n'
    printf 'ssid=%s\n' "$WIFI_SSID"
    [ -n "$hidden" ] && printf '%s\n' "$hidden"
    # Reseau ouvert : AUCUNE section de securite, sinon NM refuse le profil.
    if [ -n "$km" ]; then
      printf '\n[802-11-wireless-security]\n'
      printf 'key-mgmt=%s\n' "$km"
      [ "$km" = "wpa-psk" ] && printf 'auth-alg=open\n'
      printf 'psk=%s\n' "$WIFI_PSK"
    fi
    printf '\n[ipv4]\nmethod=auto\n\n'
    printf '[ipv6]\naddr-gen-mode=stable-privacy\nmethod=auto\n'
  } > "$dst" 2>>"$LOG"
}

# Installation en Wi-Fi : HAOS oublie tout au premier boot et attend un reseau.
# On lui depose un profil NetworkManager dans CONFIG/network/my-network de la
# partition hassos-boot (FAT), que HAOS importe au demarrage.
#
# On COPIE le profil que NM a deja ecrit, au lieu de le reconstruire : son
# key-mgmt est juste par construction (WPA2, WPA3 pur/SAE, OWE, WEP, ouvert) et
# il embarque SSID cache, IP fixe et tout ce que l'utilisateur a regle. Le motif
# invoque autrefois pour le reecrire -- "interface-name verrouille le profil sur
# la carte du live" -- se corrige directement en vidant cette propriete.
# Cela couvre aussi le parcours nmtui, qui n'injectait RIEN auparavant : le
# garde portait sur WIFI_SSID, jamais renseigne par ce chemin.
#
# Codes de retour :
#   0 = injecte | 1 = echec technique | 2 = refus delibere | 3 = rien a faire
push_wifi_config(){
  local uuid part src km mnt=/mnt/hassos-boot dst
  # Connexion Wi-Fi active, quel qu'ait ete son mode de creation.
  uuid=$(active_wifi_uuid)
  [ -n "$uuid" ] || return 3                   # installation filaire : rien a faire

  # Parcours nmtui : WIFI_SSID n'a jamais ete renseigne. On le recupere pour
  # l'AFFICHAGE du message final (le journal, lui, ne le porte pas).
  [ -n "${WIFI_SSID:-}" ] \
    || WIFI_SSID=$(nmcli -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null | head -1)

  # hassos-boot = 1re partition de l'image ecrite (label hassos-boot, sinon p1)
  partprobe "$TARGET" 2>>"$LOG" || true; sleep 1
  part=$(lsblk -nro NAME,LABEL "$TARGET" 2>/dev/null | awk '$2=="hassos-boot"{print $1; exit}')
  [ -n "$part" ] || part=$(lsblk -nro NAME "$TARGET" 2>/dev/null | sed -n '2p')
  [ -n "$part" ] || return 1

  # Delier le profil de l'interface du live AVANT de le lire : NM reecrit alors
  # le fichier sur disque. Sans cela HAOS ne l'activerait sur aucune carte.
  nmcli connection modify "$uuid" connection.interface-name "" >/dev/null 2>&1 || true

  km=$(nmcli -g 802-11-wireless-security.key-mgmt connection show "$uuid" 2>/dev/null)
  src=$(nm_profile_path "$uuid") || src=""

  # Refus delibere : un profil referencant des FICHIERS de certificats ne peut
  # pas fonctionner sous HAOS, ces chemins n'y existant pas. Mieux vaut ne rien
  # ecrire que promettre un reseau qui ne montera jamais. Un PEAP/MSCHAPv2 sans
  # certificat, mot de passe stocke, se copie et fonctionne : ne pas le refuser.
  if [ -n "$src" ] && grep -qE '^[[:space:]]*(ca-cert|client-cert|private-key|ca-path)=' "$src"; then
    logx "profil Wi-Fi NON injecte : 802.1X a certificats, fichiers absents sous HAOS"
    return 2
  fi

  mkdir -p "$mnt"
  mount "/dev/$part" "$mnt" 2>>"$LOG" || return 1
  mkdir -p "$mnt/CONFIG/network"
  dst="$mnt/CONFIG/network/my-network"

  # Le secret doit etre DANS le fichier : s'il est gere par un agent, le profil
  # copie serait muet cote HAOS -> on bascule sur le repli.
  local copied=1
  if [ -n "$src" ]; then
    case "$km" in
      wpa-psk|sae) grep -q '^[[:space:]]*psk=' "$src" || src="" ;;
    esac
  fi
  if [ -n "$src" ]; then
    # Retirer les cles propres a CETTE machine : interface-name (ceinture et
    # bretelles si le modify n'a pas pris) et permissions, qui lierait le profil
    # a un compte utilisateur inexistant sous HAOS.
    grep -vE '^[[:space:]]*(interface-name|permissions)=' "$src" > "$dst" 2>>"$LOG" && copied=0
  fi

  if [ "$copied" -ne 0 ]; then
    # Repli : necessite le parcours guide (SSID et PSK connus).
    if [ -z "${WIFI_SSID:-}" ] || [ -z "${WIFI_PSK:-}" ]; then
      logx "profil Wi-Fi NON injecte : profil NM illisible et aucun secret memorise"
      sync; umount "$mnt" 2>>"$LOG" || true
      return 2
    fi
    case "$km" in
      none|wpa-eap|wpa-eap-suite-b-192)
        # WEP et entreprise : ne pas deviner un format qu'on ne maitrise pas.
        logx "profil Wi-Fi NON injecte : key-mgmt=$km non gere par le repli"
        sync; umount "$mnt" 2>>"$LOG" || true
        return 2 ;;
    esac
    logx "profil Wi-Fi : repli sur un profil ecrit a la main (key-mgmt=${km:-aucun})"
    write_fallback_profile "$dst" "$km"
  else
    logx "profil Wi-Fi : profil NetworkManager copie (key-mgmt=${km:-aucun})"
  fi

  # Controler AVANT de demonter : apres umount le point de montage est vide et le
  # test serait toujours faux -- c'est ce qui faisait annoncer un succes meme
  # quand l'ecriture du keyfile avait echoue.
  local ok=1
  [ -s "$mnt/CONFIG/network/my-network" ] && ok=0
  sync; umount "$mnt" 2>>"$LOG" || true
  return $ok
}

# ---------------------------------------------------------------------------
finalize(){
  # Installation Wi-Fi : injecter le profil pour que HAOS se reconnecte seul.
  # Plus de garde sur WIFI_SSID : push_wifi_config detecte elle-meme la connexion
  # Wi-Fi active et sort proprement en filaire. C'est ce qui couvre nmtui.
  # Journalise le resultat sans le SSID : c'est le SUCCES de l'injection qui
  # compte pour un diagnostic, pas le nom du reseau.
  local wifi_rc
  push_wifi_config; wifi_rc=$?
  case $wifi_rc in
    3) : ;;                                    # filaire : rien a dire
    0) logx "profil Wi-Fi injecte dans CONFIG/network de hassos-boot"
       wt_msg "$S_TITLE" "$(printf "$S_WIFI_PUSH" "${WIFI_SSID:-Wi-Fi}")" ;;
    2) wt_msg "$S_WARN" "$S_WIFI_PUSH_SKIP" ;; # refus delibere, deja journalise
    *) logx "ECHEC de l'injection du profil Wi-Fi : HAOS demarrera sans reseau"
       wt_msg "$S_WARN" "$S_WIFI_PUSH_FAIL" ;;
  esac

  # L'image contient deja \EFI\BOOT\bootx64.efi ; filet pour firmwares capricieux.
  if command -v efibootmgr >/dev/null && [ -d /sys/firmware/efi ]; then
    # Purger les entrees laissees par de precedentes installations sur ce
    # meme disque (sinon efibootmgr --create en accumule une a chaque essai).
    local partuuid bootnum
    for partuuid in $(lsblk -no PARTUUID "$TARGET" 2>>"$LOG"); do
      [ -n "$partuuid" ] || continue
      while read -r bootnum; do
        [ -n "$bootnum" ] && efibootmgr -b "$bootnum" -B >/dev/null 2>>"$LOG" || true
      done < <(efibootmgr -v 2>/dev/null \
        | grep -i "$partuuid" \
        | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\).*/\1/p')
    done
    efibootmgr --create --disk "$TARGET" --part 1 \
      --label "HAOS" --loader '\EFI\BOOT\bootx64.efi' >/dev/null 2>&1 || true
    logx "entree UEFI 'HAOS' recreee sur $TARGET"
  fi

  # Proposer le reformatage AVANT de demander le retrait de la cle : c'est le
  # dernier moment ou elle est encore branchee. On n'annonce le resultat que s'il
  # a reellement eu lieu, sinon le message mentirait.
  logx "installation terminee avec succes sur $TARGET"
  local logmsg="" fmt_rc
  reformat_stick "${live_dev:-}"; fmt_rc=$?
  case $fmt_rc in
    0) logmsg="$S_DONE_LOG" ;;
    2) wt_msg "$S_WARN" "$S_FMT_FAIL" ;;     # cle intacte
    3) wt_msg "$S_WARN" "$S_FMT_BROKEN" ;;   # cle plus amorcable : le dire
                                             # 1 = refus assume, rien a dire
  esac

  # 'toram' a recopie le live en RAM : la cle n'est plus utilisee, on peut donc
  # demander son retrait MAINTENANT. Le reboot part alors directement sur HAOS,
  # sans risque de relancer l'installateur ni de retirer la cle trop tot.
  wt_msg "$S_TITLE" "$(printf "$S_DONE" "$TARGET")$logmsg"
  clear; reboot
}

# ---------------------------------------------------------------------------
HAOS_BOARD="generic-x86-64"   # cle du canal stable ET nom de l'image : gardes en phase
# ISO_LABEL est pose par build-iso.sh (--iso-volume) : garder les deux fichiers en
# phase. Il sert a reconnaitre le media de boot, 'toram' ayant remplace
# /run/live/medium par un tmpfs. LOGS_LABEL est l'etiquette donnee a la cle si
# l'utilisateur accepte son reformatage en fin d'installation.
ISO_LABEL="HAOS Installer"
LOGS_LABEL="HAOS_LOGS"
HAOS_VERSION=""
VER_SRC=""                    # source retenue pour la version : trace dans le journal
IMG_URL=""
TARGET=""
WIFI_SSID=""
WIFI_PSK=""
# Disque du live, a exclure des cibles. PIEGE : 'toram' (voir --bootappend-live
# dans build-iso.sh) recopie le media en RAM et remplace /run/live/medium par un
# tmpfs -- findmnt y renvoie donc "tmpfs" et non un peripherique. On identifie
# donc le media par le LABEL que build-iso.sh a pose (--iso-volume), en remontant
# au disque parent si la correspondance tombe sur une partition.
# Remonte d'un nom de peripherique au DISQUE PHYSIQUE qui le porte.
# Indispensable sous Ventoy : celui-ci n'expose pas la partition de la cle mais un
# peripherique device-mapper (/dev/dm-0) dont le contenu est l'ISO. C'est donc
# dm-0 que blkid trouve, un nom qui ne correspond a aucun disque -- l'exclusion
# de pick_disk ne s'appliquait pas et la CLE VENTOY ETAIT PROPOSEE COMME CIBLE
# D'INSTALLATION. /sys/block/dm-N/slaves/ donne le peripherique sous-jacent.
to_physical_disk(){
  local n s pk
  n=$(basename "${1:-}")
  [ -n "$n" ] || return 1
  case "$n" in
    dm-*|md*)
      for s in "/sys/block/$n/slaves/"*; do
        [ -e "$s" ] || continue
        # Recursif : un empilement dm sur dm reste possible.
        to_physical_disk "$(basename "$s")" && return 0
      done
      return 1 ;;
    loop*)
      # Le fichier de sauvegarde ne dit pas sur quel disque il se trouve : on
      # renonce plutot que de deviner.
      return 1 ;;
  esac
  pk=$(lsblk -no PKNAME "/dev/$n" 2>/dev/null | head -1 | tr -d ' ')
  printf '%s' "${pk:-$n}"
}

resolve_live_dev(){
  local hit d src
  hit=$(blkid -L "$ISO_LABEL" 2>/dev/null)
  if [ -n "$hit" ]; then
    d=$(to_physical_disk "$hit") && [ -n "$d" ] && { printf '%s' "$d"; return 0; }
  fi
  # Repli historique : valable si un jour 'toram' disparait du bootappend.
  src=$(findmnt -no SOURCE /run/live/medium 2>/dev/null || true)
  case "$src" in
    /dev/*) to_physical_disk "$src" || printf '' ;;
    *)      printf '' ;;
  esac
}
live_dev=$(resolve_live_dev)

set_strings                 # defauts FR, remplaces par le choix de l'ecran 1
choose_lang_keyboard
# Etat des prerequis dans le journal : c'est la premiere chose a regarder quand
# HAOS ne demarre pas apres une installation pourtant reussie.
logx "installateur demarre -- langue $UI_LANG, carte $HAOS_BOARD"
logx "demarrage : $(boot_status) | Secure Boot : $(secureboot_status)"
wt_msg "$S_TITLE" \
  "$(printf "$S_WELCOME" "$(boot_status)" "$(secureboot_status)")"
setup_network
log_active_net              # apres setup_network : couvre tous ses points de sortie
resolve_version             # NECESSITE le reseau : doit rester apres setup_network
pick_disk
flash
verify
finalize
