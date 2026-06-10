# Projet 06 - Operations et validation

Ce depot regroupe les scripts et la documentation necessaires pour verifier
l'environnement, tester les applications et valider les images Docker.

## Structure attendue

```text
projet-06/
|-- msm-projet-06-backend/
|-- msm-projet-06-frontend/
`-- msm-projet-06-ops/
```

Les noms, ports, endpoints et delais sont centralises dans `validation.env`.

## Parcours automatise

### Validation complete

```bash
./msm-projet-06-ops/validate-all.sh
```

Cette commande enchaine la verification de l'environnement, les tests
unitaires, les validations fonctionnelles du backend et du frontend, puis la
validation Docker. Elle s'arrete des qu'une etape obligatoire echoue.

### Verification de l'environnement

```bash
./msm-projet-06-ops/verify-environment.sh
```

Ce script controle les outils, les ports, l'arborescence et les fichiers de
configuration necessaires.

### Verification et tests unitaires

```bash
./msm-projet-06-ops/validate-projects.sh
```

Cette commande execute la verification de l'environnement, puis les tests
backend et frontend uniquement si les prerequis sont valides.

### Validation du backend local

```bash
./msm-projet-06-ops/validate-backend.sh
```

Le script compile, teste, demarre une base PostgreSQL temporaire, lance le
backend, controle son endpoint puis nettoie les ressources creees.

### Validation du frontend local

```bash
./msm-projet-06-ops/validate-frontend.sh
```

Le script installe les dependances, execute les tests, construit
l'application, demarre le serveur Angular et controle la page et l'asset
configures.

### Validation Docker

```bash
./msm-projet-06-ops/validate-docker.sh
```

Le script construit et demarre les stacks Compose, controle les services puis
les arrete.

Pour conserver les conteneurs apres la validation :

```bash
KEEP_CONTAINERS=1 ./msm-projet-06-ops/validate-docker.sh
```

## Choisir un script

| Besoin | Script |
|---|---|
| Executer toute la chaine de validation | `validate-all.sh` |
| Verifier les prerequis | `verify-environment.sh` |
| Executer uniquement les tests unitaires | `run-tests.sh` |
| Enchainer prerequis et tests | `validate-projects.sh` |
| Tester le backend en fonctionnement | `validate-backend.sh` |
| Tester le frontend en fonctionnement | `validate-frontend.sh` |
| Tester les images et stacks Docker | `validate-docker.sh` |

## Execution manuelle

Les commandes suivantes servent a comprendre ou reproduire manuellement les
operations des scripts. Pour une validation reproductible, privilegier les
scripts.

### Verifier les outils

```bash
docker --version
docker compose version
java --version
node --version
npm --version
```

Verifier aussi que le moteur Docker repond :

```bash
docker info
```

### Backend

Depuis `msm-projet-06-backend/` :

```bash
./gradlew clean compileJava --no-daemon
./gradlew test --no-daemon
```

Demarrer PostgreSQL :

```bash
docker run -d \
  --name workshops-db-manual \
  -e POSTGRES_USER=workshops_user \
  -e POSTGRES_PASSWORD=oc2024 \
  -e POSTGRES_DB=workshopsdb \
  -p 5432:5432 \
  postgres:13
```

Verifier la base :

```bash
docker exec workshops-db-manual \
  pg_isready -U workshops_user -d workshopsdb
```

Demarrer et tester le backend :

```bash
./gradlew bootRun --no-daemon
curl http://localhost:8080/api/workshops
```

Nettoyer la base manuelle :

```bash
docker rm -f workshops-db-manual
```

### Frontend

Depuis `msm-projet-06-frontend/` :

```bash
npm ci --cache .npm --prefer-offline
npm test
npm run build
npm start
```

Tester les ressources :

```bash
curl http://localhost:4200/
curl http://localhost:4200/assets/mock/olympic.json
```

### Docker Compose

Backend et PostgreSQL :

```bash
docker compose \
  -f msm-projet-06-backend/docker-compose.yml \
  up -d --build

curl http://localhost:8080/api/workshops

docker compose \
  -f msm-projet-06-backend/docker-compose.yml \
  down --remove-orphans
```

Frontend :

```bash
docker compose \
  -f msm-projet-06-frontend/docker-compose.yml \
  up -d --build

curl http://localhost/
curl http://localhost/assets/mock/olympic.json

