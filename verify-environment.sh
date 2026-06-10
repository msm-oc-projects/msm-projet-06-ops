#!/usr/bin/env bash
#
# Vérification préalable de l'environnement de développement.
#
# Ce script contrôle les outils, versions, ports et fichiers nécessaires avant
# les compilations et tests applicatifs. Il ne modifie pas les projets et ne
# démarre aucun service persistant.
#
# Compatibilité visée : Linux, macOS et WSL avec Bash.
# Un rapport Markdown et un journal complet sont générés automatiquement.

# Les contrôles doivent tous être exécutés pour produire un bilan complet.
# `set +e` empêche donc un contrôle négatif d'interrompre prématurément le
# script. Les erreurs bloquantes sont comptées puis traitées dans le résumé.
set +e

# Le script peut être lancé depuis n'importe quel répertoire. Il se replace à
# la racine commune contenant backend, frontend et ops afin que tous les chemins
# relatifs utilisés plus bas restent stables.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validation.env"
cd "$PROJECT_ROOT" || exit 1

# Codes ANSI utilisés uniquement pour rendre la sortie terminal plus lisible.
# Les informations restent également disponibles sans couleur dans le rapport.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Compteurs globaux alimentés exclusivement par check_result.
# PASSED   : contrôle conforme ;
# WARNINGS : situation non bloquante ou élément optionnel ;
# FAILED   : prérequis indispensable absent ou invalide.
PASSED=0
FAILED=0
WARNINGS=0

# Initialise la journalisation avant le premier affichage du script.
source "${SCRIPT_DIR}/reporting.sh"
init_report "environment-verification" "Verification de l'environnement"

# Point central d'affichage et de comptage.
# Les autres fonctions ne modifient jamais directement les compteurs, ce qui
# évite les doubles comptages lors de l'ajout de nouveaux contrôles.
check_result() {
    local tool=$1
    local status=$2
    local details=$3
    
    # Le statut est volontairement explicite dans chaque appel afin que la
    # gravité d'un contrôle reste visible à l'endroit où il est défini.
    case "$status" in
        "✅")
            echo -e "${GREEN}✅ $tool${NC} $status"
            ((PASSED++))
            ;;
        "❌")
            echo -e "${RED}❌ $tool${NC} $status"
            ((FAILED++))
            ;;
        "⚠️")
            echo -e "${YELLOW}⚠️  $tool${NC} $status"
            ((WARNINGS++))
            ;;
        *)
            echo -e "${CYAN}ℹ️  $tool${NC} $status"
            ((WARNINGS++))
            ;;
    esac
    
    # La ligne de détail apporte la version, le chemin ou la correction à faire.
    if [ -n "$details" ]; then
        echo -e "   ${CYAN}└─ $details${NC}"
    fi
}

# Vérifie la présence d'une commande et compare sa version minimale.
#
# Paramètres :
# 1. libellé affiché ;
# 2. nom de la commande ;
# 3. version minimale, ou chaîne vide si seule la présence est requise.
check_tool() {
    local tool_name=$1
    local command=$2
    local min_version=$3
    
    # `command -v` fonctionne pour les exécutables, alias et fonctions sans
    # dépendre d'un emplacement particulier dans PATH.
    if ! command -v "$command" &> /dev/null; then
        check_result "$tool_name" "❌" "Outil non installé"
        return 1
    fi
    
    # Toutes les commandes contrôlées acceptent --version. L'appel est protégé
    # pour ne pas interrompre le bilan si un outil retourne un code atypique.
    local version_output
    version_output=$("$command" --version 2>&1 || true)
    
    # Extrait le premier numéro de version sémantique rencontré dans la sortie.
    local version
    version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    
    if [ -n "$version" ]; then
        # sort -V compare correctement 20.11 et 9.2, contrairement à une
        # comparaison alphabétique classique.
        if [ -n "$min_version" ] && [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -n1)" = "$min_version" ]; then
            check_result "$tool_name" "✅" "Version: $version"
            return 0
        elif [ -z "$min_version" ]; then
            check_result "$tool_name" "✅" "Version: $version"
            return 0
        else
            check_result "$tool_name" "⚠️" "Version: $version (attendu: $min_version+)"
            return 0
        fi
    else
        check_result "$tool_name" "✅" "$version_output"
        return 0
    fi
}

