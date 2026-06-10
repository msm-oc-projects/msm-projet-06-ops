#!/usr/bin/env bash

# Validation locale complète du backend Spring Boot.
#
# Le script compile le code, exécute les tests unitaires, démarre une base
# PostgreSQL temporaire, lance Spring Boot puis appelle un endpoint réel.
# Toutes les ressources créées par le script sont supprimées à la fin.

# Échec immédiat sur commande invalide ou variable non initialisée.
set -eu

# Résolution des chemins indépendamment du répertoire courant de l'utilisateur.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validation.env"

# Ces indicateurs permettent au nettoyage de ne supprimer que les ressources
# réellement créées pendant cette exécution.
BACKEND_PID=""
DB_CREATED=0

log() {
    printf '[validate-backend] %s\n' "$*"
}

cleanup() {
    # Arrête uniquement le processus Spring Boot lancé en arrière-plan par ce
    # script. `kill -0` vérifie d'abord qu'il existe encore.
    if [ -n "${BACKEND_PID}" ] && kill -0 "${BACKEND_PID}" 2>/dev/null; then
        # Gradle peut démarrer la JVM Spring Boot comme processus enfant.
        if command -v pkill >/dev/null 2>&1; then
            pkill -TERM -P "${BACKEND_PID}" 2>/dev/null || true
        fi
        kill "${BACKEND_PID}" 2>/dev/null || true
        wait "${BACKEND_PID}" 2>/dev/null || true
    fi

    # La base n'est supprimée que si `docker run` a réussi et que DB_CREATED a
    # été positionné à 1. Un conteneur externe n'est donc jamais touché.
    if [ "${DB_CREATED}" -eq 1 ]; then
        docker rm -f "${DB_CONTAINER}" >/dev/null 2>&1 || true
    fi
}

# Interroge une URL jusqu'à recevoir un statut HTTP 2xx ou épuiser le nombre
# d'essais. Une pause de deux secondes évite de solliciter le serveur en boucle.
wait_for_url() {
    local url=$1
    local attempts=${2:-60}
    local status

    while [ "${attempts}" -gt 0 ]; do
        # Le corps de la réponse est ignoré ; seul le code HTTP est nécessaire
        # pour confirmer que l'application accepte les requêtes.
        status=$(curl -sS -o /dev/null -w '%{http_code}' "${url}" || true)
        case "${status}" in
            2??) return 0 ;;
        esac
        attempts=$((attempts - 1))
        sleep 2
    done

    return 1
}

# L'initialisation du rapport installe le trap EXIT qui appellera cleanup avant
# d'écrire le rapport final.
source "${SCRIPT_DIR}/reporting.sh"
init_report "backend-validation" "Validation locale du backend"
BACKEND_LOG="${REPORTS_DIR}/backend-runtime-${REPORT_RUN_ID}.log"

# Vérifications légères avant les opérations longues.
command -v docker >/dev/null 2>&1 || { log "Docker est requis"; exit 1; }
command -v curl >/dev/null 2>&1 || { log "curl est requis"; exit 1; }
[ -f "${BACKEND_DIR}/gradlew" ] || { log "Gradle Wrapper introuvable"; exit 1; }

mkdir -p "${SCRIPT_DIR}/execution-reports"

# compileJava déclenche aussi la génération OpenAPI déclarée dans build.gradle.
report_step "Compilation du backend"
log "Compilation du backend"
(cd "${BACKEND_DIR}" && ./gradlew clean compileJava --no-daemon)

# Les tests sont séparés de la compilation afin que le rapport indique
# clairement quelle étape a échoué. L'orchestrateur complet peut les ignorer
# lorsqu'ils viennent déjà d'être exécutés par run-tests.sh.
if [ "${SKIP_UNIT_TESTS:-0}" != "1" ]; then
    report_step "Tests unitaires du backend"
    log "Tests unitaires du backend"
    (cd "${BACKEND_DIR}" && ./gradlew test --no-daemon)
else
    log "Tests unitaires déjà exécutés : étape ignorée"
fi

# Refuse de réutiliser un ancien conteneur du même nom : cela garantit que la
# validation part d'une base connue et que le nettoyage reste prévisible.
if docker container inspect "${DB_CONTAINER}" >/dev/null 2>&1; then
    log "Le conteneur ${DB_CONTAINER} existe deja"
    exit 1
fi

report_step "Demarrage de PostgreSQL"
log "Demarrage de PostgreSQL 13"
docker run -d \
    --name "${DB_CONTAINER}" \
    -e POSTGRES_USER="${DB_USER}" \
    -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
    -e POSTGRES_DB="${DB_NAME}" \
    -p "${DATABASE_PORT}:${DB_CONTAINER_PORT}" \
    "${DB_IMAGE}" >/dev/null
DB_CREATED=1

# `docker run` indique seulement que le conteneur est lancé. pg_isready vérifie
# que PostgreSQL est réellement prêt à accepter des connexions.
attempts="${DATABASE_WAIT_ATTEMPTS}"
until docker exec "${DB_CONTAINER}" pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; do
    attempts=$((attempts - 1))
    [ "${attempts}" -gt 0 ] || { log "PostgreSQL ne repond pas"; exit 1; }
    sleep 2
done

report_step "Demarrage et controle du backend"
log "Demarrage local du backend"

# Spring Boot reste au premier plan normalement. Il est donc placé en
# arrière-plan et son PID est mémorisé pour pouvoir l'arrêter dans cleanup.
# Sa sortie applicative est isolée dans un journal dédié.
(
    cd "${BACKEND_DIR}"
    SPRING_DATASOURCE_URL="jdbc:postgresql://localhost:${DATABASE_PORT}/${DB_NAME}" \
    SPRING_DATASOURCE_USERNAME="${DB_USER}" \
    SPRING_DATASOURCE_PASSWORD="${DB_PASSWORD}" \
        ./gradlew bootRun --no-daemon
) >"${BACKEND_LOG}" 2>&1 &
BACKEND_PID=$!

# L'endpoint /api/workshops existe dans la spécification OpenAPI du projet.
# Actuator n'étant pas installé, /actuator/health ne serait pas un test valide.
if ! wait_for_url "${BACKEND_URL}" "${BACKEND_WAIT_ATTEMPTS}"; then
    log "Le backend ne repond pas. Voir ${BACKEND_LOG}"
    exit 1
fi

log "Backend valide sur ${BACKEND_URL}"
report_step "Validation terminee"
