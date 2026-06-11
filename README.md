# Tests unitaires multi-projets

Ce dépôt contient `run-tests.sh`, le point d'entrée commun utilisé localement
et dans la CI pour exécuter les tests unitaires du backend et du frontend.

Le script est autonome : il ne charge aucun fichier depuis un autre dépôt. Il
attend uniquement que les dépôts backend, frontend et Ops soient placés côte à
côte sous une même racine.

## Arborescence attendue

```text
projet-06/
|-- msm-projet-06-backend/
|-- msm-projet-06-frontend/
`-- msm-projet-06-ops/
    |-- README.md
    `-- run-tests.sh
```

## Prérequis

Pour exécuter les deux suites :

- Bash sous Linux, macOS ou WSL ;
- Java 21 pour le backend ;
- wrapper Gradle présent dans le dépôt backend ;
- Node.js 20 ou plus récent ;
- npm ;
- Chrome ou Chromium utilisable par Karma en mode headless ;
- `package-lock.json` présent dans le frontend.

Le lockfile frontend est désormais obligatoire dans tous les cas, car le
script exécute systématiquement `npm ci`. Cette réinstallation évite de
réutiliser des modules natifs créés pour une autre plateforme.

## Exercice 2 - Étape 1

Cette étape demande un script unique capable de détecter la technologie des
projets, d'exécuter leurs tests et de produire des rapports JUnit XML.

### Checklist des critères

- [x] script Bash unique `run-tests.sh` ;
- [x] détection automatique avec `package.json` ou `build.gradle` ;
- [x] exécution de `npm test` pour Angular ;
- [x] exécution de `./gradlew clean test --no-daemon` pour Spring Boot ;
- [x] vérification de Java, npm, du wrapper Gradle et du lockfile ;
- [x] installation reproductible des dépendances avec `npm ci` ;
- [x] suppression des rapports précédents avant chaque exécution ;
- [x] collecte centralisée dans `test-results/` ;
- [x] rapports au format JUnit XML ;
- [x] poursuite des tests après l'échec d'un premier projet ;
- [x] code de sortie non nul si un projet échoue ou manque ;
- [x] rapports directement exploitables par GitHub Actions.

### Résultat attendu

Après une exécution réussie :

```text
test-results/
|-- msm-projet-06-backend/
|   |-- TEST-NotionServiceTest.xml
|   `-- TEST-WorkshopServiceTest.xml
`-- msm-projet-06-frontend/
    `-- TESTS-Chrome_Headless_<version>_<plateforme>.xml
```

Le dossier est ignoré par Git, car il contient des artefacts générés.

### État de validation

L'Étape 1 de l'Exercice 2 a été validée localement le 11 juin 2026 :

- 2 projets demandés et 2 projets détectés ;
- 2 tests JUnit backend réussis ;
- 5 tests Karma/Jasmine frontend réussis ;
- 2 rapports XML backend collectés ;
- 1 rapport XML frontend collecté ;
- 3 rapports confirmés comme XML valides ;
- code de sortie final `0` ;
- aucun fichier généré ajouté au suivi Git.

## Exécuter les tests

Depuis `msm-projet-06-ops` :

```bash
./run-tests.sh
```

Cette commande exécute par défaut :

```bash
# Backend
./gradlew clean test --no-daemon

# Frontend
npm test
```

Le script traite les deux projets même si le premier échoue, afin de fournir
un bilan complet.

## Cibler un projet

Backend uniquement :

```bash
TEST_PROJECT_NAMES=msm-projet-06-backend ./run-tests.sh
```

Frontend uniquement :

```bash
TEST_PROJECT_NAMES=msm-projet-06-frontend ./run-tests.sh
```

Liste explicite des deux projets :

```bash
TEST_PROJECT_NAMES="msm-projet-06-backend msm-projet-06-frontend" \
./run-tests.sh
```

## Détection des technologies

Le moteur de test est choisi à partir des fichiers présents à la racine de
chaque projet :

| Fichier détecté | Type de projet | Commande |
|---|---|---|
| `package.json` | npm/Angular | `npm test` |
| `build.gradle` | Gradle/Java | `./gradlew clean test --no-daemon` |

Pour Gradle, l'ordre de priorité est :

1. wrapper Unix `gradlew` ;
2. wrapper Windows `gradlew.bat` lorsque `cmd.exe` est disponible ;
3. installation globale de `gradle`.

## Dépendances frontend

Le script exige `package-lock.json`, puis exécute systématiquement :

```bash
npm ci --cache .npm --prefer-offline
```

`npm ci` garantit une installation conforme au lockfile. Le cache `.npm`
réduit les téléchargements lors des exécutions suivantes. La suppression et la
recréation de `node_modules` garantissent aussi que les binaires natifs
correspondent à la plateforme courante.

## Rapports JUnit

Avant chaque exécution, l'ancien dossier `test-results/` est supprimé afin de
ne pas mélanger des résultats issus de deux lancements.

Les rapports XML sont ensuite regroupés ainsi :

```text
test-results/
|-- msm-projet-06-backend/
|   |-- TEST-NotionServiceTest.xml
|   `-- TEST-WorkshopServiceTest.xml
`-- msm-projet-06-frontend/
    `-- TESTS-Chrome_Headless_<version>_<plateforme>.xml
```

Les emplacements sources attendus sont :

- backend : `build/test-results/test/` ;
- frontend : `reports/`.

L'absence de rapport XML est considérée comme un échec, même si la commande de
test retourne le code `0`. Cette règle évite qu'une CI annonce un succès sans
preuve exploitable.

## Variables

| Variable | Valeur par défaut | Rôle |
|---|---|---|
| `PROJECT_ROOT` | dossier parent d'Ops | Racine contenant les dépôts |
| `BACKEND_PROJECT_NAME` | `msm-projet-06-backend` | Nom du dépôt backend |
| `FRONTEND_PROJECT_NAME` | `msm-projet-06-frontend` | Nom du dépôt frontend |
| `TEST_PROJECT_NAMES` | backend + frontend | Projets à parcourir |

Exemple avec une autre racine :

```bash
PROJECT_ROOT=/chemin/vers/projet-06 ./run-tests.sh
```

## Codes de sortie

| Code | Signification |
|---|---|
| `0` | Tous les projets détectés ont réussi |
| `1` | Commande absente, projet introuvable, test en échec ou rapport absent |

Le code de sortie du script peut être contrôlé avec :

```bash
./run-tests.sh
echo $?
```

GitHub Actions considère automatiquement tout code différent de `0` comme un
échec du job.

## Dépannage

### Permission refusée sur `run-tests.sh`

```bash
chmod +x run-tests.sh
```

### Wrapper Gradle inutilisable sous WSL

Le fichier `gradlew` doit utiliser des fins de ligne LF et être exécutable :

```bash
chmod +x ../msm-projet-06-backend/gradlew
```

### ChromeHeadless introuvable

Installez Chrome ou Chromium et, si nécessaire, définissez `CHROME_BIN` avant
de lancer les tests Angular.

### Aucun projet détecté

Vérifiez l'arborescence des dépôts ou surchargez `PROJECT_ROOT` et les noms de
projets.

### Aucun rapport frontend

Vérifiez que Karma utilise `karma-junit-reporter` et écrit ses fichiers XML
dans `reports/`.

### Aucun rapport backend

Vérifiez que la tâche Gradle `test` utilise JUnit Platform et génère ses
résultats dans `build/test-results/test/`.