docker compose \
  -f msm-projet-06-frontend/docker-compose.yml \
  down --remove-orphans
```

## Configuration

`validation.env` contient les valeurs partagees et les valeurs derivees :

- noms et chemins des projets ;
- versions minimales ;
- ports et endpoints de controle ;
- image et acces PostgreSQL ;
- fichiers Docker Compose ;
- delais d'attente ;
- fichiers et dossiers verifies.

Chaque valeur peut etre surchargee par variable d'environnement :

```bash
FRONTEND_PORT=4300 \
FRONTEND_HEALTH_PATH=/ \
./msm-projet-06-ops/validate-frontend.sh
```

Pour reutiliser les scripts avec un autre projet, adapter en priorite :

- `BACKEND_PROJECT_NAME` et `FRONTEND_PROJECT_NAME` ;
- `BACKEND_HEALTH_PATH` et `FRONTEND_HEALTH_PATH` ;
- les ports ;
- les parametres PostgreSQL ;
- les chemins de fichiers propres aux projets.

## Rapports

Les resultats d'execution ne sont pas recopies dans ce README. Ils sont
generes automatiquement dans `execution-reports/`.

| Fichier | Contenu |
|---|---|
| `*-latest.md` | Derniere synthese du script |
| `*.md` horodate | Historique des syntheses |
| `*.log` horodate | Sortie detaillee sans codes ANSI |

Les rapports JUnit collectes par `run-tests.sh` sont places dans
`test-results/`.

## Checklist

- [ ] `validate-all.sh` termine avec le code `0`.
- [ ] `verify-environment.sh` termine avec le code `0`.
- [ ] `validate-projects.sh` termine avec le code `0`.
- [ ] `validate-backend.sh` termine avec le code `0`.
- [ ] `validate-frontend.sh` termine avec le code `0`.
- [ ] `validate-docker.sh` termine avec le code `0`.
- [ ] L'interface frontend est verifiee dans un navigateur.
- [ ] La console du navigateur ne contient pas d'erreur critique.

Les statuts exacts, durees et erreurs restent dans les rapports generes.

## Depannage

### Port deja utilise

Identifier le processus :

```bash
lsof -i :8080
lsof -i :4200
lsof -i :5432
lsof -i :80
```

Noter le PID affiche par `lsof`, puis demander un arret normal :

```bash
kill <PID>
```

Verifier ensuite que le port est libere :

```bash
lsof -i :4200
```

Si le processus ne s'arrete pas, utiliser l'arret force uniquement en dernier
recours :

```bash
kill -9 <PID>
```

Sous Linux ou WSL, `fuser` permet aussi de liberer directement un port :

```bash
fuser -k 4200/tcp
```

Si Docker occupe le port, identifier puis arreter le conteneur concerne :

```bash
docker ps --filter publish=4200
docker stop <CONTAINER_ID>
```

Ne pas arreter un processus ou un conteneur avant d'avoir verifie qu'il
n'appartient pas a une autre application utile. Une autre solution consiste a
surcharger le port dans `validation.env`.

### Docker inaccessible

```bash
docker info
docker ps
```

Verifier que Docker Desktop ou le moteur Docker est demarre.

### Backend en echec

Consulter :

- `execution-reports/backend-validation-latest.md` ;
- le journal backend reference dans ce rapport ;
- les logs Compose si l'echec vient de Docker.

### Frontend en echec

Consulter :

- `execution-reports/frontend-validation-latest.md` ;
- le journal frontend reference dans ce rapport ;
- les rapports Karma/JUnit du frontend.

### Tests unitaires en echec

Consulter :

- `execution-reports/tests-validation-latest.md` ;
- `test-results/` ;
- les rapports natifs dans les projets backend et frontend.

## Fichiers du depot Ops

| Fichier | Role |
|---|---|
| `validate-all.sh` | Orchestration complete des validations |
| `verify-environment.sh` | Verification des prerequis |
| `run-tests.sh` | Execution et collecte des tests |
| `validate-projects.sh` | Orchestration prerequis et tests |
| `validate-backend.sh` | Validation locale du backend |
| `validate-frontend.sh` | Validation locale du frontend |
| `validate-docker.sh` | Validation Docker |
| `validation.env` | Configuration Bash chargee directement |
| `reporting.sh` | Generation des rapports et journaux |
