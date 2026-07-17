# haos-netinstall — ISO d'installation Home Assistant OS (bare-metal)

ISO live auto-démarrant qui installe **Home Assistant OS** sur un PC via un
assistant guidé : configuration réseau/Wi-Fi, sélection du disque, téléchargement
et écriture de l'image officielle. Aucune ligne de commande côté utilisateur final.

L'ISO ne contient **pas** HAOS : l'image est téléchargée au moment de
l'installation (approche « netinstall »). L'ISO reste petit (**~450 Mo**) et
installe toujours la dernière version publiée.

---

## ⚠️ À LIRE AVANT TOUT

> ### Cet outil EFFACE INTÉGRALEMENT le disque que vous sélectionnez.
>
> Aucune récupération n'est possible. Utilisez-le sur une machine **dédiée**,
> **sans aucune donnée à conserver**.

**Livré tel quel, sans aucune garantie ni support.**

- Projet **personnel**, publié dans l'espoir qu'il serve. Rien de plus.
- **Aucun support n'est assuré.** Pas d'assistance à l'installation, pas de
  garantie de réponse aux issues, pas d'engagement de correction, pas de
  maintenance dans la durée, pas d'engagement de compatibilité matérielle.
- **Aucune responsabilité** n'est acceptée en cas de perte de données, de
  matériel inutilisable ou de tout autre dommage. Voir [LICENSE](LICENSE).
- Les issues sont ouvertes et peuvent servir à documenter des problèmes pour
  les autres. Elles ne constituent pas une file de support.
- **Ce projet ne convient pas ? Forkez-le.** C'est une licence MIT, c'est fait
  pour. Vous êtes libre de le modifier, l'améliorer, le redistribuer et le
  maintenir à votre façon, sans rien demander à personne. Les fork utiles seront
  volontiers signalés ici.

En utilisant cet outil, vous acceptez d'en assumer seul les conséquences.

### Projet non officiel

Ce projet **n'est pas affilié** à l'Open Home Foundation, à Nabu Casa ni au
projet Home Assistant, et n'est ni approuvé ni soutenu par eux. « Home Assistant »
est une marque de ses détenteurs respectifs.

