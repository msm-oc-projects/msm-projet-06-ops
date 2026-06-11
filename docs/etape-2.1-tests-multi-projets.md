# Étape 2.1 - Tests multi-projets

Cette étape fournit un script Bash unique capable de détecter la technologie
des applications, d'exécuter leurs tests et de centraliser les rapports JUnit
XML.

## Critères couverts

- script unique `run-tests.sh` ;
- détection avec `package.json` ou `build.gradle` ;
- exécution de `npm test` pour Angular ;
- exécution de `./gradlew clean test --no-daemon` pour Spring Boot ;
- vérification de Java, npm, du wrapper Gradle et du lockfile npm ;
- installation reproductible des dépendances avec `npm ci` ;
- nettoyage des anciens rapports ;
- poursuite des tests lorsqu'un premier projet échoue ;
- code de sortie non nul lorsqu'un projet échoue ou est absent ;
- collecte des rapports JUnit XML dans `test-results/`.

## Arborescence attendue

```text
projet-06/
|-- msm-projet-06-backend/
|-- msm-projet-06-frontend/
`-- msm-projet-06-ops/
    `-- run-tests.sh
```

## Prérequis

- Bash sous Linux, macOS ou WSL ;
- Java 21 ;
- wrapper Gradle du backend ;
- Node.js 20 ou plus récent ;
- npm et `package-lock.json` ;
- Chrome ou Chromium pour Karma en mode headless.

## Exécution

Tester les deux applications :

```bash
./run-tests.sh
```

Tester uniquement le backend :

```bash
TEST_PROJECT_NAMES=msm-projet-06-backend ./run-tests.sh
```

Tester uniquement le frontend :

```bash
TEST_PROJECT_NAMES=msm-projet-06-frontend ./run-tests.sh
```

Utiliser une autre racine :

```bash
PROJECT_ROOT=/chemin/vers/projet-06 ./run-tests.sh
```

## Fonctionnement

| Fichier détecté | Technologie | Commande |
|---|---|---|
| `package.json` | npm/Angular | `npm ci`, puis `npm test` |
| `build.gradle` | Gradle/Java | `./gradlew clean test --no-daemon` |

Pour Gradle, le script privilégie le wrapper Unix, puis le wrapper Windows
lorsque `cmd.exe` est disponible, puis une installation globale de Gradle.

Pour npm, `package-lock.json` est obligatoire. `npm ci` recrée
`node_modules` avec les versions du lockfile et les binaires adaptés à la
plateforme courante.

## Rapports

```text
test-results/
|-- msm-projet-06-backend/
|   |-- TEST-NotionServiceTest.xml
|   `-- TEST-WorkshopServiceTest.xml
`-- msm-projet-06-frontend/
    `-- TESTS-Chrome_Headless_<version>_<plateforme>.xml
```

Les sources sont :

- backend : `build/test-results/test/` ;
- frontend : `reports/`.

L'absence de rapport XML est considérée comme un échec.

## Variables

| Variable | Valeur par défaut |
|---|---|
| `PROJECT_ROOT` | dossier parent du dépôt ops |
| `BACKEND_PROJECT_NAME` | `msm-projet-06-backend` |
| `FRONTEND_PROJECT_NAME` | `msm-projet-06-frontend` |
| `TEST_PROJECT_NAMES` | backend et frontend |

## Codes de sortie

| Code | Signification |
|---|---|
| `0` | Tous les projets demandés ont réussi |
| `1` | Outil, projet ou rapport absent, ou tests en échec |

## État de validation

L'étape a été validée localement le 11 juin 2026 :

- 2 projets demandés et détectés ;
- 2 tests JUnit backend réussis ;
- 5 tests Karma/Jasmine frontend réussis ;
- 3 rapports XML collectés et validés ;
- code de sortie final `0`.

## Dépannage

Rendre les scripts exécutables :

```bash
chmod +x run-tests.sh
chmod +x ../msm-projet-06-backend/gradlew
```

Si ChromeHeadless est introuvable, installer Chrome ou Chromium et définir
`CHROME_BIN` si nécessaire.
