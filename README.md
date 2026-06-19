# Automatisation du projet 06

Ce dépôt centralise les scripts et workflows d'exploitation communs au backend
Spring Boot et au frontend Angular.

## Arborescence

```text
msm-projet-06-ops/
|-- .github/workflows/
|   |-- ci.yml
|   `-- release.yml
|-- run-tests.sh
`-- README.md
```

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