La méthode d'installation **officiellement supportée** est décrite ici :
[Generic x86-64 installation](https://www.home-assistant.io/installation/generic-x86-64/).
En cas de problème avec Home Assistant lui-même, adressez-vous à la communauté
Home Assistant — **pas** à ce dépôt.

### Statut

| | |
|---|---|
| Testé sur Proxmox (q35 + OVMF) | ✅ |
| Testé sur PC physique | ✅ sur Dell Inspiron |
| Couverture Wi-Fi | Intel, Realtek, Atheros, Broadcom uniquement |

---

**Fichiers**
| Fichier | Rôle |
|---|---|
| `build-iso.sh` | Construit l'ISO (à lancer sur une machine de build) |
| `haos-installer.sh` | L'assistant, embarqué dans l'ISO et lancé au boot |

---

## 1. Où construire l'ISO ?

`live-build` a besoin de `chroot`, de périphériques `loop` et de montages
`/proc`, `/sys`, `/dev`. Cela conditionne l'environnement de build.

| Environnement | Verdict |
|---|---|
| **VM Debian** | ✅ **Recommandé** — isolé, jetable, rien à nettoyer |
| Hôte Proxmox directement | ⚠️ Techniquement possible (c'est une Debian) mais **déconseillé** : installe des paquets et laisse des montages orphelins en cas d'échec, sur l'hyperviseur de prod |
| LXC **non privilégié** | ❌ Ne marche pas (pas de `loop`, `debootstrap` bloqué) |
| LXC **privilégié** | ⚠️ Possible avec `nesting=1`, `fuse=1` et accès `loop` — fragile, non recommandé |
| Debian physique | ✅ Fonctionne aussi |

### Créer la VM de build sur Proxmox

Une Debian 13 minimale suffit :

- **2 vCPU**, **4 Go RAM**
- **20 Go de disque** (le build en consomme ~10 Go)
- Accès Internet (miroirs Debian + GitHub)

```bash
# Depuis le shell Proxmox : récupérer une image cloud Debian 13 prête à l'emploi
# (ou installer une Debian minimale depuis son ISO, au choix)
qm create 9000 --name debian-build --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0
```

---

## 2. Construire l'ISO

### 2.1 Installer les prérequis

Sur la VM de build :

```bash
sudo apt update
sudo apt install live-build
```

### 2.2 Lancer le build

Placer les deux scripts dans un même dossier, puis :

```bash
chmod +x build-iso.sh
sudo ./build-iso.sh
```

Le build prend **15 à 40 minutes** (téléchargement des paquets) et produit :

```
haos-installer-iso/live-image-amd64.hybrid.iso     (~450 Mo)
```

Le script est idempotent : il repart d'un dossier propre à chaque exécution.

### 2.3 En cas de problème

```bash
cd haos-installer-iso
sudo lb clean --purge     # nettoyage complet avant de relancer
```

Si le build s'interrompt brutalement, vérifier qu'il ne reste pas de montages :

```bash
mount | grep haos-installer-iso
```

---

## 3. Tester l'ISO (sans clé USB)

À faire **avant** de le distribuer. Sur Proxmox, créer une VM de test :

- **BIOS : OVMF (UEFI)** — obligatoire, HAOS ne démarre pas en mode legacy
- **Machine : q35**
- Décocher **Secure Boot** dans les options du firmware EFI
- Un disque de test (**32 Go minimum**)
- Booter sur l'ISO

Cela valide l'assistant, la sélection du disque, le téléchargement et l'écriture.
Seul le **Wi-Fi** ne peut pas être testé ainsi : il demande une machine physique.

---

## 4. Écrire l'ISO sur une clé USB

L'ISO est hybride : il s'écrit directement sur une clé (≥ 2 Go).

- **Windows / macOS / Linux (graphique)** : [Balena Etcher](https://etcher.balena.io/) ou [Rufus](https://rufus.ie/)
- **Ventoy** : copier simplement le `.iso` sur la clé
- **Linux (ligne de commande)** :
  ```bash
  sudo dd if=live-image-amd64.hybrid.iso of=/dev/sdX bs=4M status=progress conv=fsync
  ```
  ⚠️ Vérifier `/dev/sdX` avec `lsblk` — une erreur ici efface le mauvais disque.

---

## 5. Notice pour l'utilisateur final

À transmettre avec la clé USB.

### Avant de commencer

- Un PC **dédié** à Home Assistant : **son disque sera entièrement effacé**.
- Un **câble Ethernet** (fortement recommandé — le Wi-Fi est proposé en secours).
- Le PC doit avoir **32 Go de disque minimum**.

### Étape 1 — Régler le BIOS/UEFI

Allumer le PC et appuyer aussitôt sur `Suppr`, `F2`, `F10` ou `Échap` (selon la marque) :

1. **Mode de démarrage : UEFI** (pas « Legacy » ni « CSM »)
2. **Secure Boot : désactivé** ← *obligatoire, Home Assistant ne démarre pas sinon*
3. Mettre la **clé USB en premier** dans l'ordre de démarrage
4. Enregistrer et quitter (`F10`)

### Étape 2 — Installer

Brancher la clé, démarrer. L'assistant se lance seul et guide pas à pas :

1. Écran d'accueil et rappels
2. Connexion réseau (automatique en Ethernet, sinon choix du Wi-Fi)
3. **Choix du disque** — vérifier la taille et le modèle, le contenu est affiché
   avant confirmation
4. Téléchargement et installation (barre de progression, **ne pas éteindre**)
5. Valider : le PC redémarre. **Retirer la clé USB dès que l'écran s'éteint**
   — pas avant (le système d'installation tourne depuis la clé)

### Étape 3 — Premier démarrage

Laisser le câble réseau branché et **patienter 2 à 5 minutes** (Home Assistant
finalise son installation, l'écran peut sembler figé — c'est normal).

Depuis un autre appareil du même réseau, ouvrir :

```
http://homeassistant.local:8123
```

Si l'adresse ne répond pas, utiliser l'adresse IP affichée à l'écran du PC :
`http://<adresse-ip>:8123`

---

## 6. Personnalisation

**Figer une version de HAOS** — dans `haos-installer.sh`, la dernière version est
récupérée automatiquement depuis l'API GitHub. Pour la figer, remplacer le bloc
`HAOS_VERSION=$(curl ...)` par :

```bash
HAOS_VERSION="18.1"
```

**Ajouter des paquets au live** — les ajouter dans le bloc
`config/package-lists/haos.list.chroot` de `build-iso.sh`.

**Couverture matérielle** — l'ISO embarque les firmwares non-libres Intel,
Realtek, Atheros et Broadcom, ce qui couvre la grande majorité des cartes
Ethernet et Wi-Fi. Pour une couverture encore plus large, remastériser une
**Ubuntu** avec [Cubic](https://github.com/PJ-Singh-001/Cubic) et y injecter
`haos-installer.sh` (la logique de l'assistant est réutilisable telle quelle).

---

## 7. Notes techniques

- **Pourquoi pas l'installateur Debian (d-i) ?** HAOS est une image disque
  complète (GPT + partitions système A/B), pas un ensemble de paquets. `d-i`
  sait partitionner et installer une Debian, pas écrire une image brute. D'où le
  choix d'un live minimal + assistant maison.
- **Partition de données** — inutile de l'agrandir : HAOS étend automatiquement
  sa partition `hassos-data` à la taille du disque au premier démarrage.
- **Effacement préalable** — l'assistant vide les signatures et les tables GPT
  (début et fin du disque) avant écriture. C'est délibéré : sur un disque portant
  un ancien OS, le redimensionnement automatique de HAOS peut échouer.
- **Secure Boot** — HAOS ne le prend pas en charge. Le désactiver est de toute
  façon nécessaire, donc l'ISO n'a pas besoin d'être signé.
- **Firmware embarqués** — seuls les firmwares **réseau** sont inclus (Realtek,
  Intel, Atheros, Broadcom). `--firmware-chroot` est désactivé : sinon `live-build`
  embarque tous les paquets `firmware-*` de l'archive, dont les blobs GPU/audio
  inutiles à un installateur en mode texte (851 Mo → 450 Mo).
  ⚠️ `firmware-realtek` fournit aussi les blobs **Ethernet** Gigabit
  (`rtl_nic/rtl8168*`) : ne pas le retirer en croyant ne couper que le Wi-Fi.
- **`toram`** — le live est copié en RAM au démarrage : la clé USB peut être
  retirée à tout moment. Coût : démarrage plus long (~450 Mo à copier) et ~2 Go
  de RAM nécessaires. Retirer `toram` du `--bootappend-live` sur les machines très
  peu dotées en mémoire.

## Licence

[MIT](LICENSE) pour les scripts de ce dépôt.

Debian, les firmwares non-libres et Home Assistant OS restent soumis à leurs
licences respectives — voir les précisions dans le fichier [LICENSE](LICENSE).

## Sources

- [Home Assistant — Generic x86-64 installation](https://www.home-assistant.io/installation/generic-x86-64/)
- [Home Assistant OS — releases](https://github.com/home-assistant/operating-system/releases)
- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/)