# Docker Compose est aujourd'hui généralement fourni comme sous-commande
# `docker compose`. L'ancien binaire `docker-compose` reste accepté pour les
# environnements qui l'utilisent encore.
check_docker_compose() {
    local version_output
    local version

    if docker compose version >/dev/null 2>&1; then
        version_output=$(docker compose version --short 2>&1 || true)
    elif command -v docker-compose >/dev/null 2>&1; then
        version_output=$(docker-compose version --short 2>&1 || true)
    else
        check_result "Docker Compose" "❌" "Commande docker compose non installée"
        return 1
    fi

    version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [ -z "$version" ]; then
        check_result "Docker Compose" "✅" "$version_output"
    elif [ "$(printf '%s\n' "${MIN_DOCKER_COMPOSE_VERSION}" "$version" | sort -V | head -n1)" = "${MIN_DOCKER_COMPOSE_VERSION}" ]; then
        check_result "Docker Compose" "✅" "Version: $version"
    else
        check_result "Docker Compose" "⚠️" "Version: $version (attendu: ${MIN_DOCKER_COMPOSE_VERSION}+)"
    fi
}

# Vérifie qu'un port attendu pour un futur service est encore libre.
# Un port occupé est un avertissement : l'environnement existe, mais le script
# de validation concerné pourrait ne pas réussir à démarrer son serveur.
check_port() {
    local port=$1
    local service=$2
    local port_in_use
    
    # Seules les sockets TCP en écoute sont recherchées. Les connexions clientes
    # temporaires ne doivent pas être considérées comme un conflit.
    if command -v lsof >/dev/null 2>&1; then
        lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1
        port_in_use=$?
    elif command -v ss >/dev/null 2>&1; then
        ss -ltn "sport = :${port}" 2>/dev/null | tail -n +2 | grep -q .
        port_in_use=$?
    else
        check_result "Port $port ($service)" "⚠️" "Vérification impossible : installez lsof ou ss"
        return 1
    fi

    if [ "$port_in_use" -eq 0 ]; then
        check_result "Port $port ($service)" "⚠️" "Port déjà utilisé"
        return 1
    else
        check_result "Port $port ($service)" "✅" "Port libre"
        return 0
    fi
}

# Vérifie la présence d'un fichier indispensable à la suite des validations.
# Le diagnostic continue après une absence, mais le bilan final est en échec.
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        check_result "$description" "✅" "$file trouvé"
        return 0
    else
        check_result "$description" "❌" "$file non trouvé"
        return 1
    fi
}

# Vérifie la structure minimale des trois dépôts placés côte à côte.
check_dir() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        check_result "$description" "✅" "$dir trouvé"
        return 0
    else
        check_result "$description" "❌" "$dir non trouvé"
        return 1
    fi
}

