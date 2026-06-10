#!/usr/bin/env bash

# Orchestration complète des validations du projet.
#
# Ordre d'exécution :
# 1. vérification de l'environnement ;
# 2. tests unitaires backend et frontend ;
# 3. validation fonctionnelle du backend local ;
# 4. validation fonctionnelle du frontend local ;
# 5. construction et validation des stacks Docker.
#
# Chaque étape est bloquante. La chaîne s'arrête immédiatement dès qu'un
# script retourne un code différent de zéro.

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validation.env"

log() {
    printf '[validate-all] %s\n' "$*"
}

# Exécute une étape en conservant son libellé dans le rapport global.
run_validation() {
    local label=$1
    shift

    report_step "${label}"
    log "${label}"

    if ! "$@"; then
        log "Échec pendant l'étape : ${label}"
        return 1
    fi
}

source "${SCRIPT_DIR}/reporting.sh"
init_report "all-validation" "Validation complete du projet"

run_validation \
    "Verification de l'environnement" \
    bash "${SCRIPT_DIR}/verify-environment.sh"

run_validation \
    "Tests unitaires backend et frontend" \
    bash "${SCRIPT_DIR}/run-tests.sh"

# Les tests viennent d'être exécutés par run-tests.sh. Cette variable évite de
# les rejouer dans les validations locales, tout en conservant leur exécution
# normale lorsque validate-backend.sh ou validate-frontend.sh est lancé seul.
run_validation \
    "Validation fonctionnelle du backend" \
    env SKIP_UNIT_TESTS=1 bash "${SCRIPT_DIR}/validate-backend.sh"

run_validation \
    "Validation fonctionnelle du frontend" \
    env SKIP_UNIT_TESTS=1 bash "${SCRIPT_DIR}/validate-frontend.sh"

run_validation \
    "Validation des images et stacks Docker" \
    bash "${SCRIPT_DIR}/validate-docker.sh"

report_step "Validation terminee"
log "Toutes les validations ont réussi"
