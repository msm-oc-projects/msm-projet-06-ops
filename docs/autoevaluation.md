# Autoévaluation des exercices 1 et 2

Cette grille évalue les deux exercices à partir des fichiers présents dans les
trois dépôts et des validations locales réalisées les 10 et 11 juin 2026.

Légende :

- ✅ : critère implémenté et vérifié ;
- 🟡 : critère implémenté, dernière validation attendue sur GitHub après
  publication des workflows partagés.

# Exercice 1 - Conteneurisation

## Étape 1 - Préparer l'environnement de travail

| Critère | Statut | Preuve |
|---|---|---|
| Les deux applications s'exécutent localement sans erreur | ✅ | Le frontend Angular et le backend Spring Boot ont été exécutés et validés localement |
| Les commandes de build des README fonctionnent | ✅ | `npm run build` et `./gradlew clean compileJava` aboutissent |
| Les commandes d'exécution des README fonctionnent | ✅ | `ng serve`, `./gradlew bootRun` et les commandes Docker sont documentés et validés |
| Les ports nécessaires sont identifiés | ✅ | Frontend : `4200` en développement et `80` avec Docker ; backend : `8080` ; PostgreSQL : `5432` sur le réseau Compose |
| Les versions des outils correspondent aux prérequis | ✅ | Node.js 20.19, Java 21 et Docker 29.4.1 ont été utilisés pour les validations |

**Résultat : 5/5 critères validés.**

## Étape 2 - Dockerfile et Docker Compose du frontend Angular

| Critère | Statut | Preuve |
|---|---|---|
| Le Dockerfile utilise un build multi-stage | ✅ | Étape Node.js pour le build, puis étape NGINX pour l'exécution |
| L'image finale contient uniquement les fichiers nécessaires | ✅ | Seul `dist/olympic-games-starter/browser` est copié dans `/app` |
| Un fichier `.dockerignore` est présent | ✅ | Les dépendances, builds locaux, caches, rapports et fichiers IDE sont exclus |
| `docker-compose.yml` lance l'application | ✅ | Le service construit le Dockerfile et publie le port `80` |
| L'application est accessible sur `http://localhost` | ✅ | Page principale, ressource statique et route Angular validées en HTTP `200` |
| L'image Docker est constructible | ✅ | Image locale `msm-projet-06-frontend:ci-validation` construite avec succès |

**Résultat : 6/6 critères validés.**

## Étape 3 - Dockerfile et Docker Compose du backend Spring Boot

| Critère | Statut | Preuve |
|---|---|---|
| Le Dockerfile compile avec Gradle | ✅ | `./gradlew clean test bootWar --no-daemon` est exécuté dans l'étape de build |
| L'image finale utilise une JRE | ✅ | Image finale basée sur `eclipse-temurin:21-jre` |
| Compose contient l'application et PostgreSQL | ✅ | Services `app` et `db` présents |
| Les variables de connexion sont configurées | ✅ | URL JDBC, utilisateur et mot de passe transmis à Spring Boot |
| Un volume PostgreSQL est défini | ✅ | Volume nommé `postgres_data` monté dans `/var/lib/postgresql/data` |
| Un healthcheck orchestre le démarrage | ✅ | `pg_isready` contrôle PostgreSQL et `app` dépend de `service_healthy` |
| L'API répond sur `http://localhost:8080` | ✅ | Endpoint `/api/workshops` validé en HTTP `200` avec une réponse JSON |
| L'image Docker est constructible | ✅ | Image locale `msm-projet-06-backend:ci-validation` construite avec 2 tests JUnit réussis |

**Résultat : 8/8 critères validés.**

## Bilan de l'exercice 1

**19/19 critères validés.**

# Exercice 2 - Pipeline CI/CD

## Étape 1 - Script d'exécution des tests unifié

| Critère | Statut | Preuve |
|---|---|---|
| Détection automatique Angular ou Spring Boot | ✅ | `run-tests.sh` détecte `package.json` ou `build.gradle` |
| Exécution des tests des deux applications | ✅ | `npm test` pour Angular et `./gradlew clean test --no-daemon` pour Spring Boot |
| Génération de rapports JUnit XML | ✅ | Karma utilise le reporter JUnit et Gradle produit ses rapports JUnit |
| Rapports placés dans `test-results/` | ✅ | 3 rapports XML centralisés : 2 backend et 1 frontend |
| Code de sortie approprié | ✅ | `0` si tous les projets réussissent, `1` en cas d'échec, projet ou rapport absent |
| Nettoyage des anciens artefacts | ✅ | `test-results/`, `reports/` et `build/test-results/` sont nettoyés avant exécution |
| Rapports valides | ✅ | Les 3 fichiers présents dans `test-results/` ont été parsés comme XML valides |

