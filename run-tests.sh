#!/usr/bin/env bash

# Exécuteur autonome des tests unitaires backend et frontend.
#
# Règles de détection :
# - package.json  -> projet npm ;
# - build.gradle  -> projet Gradle.
#
# Les rapports JUnit XML sont regroupés sous test-results/ afin de fournir un
# emplacement unique pour la CI et pour l'analyse manuelle.
#
# Utilisation :
#   ./run-tests.sh
#   TEST_PROJECT_NAMES=msm-projet-06-backend ./run-tests.sh
#   TEST_PROJECT_NAMES=msm-projet-06-frontend ./run-tests.sh
#
# Variables :
# - `PROJECT_ROOT` : dossier parent des dépôts frères ;
# - `BACKEND_PROJECT_NAME` et `FRONTEND_PROJECT_NAME` : noms des dépôts ;
# - `TEST_PROJECT_NAMES` : liste séparée par des espaces des projets à tester.
#
# Comportement :
# - réinstalle les dépendances npm avec `npm ci` pour garantir la plateforme et
#   les versions décrites par le lockfile ;
# - privilégie toujours le wrapper Gradle du projet ;
# - continue avec le second projet lorsque le premier échoue ;
# - signale comme erreur un projet demandé mais absent ;
# - exige au moins un rapport JUnit XML par projet testé ;
# - retourne 1 si un projet échoue ou si aucun projet n'est détecté.
#
# `set -u` transforme toute variable non initialisée en erreur. `set -e` n'est
# volontairement pas utilisé car le script doit collecter les échecs des deux
# projets avant de produire son bilan.
set -u

# Chemins calculés depuis le script afin de permettre un lancement depuis
# n'importe quel répertoire.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
BACKEND_PROJECT_NAME="${BACKEND_PROJECT_NAME:-msm-projet-06-backend}"
FRONTEND_PROJECT_NAME="${FRONTEND_PROJECT_NAME:-msm-projet-06-frontend}"
TEST_PROJECT_NAMES="${TEST_PROJECT_NAMES:-${BACKEND_PROJECT_NAME} ${FRONTEND_PROJECT_NAME}}"
RESULTS_DIR="${SCRIPT_DIR}/test-results"

# Tous les messages portent un préfixe stable, pratique dans les logs CI.
log() {
  printf '[run-tests] %s\n' "$*"
}

# Compte le nombre de projets ayant retourné un échec. Le script continue avec
# le projet suivant afin de fournir un bilan complet backend + frontend.
failures=0
requested_projects=0
found_projects=0

# Vérifie explicitement les commandes requises et produit un message lisible
# plutôt que de laisser Bash échouer avec "command not found".
require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "ERREUR : commande requise introuvable : ${command_name}"
    return 1
  fi

  return 0
}

clean_previous_results() {
  # Supprime les anciennes copies JUnit pour éviter de mélanger deux exécutions
  # et de publier des résultats périmés dans la CI.
  rm -rf "${RESULTS_DIR}"
  mkdir -p "${RESULTS_DIR}"
}

# Copie récursivement les XML produits par le framework vers un dossier commun.
# Le compteur retourné permet de considérer l'absence de rapport comme un échec.
copy_xml_reports() {
  local source_dir="$1"
  local destination_dir="$2"
  local count=0

  mkdir -p "${destination_dir}"

  # `find -print0` et `read -d ''` préservent correctement les chemins contenant
  # des espaces ou des caractères spéciaux.
  if [ -d "${source_dir}" ]; then
    while IFS= read -r -d '' report; do
      cp "${report}" "${destination_dir}/"
      count=$((count + 1))
    done < <(find "${source_dir}" -type f -name '*.xml' -print0)
  fi

  printf '%s' "${count}"
}

run_npm_tests() {
  local project_dir="$1"
  local project_name
  local report_count
  local status

  project_name="$(basename "${project_dir}")"
  log "${project_name} : projet npm détecté"

  require_command npm || return 1

  # Le lockfile est obligatoire : `npm ci` supprime node_modules puis recrée
  # une installation adaptée au système courant. Cela évite notamment de
  # réutiliser sous Windows des binaires natifs installés sous WSL, ou inversement.
  if [ ! -f "${project_dir}/package-lock.json" ]; then
    log "ERREUR : ${project_name} : package-lock.json introuvable"
    return 1
  fi

  log "${project_name} : installation reproductible des dépendances avec npm ci"
  (cd "${project_dir}" && npm ci --cache .npm --prefer-offline) || return $?

  rm -rf "${project_dir}/reports"

  # Supprime uniquement les rapports Karma précédents, puis lance la commande
  # définie par le projet. Le code de sortie est conservé avant la copie.
  log "${project_name} : exécution de npm test"
  (cd "${project_dir}" && npm test)
  status=$?

  report_count="$(copy_xml_reports "${project_dir}/reports" "${RESULTS_DIR}/${project_name}")"
  if [ "${report_count}" -eq 0 ]; then
    log "ERREUR : ${project_name} : aucun rapport JUnit XML trouvé dans reports/"
    [ "${status}" -ne 0 ] && return "${status}"
    return 1
  fi

  log "${project_name} : ${report_count} rapport(s) JUnit XML copié(s)"
  return "${status}"
}

