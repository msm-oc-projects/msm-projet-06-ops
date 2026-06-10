# Tests multi-projets

Ce dépôt conserve uniquement `run-tests.sh`, utilisé par la CI pour exécuter
et regrouper les tests du backend et du frontend.

## Exécuter les tests

Depuis le dossier `msm-projet-06-ops`, lancez tous les tests unitaires du
backend et du frontend :

```bash
./run-tests.sh
```

Pour tester uniquement le backend :

```bash
TEST_PROJECT_NAMES=msm-projet-06-backend ./run-tests.sh
```

Pour tester uniquement le frontend :

```bash
TEST_PROJECT_NAMES=msm-projet-06-frontend ./run-tests.sh
```

Le script continue jusqu'à avoir traité tous les projets demandés et retourne
un code d'erreur si au moins l'un d'entre eux échoue. Les rapports JUnit sont
regroupés dans `test-results/`.

Les autres scripts de validation, leur configuration et leur documentation
sont disponibles dans `../msm-projet-06-autres/ops/`.