**Résultat : 7/7 critères validés.**

## Étape 2 - Pipeline de test réutilisable

| Critère | Statut | Preuve |
|---|---|---|
| Le workflow contient un job `test` | ✅ | `.github/workflows/ci.yml` du dépôt ops expose le job avec `workflow_call` |
| Le job s'adapte aux deux projets | ✅ | Détection npm ou Gradle et conditions sur chaque étape |
| Le rapport est intégré au workflow GitHub | ✅ | `actions/upload-artifact` et `dorny/test-reporter` publient les XML |
| Les dépendances sont mises en cache | ✅ | Cache npm via `setup-node` et cache Gradle via `setup-java` |
| Le pipeline se déclenche sur les push et pull requests | ✅ | Les workflows appelants couvrent `main`, `develop`, `feature/**` et les pull requests |
| Le template est utilisé par les deux applications | ✅ | Backend et frontend appellent le même workflow ops |

**Résultat : 6/6 critères validés.**

## Étape 3 - Build et publication des images

| Critère | Statut | Preuve |
|---|---|---|
| Un job `build` est ajouté | ✅ | Le workflow partagé contient `build` avec `needs: test` |
| Le job construit l'image Docker | ✅ | `docker/build-push-action@v6` utilise le Dockerfile du dépôt appelant |
| L'image est poussée vers GHCR | 🟡 | Authentification `ghcr.io` et publication hors pull request configurées ; nouveau workflow partagé à confirmer sur GitHub |
| L'image est taguée avec la branche et le SHA | ✅ | Tag calculé sous la forme `branche-abcdef0` |
| Le pipeline fonctionne pour les deux applications | ✅ | Les deux images ont été construites localement avec succès |
| Les pull requests ne publient pas d'image | ✅ | Le build est exécuté avec `push: false` pour une pull request |

**Résultat : 5 critères validés et 1 critère configuré à confirmer sur GitHub.**

## Étape 4 - Versionnement avec semantic-release

| Critère | Statut | Preuve |
|---|---|---|
| `semantic-release` et ses plugins sont configurés | ✅ | `release.config.cjs` dans chaque application et installation des plugins dans `release.yml` |
| Un job de release est ajouté | ✅ | Le workflow partagé `.github/workflows/release.yml` expose le job `release` |
| Conventional Commits est adopté | ✅ | Historique utilisant `feat`, `fix`, `ci`, `docs`, `refactor` et commits de release |
| Les releases GitHub avec changelog sont générées | ✅ | Tags jusqu'à `v1.1.0`, commits de release et `CHANGELOG.md` présents dans les deux dépôts |
| Les images Docker sont taguées avec la version SemVer | 🟡 | Publication configurée avec `${version}` ; nouvelle version partagée à confirmer dans GHCR |
| La stratégie de déclenchement est définie | ✅ | Release automatique après succès du pipeline sur `main` uniquement |
| La version frontend est synchronisée | ✅ | `npm version --no-git-tag-version` met à jour `package.json` et `package-lock.json` |
| La version backend est synchronisée | ✅ | Le script remplace la propriété `version` dans `build.gradle` |
| Les permissions du `GITHUB_TOKEN` sont configurées | ✅ | Droits `contents`, `issues`, `pull-requests` et `packages` en écriture |
| Les paquets applicatifs sont publiés | 🟡 | Publication npm et Maven configurée ; nouveau workflow partagé à confirmer après publication |

**Résultat : 7 critères validés et 3 critères configurés à confirmer sur GitHub.**

## Bilan de l'exercice 2

- 25 critères validés ;
- 4 critères configurés et en attente d'une dernière validation GitHub.

# Bilan général

- Exercice 1 : **19/19 critères validés** ;
- Exercice 2 : **25 critères validés sur 29**, dont 4 à confirmer sur GitHub ;
- Total : **44 critères validés sur 48**.

Les fonctionnalités demandées sont toutes implémentées. Les critères encore
marqués 🟡 concernent uniquement la confirmation distante des publications par
la nouvelle version des workflows partagés.

## Validation finale requise

1. Publier le dépôt ops sur `main`.
2. Publier les workflows backend et frontend.
3. Pousser ou fusionner un commit conventionnel vers `main`.
4. Vérifier les images `branche-SHA` dans GHCR.
5. Vérifier la release GitHub et le changelog.
6. Vérifier le paquet npm ou Maven.
7. Vérifier l'image Docker taguée avec la version sémantique.