# Exécute les tests Java avec l'outil le plus reproductible disponible.
run_gradle_tests() {
  local project_dir="$1"
  local project_name
  local gradle_cmd
  local report_count
  local status

  project_name="$(basename "${project_dir}")"
  log "${project_name} : projet Gradle détecté"

  require_command java || return 1

  # Priorité au wrapper Unix, puis au wrapper Windows sous WSL, puis à une
  # installation Gradle globale en dernier recours.
  if [ -f "${project_dir}/gradlew" ]; then
    chmod +x "${project_dir}/gradlew" 2>/dev/null || true
    gradle_cmd=("./gradlew" "clean" "test" "--no-daemon")
  elif [ -f "${project_dir}/gradlew.bat" ] && command -v cmd.exe >/dev/null 2>&1; then
    gradle_cmd=("cmd.exe" "/c" "gradlew.bat" "clean" "test" "--no-daemon")
  elif command -v gradle >/dev/null 2>&1; then
    gradle_cmd=("gradle" "clean" "test" "--no-daemon")
  else
    log "ERREUR : ${project_name} : aucun wrapper Gradle ni commande gradle disponible"
    return 1
  fi

  rm -rf "${project_dir}/build/test-results"

  # Nettoie les anciens résultats avant d'exécuter la suite JUnit Platform.
  log "${project_name} : exécution de ${gradle_cmd[*]}"
  (cd "${project_dir}" && "${gradle_cmd[@]}")
  status=$?

  report_count="$(copy_xml_reports "${project_dir}/build/test-results/test" "${RESULTS_DIR}/${project_name}")"
  if [ "${report_count}" -eq 0 ]; then
    log "ERREUR : ${project_name} : aucun rapport JUnit XML trouvé dans build/test-results/test/"
    [ "${status}" -ne 0 ] && return "${status}"
    return 1
  fi

  log "${project_name} : ${report_count} rapport(s) JUnit XML copié(s)"
  return "${status}"
}

# Sélectionne le moteur de test à partir des fichiers présents à la racine du
# projet et met à jour le compteur global sans interrompre les autres projets.
run_project_tests() {
  local project_dir="$1"
  local status=0

  if [ -f "${project_dir}/package.json" ]; then
    run_npm_tests "${project_dir}"
    status=$?
  elif [ -f "${project_dir}/build.gradle" ]; then
    run_gradle_tests "${project_dir}"
    status=$?
  else
    return 0
  fi

  if [ "${status}" -ne 0 ]; then
    log "$(basename "${project_dir}") : tests en échec avec le code ${status}"
    failures=$((failures + 1))
  else
    log "$(basename "${project_dir}") : tests réussis"
  fi
}

clean_previous_results

# Seuls les dossiers frères msm-projet-06-* sont parcourus. Le dépôt Ops ne
# possède ni package.json ni build.gradle et n'est donc pas traité comme app.
for project_name in ${TEST_PROJECT_NAMES}; do
  requested_projects=$((requested_projects + 1))
  project_dir="${PROJECT_ROOT}/${project_name}"

  if [ ! -d "${project_dir}" ]; then
    log "ERREUR : projet demandé introuvable : ${project_dir}"
    failures=$((failures + 1))
    continue
  fi

  if [ -f "${project_dir}/package.json" ] || [ -f "${project_dir}/build.gradle" ]; then
    found_projects=$((found_projects + 1))
    run_project_tests "${project_dir}"
  else
    log "ERREUR : ${project_name} : aucun package.json ni build.gradle détecté"
    failures=$((failures + 1))
  fi
done

# Une liste vide est probablement une mauvaise surcharge de TEST_PROJECT_NAMES.
if [ "${requested_projects}" -eq 0 ]; then
  log "ERREUR : aucun projet demandé dans TEST_PROJECT_NAMES"
  exit 1
fi

# Le script échoue si au moins un projet a échoué, même si l'autre a réussi.
if [ "${failures}" -ne 0 ]; then
  log "Bilan : ${found_projects}/${requested_projects} projet(s) détecté(s), ${failures} échec(s)"
  exit 1
fi

log "Bilan : ${found_projects}/${requested_projects} projet(s) détecté(s), aucun échec"
log "Tous les tests ont réussi ; rapports disponibles dans ${RESULTS_DIR}"
