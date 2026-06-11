# Étape 1.3 - Conteneurisation du backend avec PostgreSQL

Cette étape construit une stack Docker composée de deux services :

1. `app` compile, teste et empaquette l'API Spring Boot, puis exécute le WAR
   avec Eclipse Temurin JRE 21 ;
2. `db` fournit PostgreSQL 13 et conserve ses données dans un volume Docker
   nommé.

## Fichiers concernés

| Fichier | Rôle |
|---|---|
| `msm-projet-06-backend/Dockerfile` | Compilation Gradle puis image JRE |
| `msm-projet-06-backend/docker-compose.yml` | API et PostgreSQL |
| `msm-projet-06-backend/.dockerignore` | Réduction du contexte Docker |
| `msm-projet-06-backend/.gitattributes` | Fins de ligne Linux et WSL |

## Construction multi-stage

L'étape de build utilise `eclipse-temurin:21-jdk` et exécute :

```bash
./gradlew clean test bootWar --no-daemon
```

Cette commande génère les interfaces OpenAPI, compile l'application, exécute
les tests JUnit et produit le WAR Spring Boot. L'image finale utilise
`eclipse-temurin:21-jre`; elle ne contient ni sources, ni JDK, ni cache Gradle.

## Configuration PostgreSQL

| Variable | Valeur Compose par défaut |
|---|---|
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://db:5432/workshopsdb` |
| `SPRING_DATASOURCE_USERNAME` | `workshops_user` |
| `SPRING_DATASOURCE_PASSWORD` | `oc2024` |

Dans l'URL JDBC, `db` désigne le service PostgreSQL sur le réseau Compose. Les
valeurs par défaut sont réservées au développement local et ne doivent pas
être utilisées comme secrets de production.

Les valeurs peuvent être surchargées :

```bash
POSTGRES_DB=workshopsdb \
POSTGRES_USER=workshops_user \
POSTGRES_PASSWORD=mot_de_passe_local \
docker compose up -d --build
```

## Démarrage et vérifications

Depuis le dépôt backend :

```bash
docker compose up -d --build
curl http://localhost:8080/api/workshops
docker compose ps
docker compose logs app
docker compose logs db
```

PostgreSQL est contrôlé avec `pg_isready`. Le service `app` attend que la base
soit `healthy`, puis son propre healthcheck interroge
`http://127.0.0.1:8080/api/workshops`.

Si le port `8080` est occupé :

```bash
BACKEND_PORT=8081 docker compose up -d --build
```

L'API est alors disponible sur
`http://localhost:8081/api/workshops`.

## Persistance et nettoyage

Le volume `postgres_data` est monté dans
`/var/lib/postgresql/data`.

Recréer les conteneurs en conservant les données :

```bash
docker compose down
docker compose up -d
```

Arrêter la stack sans supprimer les données :

```bash
docker compose down --remove-orphans
```

Supprimer volontairement la base locale :

```bash
docker compose down --volumes --remove-orphans
```

Cette dernière commande est destructive pour les données du volume.

## Dépannage

```bash
docker inspect --format '{{json .State.Health}}' \
  "$(docker compose ps -q app)"
docker compose logs --tail=200 app
docker compose logs --tail=200 db
docker compose exec db \
  pg_isready -U workshops_user -d workshopsdb
```

## État de validation

L'étape a été validée localement le 10 juin 2026 :

- build Gradle, génération OpenAPI et packaging WAR réussis ;
- 2 tests JUnit réussis pendant la construction ;
- PostgreSQL et Spring Boot passés à l'état `healthy` ;
- endpoint `/api/workshops` validé en HTTP `200` avec une réponse JSON ;
- persistance confirmée après recréation des conteneurs ;
- données de contrôle nettoyées et volume applicatif conservé.

## Résultat attendu

- l'image backend est construite avec succès ;
- les services `db` et `app` deviennent `healthy` dans cet ordre ;
- l'API répond en HTTP `200` ;
- les données survivent à la recréation des conteneurs ;
- les secrets de production ne sont ni écrits dans Git ni affichés dans les
  logs.
