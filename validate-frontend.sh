#!/usr/bin/env bash

# Validation locale complète du frontend Angular.
#
# Le script réinstalle les dépendances depuis le lockfile, lance les tests,
# produit le build de production, démarre le serveur de développement et
# contrôle la page principale ainsi qu'une ressource JSON utilisée par l'app.

set -eu

# Chemins absolus calculés depuis l'emplacement du script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validation.env"
FRONTEND_PID=""

log() {
    printf '[validate-frontend] %s\n' "$*"
}

cleanup() {
    # npm start lance un serveur persistant. Son PID est conservé pour garantir
    # son arrêt même si un contrôle HTTP échoue ou si l'utilisateur fait Ctrl+C.
    if [ -n "${FRONTEND_PID}" ] && kill -0 "${FRONTEND_PID}" 2>/dev/null; then
        # npm peut démarrer Angular comme processus enfant.
        if command -v pkill >/dev/null 2>&1; then
            pkill -TERM -P "${FRONTEND_PID}" 2>/dev/null || true
        fi
        kill "${FRONTEND_PID}" 2>/dev/null || true
        wait "${FRONTEND_PID}" 2>/dev/null || true
    fi
}

# Attend une réponse HTTP 2xx avec un délai maximal configurable.
wait_for_url() {
    local url=$1
    local attempts=${2:-60}
    local status

    while [ "${attempts}" -gt 0 ]; do
        status=$(curl -sS -o /dev/null -w '%{http_code}' "${url}" || true)
        case "${status}" in
            2??) return 0 ;;
        esac
        attempts=$((attempts - 1))
        sleep 2
    done

    return 1
}

source "${SCRIPT_DIR}/reporting.sh"
init_report "frontend-validation" "Validation locale du frontend"

# Les logs Angular sont volumineux ; ils sont placés dans un fichier distinct
# du journal général pour faciliter le diagnostic d'un démarrage échoué.
FRONTEND_LOG="${REPORTS_DIR}/frontend-runtime-${REPORT_RUN_ID}.log"

# npm, curl et le lockfile sont indispensables à une exécution reproductible.
command -v npm >/dev/null 2>&1 || { log "npm est requis"; exit 1; }
command -v curl >/dev/null 2>&1 || { log "curl est requis"; exit 1; }
[ -f "${FRONTEND_LOCK_FILE}" ] || { log "${FRONTEND_LOCK_FILE} introuvable"; exit 1; }

mkdir -p "${SCRIPT_DIR}/execution-reports"

# npm ci supprime et recrée node_modules conformément à package-lock.json.
# Le cache local accélère les exécutions suivantes sans modifier les versions.
report_step "Installation des dependances"
log "Installation reproductible des dependances"
(cd "${FRONTEND_DIR}" && npm ci --cache .npm --prefer-offline)

# Les tests Karma sont configurés avec `--watch false` dans package.json.
# L'orchestrateur complet peut les ignorer après le passage de run-tests.sh.
if [ "${SKIP_UNIT_TESTS:-0}" != "1" ]; then
    report_step "Tests unitaires du frontend"
    log "Tests unitaires du frontend"
    (cd "${FRONTEND_DIR}" && npm test)
else
    log "Tests unitaires déjà exécutés : étape ignorée"
fi

# Le build de production valide également TypeScript, les templates Angular,
# les styles et les limites de taille configurées dans angular.json.
report_step "Build de production du frontend"
log "Build de production du frontend"
(cd "${FRONTEND_DIR}" && npm run build)

report_step "Demarrage et controle du frontend"
log "Demarrage du serveur Angular"

# Le serveur est limité à 127.0.0.1 : il reste accessible localement sans être
# exposé sur toutes les interfaces réseau de la machine.
(cd "${FRONTEND_DIR}" && npm start -- --host 127.0.0.1 --port "${FRONTEND_PORT}") >"${FRONTEND_LOG}" 2>&1 &
FRONTEND_PID=$!

# Le premier contrôle confirme que l'application est servie.
if ! wait_for_url "${FRONTEND_URL}" "${FRONTEND_WAIT_ATTEMPTS}"; then
    log "Le frontend ne repond pas. Voir ${FRONTEND_LOG}"
    exit 1
fi

# Le second confirme que les assets Angular sont bien copiés et accessibles.
if ! wait_for_url "${FRONTEND_ASSET_URL}" "${ASSET_WAIT_ATTEMPTS}"; then
    log "La ressource olympic.json est inaccessible"
    exit 1
fi

log "Frontend valide sur ${FRONTEND_URL}"
report_step "Validation terminee"
