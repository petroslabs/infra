# infra

Reverse proxy partagé pour les projets [PetrosLabs](https://petroslabs.dev)
hébergés sur un même VPS.

## Pourquoi ce dépôt

Chaque projet PetrosLabs est pensé pour être autonome : sa propre base de
données embarquée, son propre conteneur applicatif, déployable seul sur un
hôte nu. La seule chose qu'un projet ne peut pas embarquer lui-même, c'est le
reverse proxy — un reverse proxy possède les ports 80 et 443, et il ne peut
y en avoir qu'un par machine. Ce dépôt fournit ce proxy, une fois, pour tous
les projets colocalisés sur le même VPS.

Un projet qui tourne seul sur sa propre machine n'a pas besoin de ce dépôt :
voir la pile « edge » optionnelle que chaque projet embarque pour ce cas-là
(ex. `compose.edge.yaml` dans SymAgri).

## Utilisation

```bash
git clone git@github.com:petroslabs/infra.git
cd infra

# Développement
cp .env.example .env
make up          # lève Traefik, engendre les certificats mkcert locaux

# Production (VPS)
cp .env.docker.example .env.docker
# renseigner ACME_EMAIL dans .env.docker
make up-prod
```

Pour qu'un projet rejoigne ce proxy, il suffit qu'il pointe
`PROXY_NETWORK=edge` dans sa propre configuration Docker Compose et qu'il
déclare son routage par des étiquettes Traefik — aucune dépendance de code,
aucune donnée partagée.

## Stack

- Traefik v3 (reverse proxy, TLS)
- `tecnativa/docker-socket-proxy` (accès en lecture seule au socket Docker —
  jamais en direct)
- mkcert (certificats TLS de développement)
- Let's Encrypt (certificats TLS de production)

## Portée

Ce dépôt est volontairement minimal : le reverse proxy, rien d'autre. Voir
`CLAUDE.md` pour la discipline de périmètre à respecter avant d'y ajouter
quoi que ce soit.

## Licence

MIT — voir [LICENSE](LICENSE).
