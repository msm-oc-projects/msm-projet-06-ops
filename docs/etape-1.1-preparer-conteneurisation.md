# Étape 1.1 - Préparer la conteneurisation

Cette étape prépare les deux applications à être construites et exécutées avec
Docker. Chaque dépôt applicatif reçoit :

- un `Dockerfile` multi-stage ;
- un fichier `docker-compose.yml` ;
- un `.dockerignore` adapté à sa technologie.

## Frontend Angular

Le build utilise `node:20.19-alpine` :

```dockerfile
FROM node:20.19-alpine AS build
```

Les dépendances sont installées à partir du lockfile, puis Angular produit les
fichiers statiques :

```bash
npm ci --cache .npm --prefer-offline
npm run build
```

L'image finale utilise `nginx:1.27-alpine` et expose le port `80`.

Le `.dockerignore` exclut notamment :

- `node_modules` ;
- `dist` et `coverage` ;
- les caches `.angular` et `.npm` ;
- les fichiers Git et IDE.

## Backend Spring Boot

Le build utilise `eclipse-temurin:21-jdk` et le wrapper Gradle :

```bash
./gradlew clean test bootWar --no-daemon
```

L'image finale utilise `eclipse-temurin:21-jre`, copie uniquement le WAR et
expose le port `8080`.

Le `.dockerignore` exclut notamment :

- `.gradle`, `build`, `bin` et `out` ;
- les fichiers Git et IDE ;
- les fichiers qui ne sont pas nécessaires au contexte de build.

## Docker Compose

Le frontend est publié sur le port `80`.

Le backend est publié sur le port `8080` et communique avec un service
PostgreSQL 13. Le service applicatif attend que la base soit disponible avant
de démarrer.

## Vérifications

Depuis chaque dépôt :

```bash
docker compose config
docker compose build
```

Les images finales ne doivent contenir ni les sources ni les outils de
compilation.

## Résultat attendu

- chaque application possède un contexte Docker reproductible ;
- les dépendances sont installées depuis les fichiers de verrouillage ;
- les images utilisent une construction multi-stage ;
- les fichiers inutiles sont exclus du contexte ;
- Docker Compose permet de construire et démarrer chaque application.

