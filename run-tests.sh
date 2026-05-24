#!/usr/bin/env bash
set -u

# This script lives in msm-projet-06-ops and runs tests for sibling projects.
# It is intentionally generic: a package.json means npm, a build.gradle means Gradle.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/test-results"

log() {
  printf '[run-tests] %s\n' "$*"
}

failures=0

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "ERROR: required command not found: ${command_name}"
    return 1
  fi

  return 0
}

clean_previous_results() {
  # Keep CI artifacts deterministic by removing reports from previous runs.
  rm -rf "${RESULTS_DIR}"
  mkdir -p "${RESULTS_DIR}"
}

copy_xml_reports() {
  local source_dir="$1"
  local destination_dir="$2"
  local count=0

  mkdir -p "${destination_dir}"

  # GitHub Actions can consume JUnit XML from a single artifact directory.
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

  # Prefer the README command, but install dependencies first when needed.
  if [ ! -d "${project_dir}/node_modules" ]; then
    if [ ! -f "${project_dir}/package-lock.json" ]; then
      log "ERROR: ${project_name}: node_modules is missing and package-lock.json was not found"
      return 1
    fi

    log "${project_name}: installing dependencies with npm ci"
    (cd "${project_dir}" && npm ci --cache .npm --prefer-offline) || return $?
  fi

  rm -rf "${project_dir}/reports"

  # Frontend README test command. Karma writes JUnit XML into reports/.
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

run_gradle_tests() {
  local project_dir="$1"
  local project_name
  local gradle_cmd
  local report_count
  local status

  project_name="$(basename "${project_dir}")"
  log "${project_name}: detected Gradle project"

  require_command java || return 1

  # Use the Gradle wrapper when available so CI uses the project-pinned Gradle version.
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

  # Backend README test command. Gradle writes JUnit XML into build/test-results/test/.
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

found_projects=0
# Only sibling project folders are scanned; ops itself is not treated as an app.
for project_dir in "${ROOT_DIR}"/msm-projet-06-*; do
  [ -d "${project_dir}" ] || continue

  if [ -f "${project_dir}/package.json" ] || [ -f "${project_dir}/build.gradle" ]; then
    found_projects=$((found_projects + 1))
    run_project_tests "${project_dir}"
  fi
done

if [ "${found_projects}" -eq 0 ]; then
  log "ERROR: no npm or Gradle project found"
  exit 1
fi

if [ "${failures}" -ne 0 ]; then
  log "completed with ${failures} failing project(s)"
  exit 1
fi

log "all tests passed; reports are available in ${RESULTS_DIR}"
