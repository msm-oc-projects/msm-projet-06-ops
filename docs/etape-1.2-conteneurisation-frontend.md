# Étape 1.2 - Conteneurisation du frontend

Cette étape conteneurise l'application Angular dans une image multi-stage :

1. `node:20.19-alpine` installe les dépendances avec `npm ci` et produit le
   build Angular de production ;
2. `nginx:1.27-alpine` reçoit uniquement les fichiers statiques compilés et les
   sert sur le port `80`.

Les outils de compilation et `node_modules` restent ainsi absents de l'image
finale.

## Fichiers concernés

| Fichier | Rôle |
|---|---|
| `msm-projet-06-frontend/Dockerfile` | Build Angular puis image NGINX |
| `msm-projet-06-frontend/docker-compose.yml` | Construction et exécution du frontend |
| `msm-projet-06-frontend/.dockerignore` | Réduction du contexte Docker |
| `msm-projet-06-frontend/nginx/nginx.conf` | Fichiers statiques et routes Angular |

## Construction

Le builder Angular écrit les fichiers web dans :

```text
dist/olympic-games-starter/browser
```

Le `Dockerfile` copie ce dossier dans `/app` au sein de l'image NGINX.

Depuis le dépôt frontend :

```bash
docker compose up -d --build
```

L'application est disponible sur `http://localhost`.

## Vérifications

```bash
curl http://localhost/
curl http://localhost/assets/mock/olympic.json
docker compose ps
docker compose logs
```

Le conteneur doit être `healthy` et les deux requêtes HTTP doivent retourner un
statut `2xx`.

La configuration NGINX utilise :

```nginx
try_files $uri $uri/ /index.html;
```

Ce fallback permet d'ouvrir ou de rafraîchir directement une route Angular
sans erreur HTTP 404. La configuration active également gzip, évite le cache
durable de `index.html` et applique un cache long aux bundles nommés avec un
hash.

## Nettoyage

Conserver l'image dans le cache :

```bash
docker compose down --remove-orphans
```

Supprimer aussi l'image locale :

```bash
docker compose down --rmi local --remove-orphans
```

Si le port `80` est occupé, la publication peut temporairement être changée en
`8081:80`; l'application devient alors accessible sur
`http://localhost:8081`.

## État de validation

L'étape a été validée localement le 10 juin 2026 :

- build Angular et création de l'image NGINX réussis ;
- démarrage Compose et healthcheck réussis ;
- page principale, ressource statique et route Angular directe en HTTP `200` ;
- nettoyage des conteneurs et du réseau vérifié.

## Résultat attendu

- `docker compose build` termine sans erreur ;
- le conteneur devient `healthy` ;
- la page principale et les ressources statiques répondent en HTTP `2xx` ;
- le routage Angular fonctionne après un rafraîchissement direct ;
- `docker compose down --remove-orphans` nettoie le conteneur et le réseau.
