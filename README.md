# Automatisation du projet 06

Ce dépôt centralise les scripts, workflows et documents d'exploitation communs
au backend Spring Boot et au frontend Angular.

## Arborescence

```text
msm-projet-06-ops/
|-- .github/workflows/ci.yml
|-- docs/
|-- run-tests.sh
`-- README.md
```

## Documentation des étapes

Toutes les étapes sont documentées dans `docs/` :

| Étape | Document |
|---|---|
| Étape 1.1 - Préparer la conteneurisation | [`docs/etape-1.1-preparer-conteneurisation.md`](docs/etape-1.1-preparer-conteneurisation.md) |
| Étape 1.2 - Conteneurisation frontend | [`docs/etape-1.2-conteneurisation-frontend.md`](docs/etape-1.2-conteneurisation-frontend.md) |
| Étape 1.3 - Conteneurisation backend | [`docs/etape-1.3-conteneurisation-backend.md`](docs/etape-1.3-conteneurisation-backend.md) |
| Étape 2.1 - Tests multi-projets | [`docs/etape-2.1-tests-multi-projets.md`](docs/etape-2.1-tests-multi-projets.md) |
| Étape 2.2 - Pipeline réutilisable | [`docs/etape-2.2-pipeline-reutilisable.md`](docs/etape-2.2-pipeline-reutilisable.md) |
| Étape 2.3 - Build et publication GHCR | [`docs/etape-2.3-build-images-ghcr.md`](docs/etape-2.3-build-images-ghcr.md) |

Le README sert uniquement de page d'accueil et d'index. Les critères, choix
techniques, procédures détaillées et validations restent dans les documents
dédiés.

## Démarrage rapide

Les trois dépôts doivent être placés côte à côte :

```text
projet-06/
|-- msm-projet-06-backend/
|-- msm-projet-06-frontend/
`-- msm-projet-06-ops/
```

Depuis le dépôt ops, lancer les tests des deux applications :

```bash
./run-tests.sh
```

Les rapports JUnit sont regroupés dans `test-results/`.
