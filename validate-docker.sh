#!/usr/bin/env bash

# Validation des images et stacks Docker du backend et du frontend.
#
# Deux projets Compose distincts sont utilisés pour isoler les noms de réseaux,
# volumes et conteneurs. Par défaut, tout est arrêté après les contrôles.
# Définir KEEP_CONTAINERS=1 permet de conserver les services pour inspection.

set -eu

# Localisation des deux projets frères depuis le dépôt Ops.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validation.env"

log() {
    printf '[validate-docker] %s\n' "$*"
}

# Petit adaptateur pour garder les commandes Compose lisibles et centraliser
# l'appel à `docker compose`.
compose() {
    docker compose "$@"
}

cleanup() {
    # Mode de diagnostic : laisse volontairement les conteneurs actifs afin que
    # l'utilisateur puisse examiner `docker ps`, les logs ou les volumes.
    if [ "${KEEP_CONTAINERS:-0}" = "1" ]; then
        log "KEEP_CONTAINERS=1 : conteneurs conserves"
        return
    fi

    # Le frontend est arrêté avant le backend. Les erreurs de nettoyage sont
    # ignorées pour préserver le vrai code de sortie de la validation.
    compose -p "${FRONTEND_COMPOSE_PROJECT}" -f "${FRONTEND_COMPOSE_FILE}" down --remove-orphans >/dev/null 2>&1 || true
    compose -p "${BACKEND_COMPOSE_PROJECT}" -f "${BACKEND_COMPOSE_FILE}" down --remove-orphans >/dev/null 2>&1 || true
}

# Attend que le service HTTP soit réellement disponible. Le statut du
# conteneur seul ne garantit pas que l'application est prête.
wait_for_url() {
    local url=$1
    local attempts=${2:-90}
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
init_report "docker-validation" "Validation des stacks Docker"

# Vérifie à la fois la présence du client Docker et l'accès au moteur.
command -v docker >/dev/null 2>&1 || { log "Docker est requis"; exit 1; }
command -v curl >/dev/null 2>&1 || { log "curl est requis"; exit 1; }
docker info >/dev/null 2>&1 || { log "Le moteur Docker est inaccessible"; exit 1; }

report_step "Build et demarrage Docker du backend"
log "Build et demarrage du backend avec PostgreSQL"

# --build force la prise en compte des Dockerfiles et du code courant.
# Compose attend le healthcheck PostgreSQL avant de démarrer Spring Boot.
compose -p "${BACKEND_COMPOSE_PROJECT}" -f "${BACKEND_COMPOSE_FILE}" up -d --build

# En cas d'échec, les logs Compose sont affichés avant la génération du rapport.
if ! wait_for_url "${BACKEND_URL}" "${DOCKER_BACKEND_WAIT_ATTEMPTS}"; then
    compose -p "${BACKEND_COMPOSE_PROJECT}" -f "${BACKEND_COMPOSE_FILE}" logs
    log "Le backend Docker ne repond pas"
    exit 1
fi

report_step "Build et demarrage Docker du frontend"
log "Build et demarrage du frontend NGINX"

# Le frontend utilise une image multi-stage : compilation Node puis service
# statique avec NGINX.
compose -p "${FRONTEND_COMPOSE_PROJECT}" -f "${FRONTEND_COMPOSE_FILE}" up -d --build

if ! wait_for_url "${DOCKER_FRONTEND_URL}" "${DOCKER_FRONTEND_WAIT_ATTEMPTS}"; then
    compose -p "${FRONTEND_COMPOSE_PROJECT}" -f "${FRONTEND_COMPOSE_FILE}" logs
    log "Le frontend Docker ne repond pas"
    exit 1
fi

# Vérifie aussi un asset réel afin de détecter une copie incomplète du dossier
# dist dans l'image NGINX.
if ! wait_for_url "${DOCKER_FRONTEND_ASSET_URL}" "${ASSET_WAIT_ATTEMPTS}"; then
    log "La ressource olympic.json est inaccessible via NGINX"
    exit 1
fi

log "Images et conteneurs Docker valides"
report_step "Validation terminee"
