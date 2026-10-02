# infra — petroslabs

Reverse proxy partagé pour les projets PetrosLabs hébergés sur un même VPS.
Né de la volonté de rendre chaque projet (portfolio, SymAgri, …) autonome —
sa propre base de données embarquée, son propre conteneur — sans pour autant
faire tourner un Traefik par projet, puisqu'un reverse proxy possède les
ports 80/443 et ne peut exister qu'en un seul exemplaire par machine.

## Règle n°0 — Discipline de périmètre

**Ce dépôt ne connaît que des noms de domaines et des labels Docker, jamais
le contenu d'une application.** Avant d'ajouter quoi que ce soit ici, vérifier
que ça respecte les deux règles suivantes — sinon, ça vit dans le projet
concerné, pas ici :

- **Singleton au niveau de l'hôte uniquement.** Le reverse proxy en est un
  (contrainte physique : un seul process peut tenir les ports 80/443). Un
  outil qui pourrait tourner par projet sans conflit (base de données, cache,
  file de messages, mailer de dev…) n'a pas sa place ici, même si plusieurs
  projets pourraient techniquement le partager — c'est exactement ce que
  `symfony_env` faisait, et c'est la dépendance qu'on est en train de
  démonter projet par projet.
- **Pas de données applicatives.** Rien ici ne doit porter le contenu ou
  l'état d'un projet (pas de volume de base de données, pas de backup
  applicatif). Le jour où un outil générique et sans état (ex. un registre
  Docker, Watchtower) devient un vrai besoin partagé, il peut rejoindre ce
  dépôt — mais pas par anticipation : seulement quand le besoin est concret.

## Comment un projet rejoint ce proxy

Le projet ne fait rien d'autre que :
1. Pointer `PROXY_NETWORK=edge` (le réseau externe que ce dépôt possède) dans
   sa propre config Docker Compose.
2. Déclarer son routage par des étiquettes Traefik (`Host(...)`,
   `tls.certresolver=letsencrypt` en prod) sur son propre service applicatif.

Aucun dépôt tiers à cloner côté projet, aucune donnée partagée — juste un nom
de réseau Docker.

## Usage

- Développement : `make up` (certificats mkcert locaux, tableau de bord sur
  `TRAEFIK_DOMAIN`).
- Production : `make up-prod` (Let's Encrypt, `.env.docker` requis — voir
  `.env.docker.example`). Pas de tableau de bord exposé en production.

## Stack

Traefik v3 + `tecnativa/docker-socket-proxy` (le socket Docker n'est jamais
accessible en direct — y donner accès équivaut à donner root sur l'hôte).
