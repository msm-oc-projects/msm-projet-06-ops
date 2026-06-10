#!/usr/bin/env bash
set -u

# Lance les tests des projets frères sans coder en dur leur technologie.
#
# Règles de détection :
# - package.json  -> projet npm ;
# - build.gradle  -> projet Gradle.
#
# Les rapports JUnit XML sont regroupés sous test-results/ afin de fournir un
# emplacement unique pour la CI et pour l'analyse manuelle.

# Chemins calculés depuis le script afin de permettre un lancement depuis
# n'importe quel répertoire.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validation.env"
RESULTS_DIR="${SCRIPT_DIR}/test-results"

# Active un rapport d'exécution distinct des rapports JUnit des frameworks.
source "${SCRIPT_DIR}/reporting.sh"
init_report "tests-validation" "Tests backend et frontend"

log() {
  printf '[run-tests] %s\n' "$*"
}

# Compte le nombre de projets ayant retourné un échec. Le script continue avec
# le projet suivant afin de fournir un bilan complet backend + frontend.
failures=0

# Vérifie explicitement les commandes requises et produit un message lisible
# plutôt que de laisser Bash échouer avec "command not found".
require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "ERROR: required command not found: ${command_name}"
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
  log "${project_name}: detected npm project"

  require_command npm || return 1

  # Évite un npm ci inutile si node_modules est déjà présent. Lorsqu'une
  # installation est nécessaire, le lockfile est obligatoire pour garantir
  # les mêmes versions en local et en CI.
  if [ ! -d "${project_dir}/node_modules" ]; then
    if [ ! -f "${project_dir}/package-lock.json" ]; then
      log "ERROR: ${project_name}: node_modules is missing and package-lock.json was not found"
      return 1
    fi

    log "${project_name}: installing dependencies with npm ci"
    (cd "${project_dir}" && npm ci --cache .npm --prefer-offline) || return $?
  fi

  rm -rf "${project_dir}/reports"

  # Supprime uniquement les rapports Karma précédents, puis lance la commande
  # définie par le projet. Le code de sortie est conservé avant la copie.
  log "${project_name}: running npm test"
  (cd "${project_dir}" && npm test)
  status=$?

  report_count="$(copy_xml_reports "${project_dir}/reports" "${RESULTS_DIR}/${project_name}")"
  if [ "${report_count}" -eq 0 ]; then
    log "ERROR: ${project_name}: no JUnit XML report found in reports/"
    [ "${status}" -ne 0 ] && return "${status}"
    return 1
  fi

  log "${project_name}: copied ${report_count} JUnit XML report(s)"
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
  log "${project_name}: detected Gradle project"

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
    log "ERROR: ${project_name}: neither Gradle wrapper nor gradle command was found"
    return 1
  fi

  rm -rf "${project_dir}/build/test-results"

  # Nettoie les anciens résultats avant d'exécuter la suite JUnit Platform.
  log "${project_name}: running ${gradle_cmd[*]}"
  (cd "${project_dir}" && "${gradle_cmd[@]}")
  status=$?

  report_count="$(copy_xml_reports "${project_dir}/build/test-results/test" "${RESULTS_DIR}/${project_name}")"
  if [ "${report_count}" -eq 0 ]; then
    log "ERROR: ${project_name}: no JUnit XML report found in build/test-results/test/"
    [ "${status}" -ne 0 ] && return "${status}"
    return 1
  fi

  log "${project_name}: copied ${report_count} JUnit XML report(s)"
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
    log "$(basename "${project_dir}"): tests failed with exit code ${status}"
    failures=$((failures + 1))
  else
    log "$(basename "${project_dir}"): tests passed"
  fi
}

clean_previous_results

report_step "Detection et execution des tests"
found_projects=0
# Seuls les dossiers frères msm-projet-06-* sont parcourus. Le dépôt Ops ne
# possède ni package.json ni build.gradle et n'est donc pas traité comme app.
for project_name in ${TEST_PROJECT_NAMES}; do
  project_dir="${PROJECT_ROOT}/${project_name}"
  [ -d "${project_dir}" ] || continue

  if [ -f "${project_dir}/package.json" ] || [ -f "${project_dir}/build.gradle" ]; then
    found_projects=$((found_projects + 1))
    run_project_tests "${project_dir}"
  fi
done

# Aucun projet détecté signifie généralement que les trois dépôts ne sont pas
# placés côte à côte comme attendu.
if [ "${found_projects}" -eq 0 ]; then
  log "ERROR: no npm or Gradle project found"
  exit 1
fi

# Le script échoue si au moins un projet a échoué, même si l'autre a réussi.
if [ "${failures}" -ne 0 ]; then
  log "completed with ${failures} failing project(s)"
  exit 1
fi

log "all tests passed; reports are available in ${RESULTS_DIR}"
report_step "Tests termines"
