# Étape 2.3 - Construire et publier les images Docker

Cette étape ajoute le job `build` au workflow réutilisable
`.github/workflows/ci.yml`. Il construit l'image Docker de l'application après
la réussite du job `test`, puis la publie dans GitHub Container Registry.

## Enchaînement

```text
test -> build
```

La dépendance `needs: test` empêche la création et la publication d'une image
si les tests unitaires échouent.

Les workflows backend et frontend appellent le pipeline partagé avec :

```yaml
jobs:
  pipeline:
    uses: msm-oc-projects/msm-projet-06-ops/.github/workflows/ci.yml@main
```

## Registre et nom de l'image

Le registre est défini avec une variable d'environnement :

```yaml
env:
  REGISTRY: ghcr.io
```

Le nom de l'image est dérivé de `GITHUB_REPOSITORY` et converti en minuscules :

```text
ghcr.io/msm-oc-projects/msm-projet-06-backend
ghcr.io/msm-oc-projects/msm-projet-06-frontend
```

## Tag de l'image

Le tag combine :

- le nom de la branche fourni par `GITHUB_REF_NAME` ;
- les 7 premiers caractères de `GITHUB_SHA`.

Les caractères incompatibles avec un tag Docker sont remplacés par `-`.

Exemples :

```text
develop-a1b2c3d
feature-ajout-ci-a1b2c3d
main-a1b2c3d
```

L'image complète prend donc cette forme :

```text
ghcr.io/msm-oc-projects/msm-projet-06-backend:develop-a1b2c3d
```

## Construction et cache

Le job utilise :

- `docker/setup-buildx-action@v3` pour préparer Buildx ;
- `docker/build-push-action@v6` pour construire et publier ;
- le cache GitHub Actions avec `cache-from: type=gha` et
  `cache-to: type=gha,mode=max`.

Le `Dockerfile` est vérifié avant le lancement du build.

## Authentification et permissions

Le workflow utilise le jeton temporaire fourni par GitHub Actions :

```yaml
permissions:
  contents: read
  packages: write
```

L'authentification GHCR utilise `github.actor` et `secrets.GITHUB_TOKEN`. Aucun
Personal Access Token n'est écrit dans le workflow ou les logs.

## Pull requests

Pour une pull request, l'image est construite afin de valider le Dockerfile,
mais elle n'est pas poussée dans GHCR :

```yaml
push: ${{ github.event_name != 'pull_request' }}
```

L'authentification au registre est également ignorée dans ce cas. Cela permet
aux contributions de vérifier le build sans obtenir de droit d'écriture sur le
registre.

## Publication des changements

Le workflow ops doit être fusionné ou publié sur la référence utilisée par les
applications avant les workflows backend et frontend. Avec la référence
actuelle `@main`, l'ordre est :

1. publier `msm-projet-06-ops` sur `main` ;
2. publier le workflow backend ;
3. publier le workflow frontend.

## Vérification

Sur une branche de test :

1. pousser un commit dans chaque application ;
2. vérifier que `test` réussit avant `build` ;
3. contrôler dans les logs le nom et le tag calculés ;
4. ouvrir l'onglet **Packages** de l'organisation GitHub ;
5. vérifier la présence des images backend et frontend avec un tag
   `branche-SHA`.

Sur une pull request, vérifier que le build réussit sans publication.

## Résultat attendu

- le même job `build` fonctionne pour les deux applications ;
- une image n'est construite qu'après la réussite des tests ;
- chaque push hors pull request publie une image dans GHCR ;
- le tag identifie clairement la branche et le commit ;
- les pull requests ne disposent pas d'un accès en écriture au registre ;
- le cache Buildx accélère les constructions suivantes.

