# Contribuer

Ce projet est maintenu sur le temps libre, **sans engagement de support ni de
réactivité**. Ce cadre posé, les contributions sont les bienvenues.

## Rapports de bogue

Les issues servent à **documenter les problèmes pour les autres**, pas à obtenir
de l'aide garantie. Une issue peut rester sans réponse ou être fermée sans suite.

Pour qu'un rapport soit utile, précisez :

- le **matériel** (modèle du PC, contrôleur de stockage, carte Wi-Fi via `lspci -nn`) ;
- le mode de démarrage (**UEFI** ou legacy) et l'état de **Secure Boot** ;
- la version de l'ISO et celle de HAOS installée ;
- le contenu de `/tmp/haos-install.log` en cas d'échec de l'installation.

Les problèmes concernant **Home Assistant lui-même** (et non l'installateur)
relèvent de la communauté Home Assistant, pas de ce dépôt.

## Pull requests

Bienvenues, sans promesse de fusion ni de délai. Merci de :

- garder les scripts en **bash POSIX-compatible**, sans dépendance nouvelle
  sauf nécessité réelle (chaque paquet alourdit l'ISO) ;
- vérifier avec `bash -n` et `shellcheck` ;
- tester **au minimum** en VM UEFI (Proxmox q35 + OVMF, Secure Boot désactivé) et
  préciser ce qui a été testé — ou ne l'a pas été ;
- une PR = un sujet.

## Pas d'accord avec les choix de ce projet ?

**Forkez.** La licence MIT est faite pour ça : reprenez le code, changez ce que
vous voulez, redistribuez sous votre nom. Aucune permission à demander. C'est
souvent plus rapide et plus satisfaisant qu'un débat en issue.
