# Étape 2.2 - Pipeline réutilisable

Le fichier `.github/workflows/ci.yml` du dépôt ops est un workflow GitHub
Actions réutilisable par les applications Angular et Spring Boot.

## Appel depuis une application

```yaml
jobs:
  pipeline:
    uses: msm-oc-projects/msm-projet-06-ops/.github/workflows/ci.yml@main
```

Les pipelines backend et frontend conservent leurs propres déclencheurs. Le
workflow partagé est appelé avec `workflow_call`.

## Fonctionnement

Le job :

- détecte npm/Angular avec `package.json` ;
- détecte Gradle/Java avec `build.gradle` ou `build.gradle.kts` ;
- prépare uniquement Node.js 20 ou Java 21 selon le projet ;
- active le cache npm ou Gradle ;
- exécute `npm ci` et `npm test`, ou
  `./gradlew clean test --no-daemon` ;
- collecte les rapports XML dans `test-results/` ;
- conserve les rapports comme artefact pendant 14 jours ;
- publie les résultats dans GitHub avec `dorny/test-reporter`.

## Permissions et secrets

Le workflow demande uniquement :

```yaml
permissions:
  contents: read
  checks: write
```

Aucun secret applicatif n'est lu ou affiché par le job de test.

Si le dépôt ops est privé, le réglage
`Settings > Actions > General > Access` doit autoriser les autres dépôts de
l'organisation à utiliser ses workflows.

Le workflow ops doit être publié avant les pipelines applicatifs qui le
référencent avec `@main`. Une version immuable pourra ensuite être référencée
avec un tag ou un SHA.

## Résultat attendu

- le même workflow fonctionne dans le backend et le frontend ;
- seules les étapes correspondant à la technologie détectée sont exécutées ;
- les dépendances sont mises en cache ;
- les tests bloquent le job de build en cas d'échec ;
- les rapports JUnit sont disponibles comme artefacts et checks GitHub.
