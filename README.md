# haos-netinstall — installer Home Assistant OS sur un PC, sans ligne de commande

Clé USB bootable qui installe **Home Assistant OS** sur un PC via un assistant
guidé : réglage du réseau (Ethernet ou Wi-Fi), choix du disque, téléchargement et
écriture de l'image officielle. Aucune commande à taper.

L'ISO ne contient **pas** HAOS : l'image est téléchargée pendant l'installation
(approche « netinstall »). Il reste donc petit (**~450 Mo**) et installe toujours
la **dernière version** publiée de Home Assistant OS.

## ⚠️ À LIRE AVANT TOUT

> ### Cet outil EFFACE INTÉGRALEMENT le disque que vous sélectionnez.
>
> Aucune récupération n'est possible. À utiliser sur une machine **dédiée**,
> **sans aucune donnée à conserver**.

**Livré tel quel, sans aucune garantie ni support.**

- Projet **personnel**, publié dans l'espoir qu'il serve. Rien de plus.
- **Aucun support n'est assuré.** Pas d'assistance à l'installation, pas de
  garantie de réponse aux issues, pas d'engagement de correction, pas de
  maintenance dans la durée, pas d'engagement de compatibilité matérielle.
- **Aucune responsabilité** n'est acceptée en cas de perte de données, de
  matériel inutilisable ou de tout autre dommage. Voir [LICENSE](LICENSE).
- **Ce projet ne convient pas ? Forkez-le.** C'est une licence MIT, c'est fait
  pour. Vous êtes libre de le modifier, l'améliorer, le redistribuer et le
  maintenir à votre façon, sans rien demander à personne.

En utilisant cet outil, vous acceptez d'en assumer seul les conséquences.