# Vérifie qu'un fichier de propriétés contient toutes les clés obligatoires.
# Les valeurs ne sont pas affichées afin de ne pas recopier de secret éventuel
# dans les logs ou rapports.
check_file_keys() {
    local file=$1
    local description=$2
    shift 2

    if [ ! -f "$file" ]; then
        check_result "$description" "❌" "$file non trouvé"
        return 1
    fi

    # Un tableau permet de signaler toutes les clés absentes en une seule fois.
    local missing_keys=()
    local key
    for key in "$@"; do
        if ! grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
            missing_keys+=("$key")
        fi
    done

    if [ ${#missing_keys[@]} -eq 0 ]; then
        check_result "$description" "✅" "Toutes les clés requises sont présentes"
        return 0
    fi

    check_result "$description" "❌" "Clés manquantes : ${missing_keys[*]}"
    return 1
}

# En-tête visuel du diagnostic.
echo ""
echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  VÉRIFICATION DE L'ENVIRONNEMENT DE DÉVELOPPEMENT         ║${NC}"
echo -e "${MAGENTA}║  Projet: MSM Projet 06 - Backend + Frontend               ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════╝${NC}"

# Section 1: Outils Systèmes
report_step "Verification des outils systeme"
echo ""
echo -e "${YELLOW}[1] OUTILS SYSTÈMES${NC}"

check_tool "Docker" "docker" "${MIN_DOCKER_VERSION}"
check_docker_compose

# La présence du client Docker ne garantit pas que Docker Desktop ou le daemon
# est démarré. `docker info` valide la communication avec le moteur.
if timeout 15s docker info &>/dev/null; then
    check_result "Docker Engine" "✅" "Moteur Docker accessible"
else
    check_result "Docker Engine" "❌" "Docker Desktop ou le moteur Docker n'est pas démarré"
fi

# Section 2: Java / Gradle
report_step "Verification de Java et Gradle"
echo ""
echo -e "${YELLOW}[2] JAVA / GRADLE${NC}"

check_tool "Java (JDK)" "java" "${MIN_JAVA_VERSION}"

# Gradle et Spring Boot utilisent JAVA_HOME lorsqu'il est disponible. Si la
# variable n'est pas exportée par le shell, elle est déduite du binaire `java`
# puis exportée uniquement pour la durée de ce script.
if [ -n "${JAVA_HOME:-}" ] && [ -d "$JAVA_HOME" ]; then
    check_result "JAVA_HOME" "✅" "$JAVA_HOME"
else
    JAVA_PATH=$(readlink -f "$(command -v java)" 2>/dev/null)
    DETECTED_JAVA_HOME=$(dirname "$(dirname "$JAVA_PATH")")
    if [ -d "$DETECTED_JAVA_HOME" ]; then
        export JAVA_HOME="$DETECTED_JAVA_HOME"
        check_result "JAVA_HOME" "✅" "Détecté et exporté pour le script : $JAVA_HOME"
    else
        check_result "JAVA_HOME" "❌" "Variable absente et JDK impossible à localiser"
    fi
fi

# La présence du wrapper ne suffit pas : son exécution confirme la version
# réellement épinglée par le projet et l'accès au JDK.
if [ -f "${BACKEND_WRAPPER}" ]; then
    GRADLE_VERSION=$(timeout 20s "${BACKEND_WRAPPER}" --version 2>/dev/null |
        grep -oE '^Gradle [0-9]+(\.[0-9]+)+' | head -1 | awk '{print $2}')
    if [ -n "$GRADLE_VERSION" ]; then
        check_result "Gradle Wrapper" "✅" "Version: $GRADLE_VERSION"
    else
        check_result "Gradle Wrapper" "❌" "Présent mais non exécutable"
    fi
else
    check_result "Gradle Wrapper" "❌" "${BACKEND_WRAPPER} non trouvé"
fi

# Section 3: Node.js / npm / Angular
report_step "Verification de Node.js, npm et Angular"
echo ""
echo -e "${YELLOW}[3] NODE.JS / NPM / ANGULAR${NC}"

check_tool "Node.js" "node" "${MIN_NODE_VERSION}"
check_tool "npm" "npm" "${MIN_NPM_VERSION}"

# Angular CLI est volontairement contrôlé dans node_modules. Une installation
# globale pourrait masquer une incompatibilité avec la version du projet.
if [ -f "$ANGULAR_PACKAGE" ]; then
    ANGULAR_VERSION=$(node -p "require('$ANGULAR_PACKAGE').version" 2>/dev/null)
    check_result "Angular CLI (local)" "✅" "Version: $ANGULAR_VERSION"
else
    check_result "Angular CLI (local)" "⚠️" "Non installé : exécuter npm ci dans ${FRONTEND_PROJECT_NAME}"
fi

# Section 4: Ports Réseau
report_step "Verification des ports reseau"
echo ""
echo -e "${YELLOW}[4] PORTS RÉSEAU${NC}"

check_port "${DATABASE_PORT}" "PostgreSQL"
check_port "${BACKEND_PORT}" "Backend (Spring Boot)"
check_port "${FRONTEND_PORT}" "Frontend (serveur de développement)"
check_port "${FRONTEND_DOCKER_PORT}" "Frontend (conteneur web)"

# Section 5: Projets Locaux
report_step "Verification des projets locaux"
echo ""
echo -e "${YELLOW}[5] PROJETS LOCAUX${NC}"

check_dir "${BACKEND_DIR}" "Backend Project"
check_dir "${FRONTEND_DIR}" "Frontend Project"
check_dir "${OPS_DIR}" "Ops Project"

check_file "${BACKEND_BUILD_FILE}" "Backend Build File"
check_dir "${BACKEND_SOURCES_DIR}" "Backend Sources"
check_file "${FRONTEND_PACKAGE_FILE}" "Frontend Package File"
check_dir "${FRONTEND_SOURCES_DIR}" "Frontend Sources"
check_file "${OPS_TEST_SCRIPT}" "Ops Test Script"
check_file "${OPS_CONFIG_FILE}" "Ops Validation Config"

# Vérifie les fichiers de construction et d'orchestration sans construire les
# images. La construction complète appartient à validate-docker.sh.
# Section 6: Fichiers Dockerfile
report_step "Verification des fichiers Docker"
echo ""
echo -e "${YELLOW}[6] FICHIERS DOCKER${NC}"

check_file "${BACKEND_DOCKERFILE}" "Backend Dockerfile"
check_file "${FRONTEND_DOCKERFILE}" "Frontend Dockerfile"
check_file "${BACKEND_COMPOSE_FILE}" "Backend Docker Compose"
check_file "${FRONTEND_COMPOSE_FILE}" "Frontend Docker Compose"

# Vérifie la présence de la configuration, sans tenter de se connecter à une
# base. Le démarrage PostgreSQL est pris en charge par validate-backend.sh.
# Section 7: Bases de Données
report_step "Verification des configurations"
echo ""
echo -e "${YELLOW}[7] BASES DE DONNÉES${NC}"

check_file "${BACKEND_DB_INIT_FILE}" "DB Init Script"
check_file "${BACKEND_CONFIG_FILE}" "Backend Config"
check_file_keys \
    "${BACKEND_CONFIG_FILE}" \
    "Backend Datasource Config" \
    "spring\.datasource\.url" \
    "spring\.datasource\.username" \
    "spring\.datasource\.password"
check_file "${FRONTEND_ENV_FILE}" "Frontend Environment"
check_file "${FRONTEND_PROD_ENV_FILE}" "Frontend Production Environment"

# Le résumé alimente à la fois le terminal et les lignes métier du rapport.
report_step "Generation du resume"
echo ""
echo -e "${YELLOW}[RÉSUMÉ]${NC}"
echo -e "  ${GREEN}✅ Vérifications réussies : $PASSED${NC}"
echo -e "  ${YELLOW}⚠️  Avertissements           : $WARNINGS${NC}"
echo -e "  ${RED}❌ Erreurs                  : $FAILED${NC}"

report_detail "Verifications reussies" "\`${PASSED}\`"
report_detail "Avertissements" "\`${WARNINGS}\`"
report_detail "Erreurs" "\`${FAILED}\`"

# Seules les erreurs bloquantes déterminent le code de sortie. Un avertissement,
# par exemple un port déjà occupé, laisse l'environnement validé tout en
# indiquant clairement qu'une intervention peut être nécessaire.
if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ ENVIRONNEMENT VALIDÉ - Prêt pour l'étape suivante!${NC}"
    exit 0
elif [ $FAILED -le 2 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Certains outils sont manquants, mais le projet peut fonctionner${NC}"
    echo -e "    Consultez README.md et le rapport généré pour les détails${NC}"
    exit 1
else
    echo ""
    echo -e "${RED}❌ ENVIRONNEMENT INCOMPLET - Installez les outils manquants${NC}"
    echo -e "    Consultez README.md et le rapport généré pour les instructions${NC}"
    exit 1
fi
