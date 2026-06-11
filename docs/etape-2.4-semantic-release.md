# Étape 2.4 - Automatiser les versions avec semantic-release

Cette étape centralise l'exécution de `semantic-release` dans le workflow
réutilisable `.github/workflows/release.yml`.

Après la réussite des jobs de test et de build sur `main`, le workflow analyse
les commits, calcule la prochaine version, génère le changelog et publie les
artefacts de l'application.

Le runner de release utilise Node.js 22.14 afin de respecter la version
minimale requise par la version actuelle de `semantic-release`. Le frontend
continue d'utiliser Node.js 20.19 pour ses jobs de test et de build.

## Enchaînement

```text
pipeline partagé (test -> build) -> release
```

Les applications appellent le workflow de release avec :

```yaml
release:
  needs: pipeline
  if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'
  permissions:
    contents: write
    issues: write
    pull-requests: write
    packages: write
  uses: msm-oc-projects/msm-projet-06-ops/.github/workflows/release.yml@main
  secrets:
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

Le release ne s'exécute donc ni sur une branche de développement ni sur une
pull request.

## Conventional Commits et versions

`semantic-release` détermine la version à partir des commits ajoutés depuis la
dernière release :

| Commit | Incrément |
|---|---|
| `fix(scope): description` | patch, par exemple `1.1.0` vers `1.1.1` |
| `feat(scope): description` | minor, par exemple `1.1.0` vers `1.2.0` |
| `feat(scope)!: description` | major, par exemple `1.1.0` vers `2.0.0` |
| Corps contenant `BREAKING CHANGE:` | major |
| `docs`, `chore`, `refactor`, `test`, `ci` | aucune release par défaut |

Exemples :

```text
fix(frontend): corriger le chargement des statistiques
feat(backend): ajouter la recherche des ateliers
feat(api)!: modifier le format des réponses
```

## Configuration par application

Chaque application conserve son fichier `release.config.cjs`, car les fichiers
dont la version doit être modifiée diffèrent :

- frontend : `package.json` et `package-lock.json` ;
- backend : `build.gradle`.

La configuration commune :

- publie uniquement depuis `main` ;
- crée des tags Git `v<version>` ;
- analyse les Conventional Commits ;
- génère les notes de version et `CHANGELOG.md` ;
- met à jour la version applicative ;
- crée un commit `chore(release): <version> [skip ci]` ;
- crée la release GitHub.

Le marqueur `[skip ci]` empêche le commit de version de déclencher une nouvelle
exécution complète du pipeline.

## Détection de la technologie

Le workflow partagé détecte :

- `package.json` pour le frontend npm/Angular ;
- `build.gradle` ou `build.gradle.kts` pour le backend Gradle/Java.

Il vérifie également la présence de `release.config.cjs`.

## Publication des artefacts

Lorsqu'une nouvelle version est créée :

### Frontend

- la version de `package.json` et `package-lock.json` est mise à jour ;
- le paquet npm est publié dans GitHub Packages ;
- l'image Docker est publiée dans GHCR avec le tag de version.

Exemple :

```text
@msm-oc-projects/olympic-games-starter@1.2.0
ghcr.io/msm-oc-projects/msm-projet-06-frontend:1.2.0
```

### Backend

- la version de `build.gradle` est mise à jour ;
- le WAR est publié dans le registre Maven GitHub Packages ;
- l'image Docker est publiée dans GHCR avec le tag de version.

Exemple :

```text
fr.oc.devops:workshop-organizer:1.2.0
ghcr.io/msm-oc-projects/msm-projet-06-backend:1.2.0
```

Si aucun commit ne nécessite de nouvelle version, le workflow se termine sans
publier de paquet ni d'image versionnée.

## Permissions et secrets

Le job demande uniquement les droits nécessaires à la release :

- `contents: write` pour le commit, le tag et la release GitHub ;
- `issues: write` et `pull-requests: write` pour les commentaires générés ;
- `packages: write` pour npm, Maven et GHCR.

Le jeton `GITHUB_TOKEN` est transmis explicitement au workflow réutilisable. Il
n'est jamais écrit dans un fichier versionné ni affiché dans les logs.

## Prérequis GitHub

- autoriser GitHub Actions à lire et écrire dans le dépôt ;
- permettre au dépôt ops privé d'être utilisé par les dépôts applicatifs ;
- vérifier que les règles de protection de `main` autorisent le compte GitHub
  Actions à créer le commit de release et le tag ;
- publier `release.yml` sur la référence appelée avant les workflows
  applicatifs.

## Vérification

1. Créer une branche de test.
2. Ajouter un commit `fix(...)` ou `feat(...)`.
3. Ouvrir et fusionner une pull request vers `main`.
4. Vérifier l'exécution du job `release`.
5. Contrôler le nouveau tag `v<version>` et la release GitHub.
6. Vérifier la mise à jour de `CHANGELOG.md` et de la version applicative.
7. Contrôler le paquet npm ou Maven dans GitHub Packages.
8. Contrôler l'image Docker versionnée dans GHCR.

## Résultat attendu

- la version est calculée automatiquement à partir des commits ;
- le changelog, le tag et la release GitHub sont générés ;
- les fichiers de version propres à chaque technologie sont mis à jour ;
- les paquets npm ou Maven sont publiés uniquement lors d'une nouvelle release ;
- les images Docker reçoivent le même tag SemVer ;
- aucune release n'est créée pour une pull request ou une branche autre que
  `main`.