**Projet non officiel** — sans affiliation avec l'Open Home Foundation, Nabu Casa
ni le projet Home Assistant, et ni approuvé ni soutenu par eux. La méthode
officiellement supportée est décrite
[ici](https://www.home-assistant.io/installation/generic-x86-64/). Pour tout
problème concernant **Home Assistant lui-même**, adressez-vous à la communauté
Home Assistant — pas à ce dépôt.

---

# Partie 1 — Installer Home Assistant (utilisateurs)

## Ce qu'il vous faut

- Un PC **dédié** à Home Assistant — **son disque sera entièrement effacé**
- **32 Go de disque** minimum, **2 Go de RAM** minimum
- Une **clé USB** de 1 Go ou plus (son contenu sera effacé)
- Un **câble Ethernet** — recommandé ; le Wi-Fi est proposé en secours

## Étape 1 — Télécharger l'ISO

**[⬇️ Télécharger la dernière version](https://github.com/PocketFR/haos-netinstall/releases/latest)**

Prenez le fichier `.iso` dans la section *Assets*. Le fichier `.sha256` à côté
permet de vérifier que le téléchargement n'est pas corrompu (facultatif) :

```bash
sha256sum -c haos-netinstall-*.iso.sha256
```

## Étape 2 — Écrire l'ISO sur la clé USB

Avec l'un de ces outils, au choix :

- **[Balena Etcher](https://etcher.balena.io/)** — le plus simple, Windows/macOS/Linux
- **[Rufus](https://rufus.ie/)** — Windows
- **[Ventoy](https://www.ventoy.net/)** — copier simplement le `.iso` sur la clé
- **Linux, en ligne de commande** :
  ```bash
  sudo dd if=haos-netinstall-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
  ```
  ⚠️ Vérifiez `/dev/sdX` avec `lsblk` — une erreur ici efface le mauvais disque.

## Étape 3 — Régler le BIOS/UEFI du PC

C'est **l'étape sur laquelle tout le monde trébuche**. Allumez le PC et appuyez
aussitôt sur `Suppr`, `F2`, `F10` ou `Échap` (selon la marque) :

1. **Mode de démarrage : UEFI** — pas « Legacy », pas « CSM »
2. **Secure Boot : DÉSACTIVÉ** ← *obligatoire, Home Assistant ne démarre pas sinon*
3. **Clé USB en premier** dans l'ordre de démarrage
4. Enregistrer et quitter (`F10`)

## Étape 4 — Installer

Branchez la clé, démarrez. L'assistant se lance tout seul :

1. Écran d'accueil et rappels
2. Disposition du clavier
3. Connexion réseau — automatique en Ethernet, sinon sélection du Wi-Fi
4. **Choix du disque** — vérifiez la taille et le modèle ; le contenu actuel est
   affiché avant confirmation
5. Téléchargement et écriture (barre de progression) — **ne pas éteindre le PC**
6. **Retirez la clé USB**, puis validez : le PC redémarre directement sur Home
   Assistant. L'installateur est chargé en mémoire, la clé ne sert plus à rien
   à cette étape.

Des lignes de texte défilent au démarrage : c'est normal, ce n'est pas planté.

## Étape 5 — Premier démarrage

Laissez le câble réseau branché et **patientez 2 à 5 minutes** : Home Assistant
finalise son installation, l'écran peut sembler figé. Puis, depuis un autre
appareil du même réseau :

```
http://homeassistant.local
```

Si l'adresse ne répond pas, utilisez l'adresse IP affichée à l'écran du PC :
`http://<adresse-ip>`

> Depuis Home Assistant Core 2026.8, les nouvelles installations écoutent sur le
> port 80 et non plus sur 8123. Si votre installation date d'avant, ajoutez
> `:8123` à l'adresse.

## En cas de problème

| Symptôme | Cause probable |
|---|---|
| La clé ne démarre pas | Secure Boot encore actif, ou mode Legacy/CSM au lieu d'UEFI |
| Home Assistant ne démarre pas après l'installation | Secure Boot encore actif ; sur PC physique, mode SATA en RAID/Intel RST au lieu d'**AHCI** |
| Wi-Fi OK pendant l'install mais HA hors-ligne ensuite | La carte Wi-Fi n'est pas embarquée par Home Assistant OS (couverture firmware plus restreinte que l'installateur). Utilisez l'Ethernet. |
| Installation échouée | Un journal est écrit dans `/tmp/haos-install.log`, copié sur la partition `HAOS_LOGS` de la clé, et affichable à l'écran |

**Couverture Wi-Fi** : Intel, Realtek, Atheros et Broadcom. L'Ethernet reste le
chemin fiable. Le journal d'installation indique le pilote exact de votre carte
et le `key-mgmt` utilisé : c'est ce qu'il faut regarder si Home Assistant reste
hors-ligne.

**Report du Wi-Fi vers Home Assistant** — l'assistant copie dans l'image le
profil réseau que vous venez d'utiliser, y compris s'il a été créé par la
configuration manuelle (`nmtui`) : SSID caché, IP fixe et WPA3 sont donc
repris tels quels. Deux exceptions, signalées à l'écran plutôt que passées sous
silence : un réseau **d'entreprise à certificats** (802.1X avec fichiers de
certificats) n'est pas reportable, ces fichiers n'existant pas dans Home
Assistant ; et un profil dont le mot de passe n'est pas stocké dans le fichier
ne peut pas l'être non plus. Dans ces cas rien n'est écrit — mieux vaut cela
qu'un réseau qui ne monte jamais — et la configuration se fait ensuite depuis la
console de Home Assistant, ou par câble Ethernet.

### Statut des tests

| | |
|---|---|
| Proxmox (q35 + OVMF, Secure Boot désactivé) | ✅ |
| PC physique (Dell Inspiron, Wi-Fi) | ✅ |
| Hyper-V / VirtualBox | ❌ non pertinent — voir les notes techniques |

---

# Partie 2 — Construire l'ISO soi-même (utilisateurs avancés)

Inutile si vous avez téléchargé l'ISO ci-dessus. Utile pour auditer, modifier ou
adapter l'installateur.

| Fichier | Rôle |
|---|---|
| `build-iso.sh` | Construit l'ISO (à lancer sur une machine de build) |
| `haos-installer.sh` | L'assistant, embarqué dans l'ISO et lancé au boot |

## 1. Où construire

`live-build` a besoin de `chroot`, de périphériques `loop` et de montages
`/proc`, `/sys`, `/dev`. Cela conditionne l'environnement.

| Environnement | Verdict |
|---|---|
| **VM Debian** (sur Proxmox) | ✅ **Recommandé** — isolé, jetable, rien à nettoyer |
| Hôte Proxmox directement | ⚠️ Techniquement possible (c'est une Debian) mais **déconseillé** : installe des paquets et laisse des montages orphelins en cas d'échec, sur l'hyperviseur de prod |
| LXC **non privilégié** | ❌ Ne marche pas (pas de `loop`, `debootstrap` bloqué) |
| LXC **privilégié** | ⚠️ Possible avec `nesting=1`, `fuse=1` et accès `loop` — fragile |
| Ubuntu / Debian physique | ✅ Fonctionne aussi |
| GitHub Actions | ✅ Voir `.github/workflows/build-iso.yml` (conteneur Debian privilégié) |

> **Pas besoin d'une distribution particulière** : n'importe quelle Debian ou
> Ubuntu récente convient. La seule vraie contrainte est `debootstrap` (§2.2).

Une VM de build minimale : **2 vCPU**, **4 Go RAM**, **20 Go de disque**, accès
Internet (miroirs Debian + GitHub).

## 2. Construire

### 2.1 Prérequis

```bash
sudo apt update
sudo apt install live-build
```

### 2.2 Vérifier la cible

`build-iso.sh` construit une **Debian 13 (trixie)**. Le `debootstrap` local doit
la connaître :

```bash
ls /usr/share/debootstrap/scripts/ | grep trixie
```

- **Rien ne s'affiche** (typique sur Debian 12 / Proxmox VE 8) → soit remplacer
  `--distribution trixie` par `--distribution bookworm` dans `build-iso.sh`, soit
  installer un `debootstrap` récent depuis backports.
- **`trixie` apparaît** (Debian 13 / Proxmox VE 9) → rien à faire.

### 2.3 Lancer

Les deux scripts dans un même dossier, puis :

```bash
chmod +x build-iso.sh
sudo ./build-iso.sh
```

Le build prend **15 à 40 minutes** et produit
`haos-installer-iso/live-image-amd64.hybrid.iso` (~450 Mo). Le script repart d'un
dossier propre à chaque exécution.

Les timeouts de boot appliqués s'affichent **dès les premières secondes** : si la
liste est vide, inutile d'attendre la fin.

### 2.4 En cas de problème

```bash
cd haos-installer-iso
sudo lb clean --purge            # nettoyage complet avant de relancer
mount | grep haos-installer-iso  # montages orphelins après une interruption ?
```

## 3. Tester sans clé USB

Sur Proxmox, une VM de test :

- **BIOS : OVMF (UEFI)** — obligatoire
- **Machine : q35**
- **EFI Disk sans « Pre-Enroll keys »** — sinon Secure Boot rejette HAOS
  (`Access Denied` sur `bootx64.efi`)
- Un disque de **32 Go minimum**

Cela valide l'assistant, la sélection du disque, le téléchargement et l'écriture.
Le **Wi-Fi**, lui, exige une machine physique.

## 4. Personnalisation

**Résolution de la version** — après la configuration réseau,
`resolve_version()` interroge le canal stable de Home Assistant
(`version.home-assistant.io/stable.json`, clé `hassos` de la carte
`generic-x86-64`). C'est la même source que le Supervisor : elle reflète les
rétrogradations de canal, contrairement à l'API GitHub qui sert de repli si
elle est injoignable. Si les deux échouent, l'installation s'arrête sur une
erreur explicite : aucune version n'est codée en dur. C'est délibéré — une
constante de repli n'aiderait que si les deux sources étaient injoignables
*alors que* le téléchargement de l'image fonctionne, et il faudrait la
rafraîchir à chaque version de HAOS.

**Figer une version de HAOS** — remplacer le corps de `resolve_version()` par
un `HAOS_VERSION` en dur ; `IMG_URL` s'en déduit automatiquement.

**Ajouter des paquets** — bloc `config/package-lists/haos.list.chroot` de
`build-iso.sh`. Chaque paquet alourdit l'ISO.

**Couverture matérielle plus large** — remastériser une **Ubuntu** avec
[Cubic](https://github.com/PJ-Singh-001/Cubic) et y injecter `haos-installer.sh`,
réutilisable tel quel.

## 5. Notes techniques

- **Pourquoi pas l'installateur Debian (d-i) ?** HAOS est une image disque
  complète (GPT + partitions système A/B), pas un ensemble de paquets. `d-i` sait
  partitionner et installer une Debian, pas écrire une image brute. D'où le choix
  d'un live minimal + assistant maison.
- **Pourquoi pas en machine virtuelle ?** Home Assistant fournit des images
  **dédiées** aux hyperviseurs (build `haos_ova` : `.qcow2`, `.vmdk`, `.vhdx`,
  `.vdi`, `.ova`). Cet ISO écrit l'image `generic-x86-64`, prévue pour le
  bare-metal. Utilisez l'artefact officiel de votre hyperviseur.
  Cas particulier fréquent : un hyperviseur qui n'accepte que des ISO **à la
  création** d'une VM — Synology VMM, typiquement. La restriction ne vaut que
  pour la création : à l'**import**, VMM accepte les images disque
  (`.img`, `.vmdk`, `.vdi`, `.vhd`, `.vhdx`, `.qcow2`). Importez donc
  `haos_ova-*` plutôt que de passer par un installateur.
- **Matériel sans UEFI** — HAOS impose UEFI et GPT : c'est une contrainte de
  l'image officielle, pas de cet ISO. Sur une machine qui ne sait démarrer
  qu'en Legacy/CSM, aucune installation de HAOS n'est possible. La seule
  alternative est une installation *Supervised* sur Debian, méthode nettement
  moins supportée par Home Assistant (bandeau « unsupported » dès que l'OS
  dévie, maintenance du système à votre charge).
- **Mac Apple Silicon — ne pas essayer.** Ces machines n'ont pas d'UEFI (chaîne
  iBoot propre à Apple), leur SSD interne n'est pas un NVMe standard, et le
  noyau de HAOS n'embarque aucun pilote Apple Silicon. Surtout : effacer
  intégralement le disque ôte au Mac sa capacité à démarrer quoi que ce soit,
  la récupération passant par un restore en DFU depuis un autre Mac. Pour
  faire tourner HAOS sur un Mac ARM, utilisez une VM (UTM) et l'image
  `haos_generic-aarch64` — sans cet ISO, qui est amd64.
- **Journal d'installation** — l'ISO embarque une petite partition FAT
  étiquetée `HAOS_LOGS` qui reçoit le journal, que l'installation ait réussi ou
  échoué. En cas de succès la copie est **silencieuse** : aucun écran de plus,
  le journal est simplement là si vous en avez besoin. Le journal trace les
  décisions (version retenue et sa source, disque cible, résultat de la
  vérification, état UEFI/Secure Boot) et ne contient jamais le mot de passe
  Wi-Fi. Cette partition existe parce que l'ESP de la clé ne laisse que ~10 Ko
  libres, très insuffisant.
  Elle n'apparaît que si la clé a été écrite en mode brut (`dd`, Etcher, Rufus
  en mode DD) : sous Ventoy ou Rufus en mode ISO, l'ISO est montée en boucle et
  la partition ne devient jamais un périphérique. Sur un échec, l'assistant
  propose alors de brancher une autre clé, puis d'afficher le journal à l'écran
  pour le photographier.

  > **Windows 11 ne montera pas cette partition tout seul.** Il n'expose que la
  > **première** partition d'un support amovible — Windows 10 savait en gérer
  > plusieurs depuis la Creators Update, Windows 11 est revenu en arrière. Il
  > faut donc lui attribuer une lettre dans *Gestion des disques*
  > (`diskmgmt.msc`). Linux et macOS la montent directement.
  > Ce n'est pas contournable côté ISO : la première partition doit contenir le
  > système de fichiers ISO9660 pour l'amorçage BIOS, les journaux ne peuvent
  > donc pas y être placés.
- **Partition de données** — inutile de l'agrandir : HAOS étend automatiquement
  sa partition `hassos-data` à la taille du disque au premier démarrage.
- **Effacement préalable** — l'assistant vide les signatures et les tables GPT
  (début et fin du disque) avant écriture. Délibéré : sur un disque portant un
  ancien OS, le redimensionnement automatique de HAOS peut échouer.
- **Secure Boot** — HAOS ne le prend pas en charge. Le désactiver étant de toute
  façon nécessaire, l'ISO n'a pas besoin d'être signé.
- **Firmware embarqués** — seuls les firmwares **réseau** sont inclus (Realtek,
  Intel, Atheros, Broadcom). `--firmware-chroot` est désactivé : sinon
  `live-build` embarque tous les paquets `firmware-*` de l'archive, dont les
  blobs GPU/audio inutiles à un installateur en mode texte (851 Mo → 450 Mo).
  ⚠️ `firmware-realtek` fournit aussi les blobs **Ethernet** Gigabit
  (`rtl_nic/rtl8168*`) : ne pas le retirer en croyant ne couper que le Wi-Fi.
- **Timeout de boot** — les modèles `live-build` n'en définissent aucun pour GRUB,
  et `timeout 0` signifie « attendre indéfiniment » pour isolinux. Le menu restant
  invisible sur certains écrans, `build-iso.sh` force `timeout=1` +
  `timeout_style=hidden` via `config/bootloaders/`.
- **`toram`** — le live est copié en RAM au démarrage : la clé USB peut être
  retirée à tout moment. Coût : démarrage plus long (~450 Mo à copier) et ~2 Go de
  RAM. Retirer `toram` du `--bootappend-live` sur les machines très peu dotées.
- **Pas de `quiet`** — le log noyau défile volontairement, comme le fait HAOS
  lui-même : c'est le seul signe de vie pendant l'attente, et un écran exploitable
  en cas de rapport de bogue.
- **Pré-configuration Wi-Fi (installation sans fil)** — après écriture, si
  l'installation s'est faite en Wi-Fi, l'assistant dépose un profil NetworkManager
  dans `CONFIG/network/my-network` de la partition `hassos-boot`, que HAOS importe
  au premier démarrage (profil minimal, **sans `interface-name`** : ce champ,
  copié tel quel depuis le live, verrouille le profil sur une carte inexistante
  côté HAOS). **Limite importante :** cela ne fonctionne que si la carte Wi-Fi est
  prise en charge par HAOS. Sa couverture firmware est plus restreinte que celle
  de l'installateur (basé sur Debian) : une carte qui fonctionne pendant l'install
  peut être absente sous HAOS (`Direct firmware load ... failed`). Il n'existe
  **aucun moyen d'injecter le firmware manquant depuis l'installateur** — HAOS
  n'utilise pas d'initrd, le pilote se charge trop tôt pour qu'un firmware déposé
  après coup soit lu. La seule voie est de faire ajouter le firmware au paquet
  `linux-firmware` de HAOS (en amont, à la construction de l'image). L'Ethernet
  reste donc recommandé.

---

## Licence

[MIT](LICENSE) pour les scripts de ce dépôt.

Debian, les firmwares non-libres et Home Assistant OS restent soumis à leurs
licences respectives — voir les précisions dans le fichier [LICENSE](LICENSE).

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). Les issues documentent les problèmes ;
elles ne constituent pas une file de support.

## Sources

- [Home Assistant — Generic x86-64 installation](https://www.home-assistant.io/installation/generic-x86-64/)
- [Home Assistant OS — releases](https://github.com/home-assistant/operating-system/releases)
- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/)
