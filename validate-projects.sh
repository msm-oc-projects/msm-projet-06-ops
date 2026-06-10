#!/usr/bin/env bash

# Point d'entrée court pour la validation préalable du projet.
#
# Ordre imposé :
# 1. vérifier l'environnement de développement ;
# 2. lancer les tests unitaires backend et frontend ;
# 3. arrêter immédiatement si l'une des deux étapes échoue.
#
# Les validations applicatives avec démarrage des serveurs sont volontairement
# séparées dans validate-backend.sh, validate-frontend.sh et validate-docker.sh.

# -e : arrête le script dès qu'une commande non gérée échoue.
# -u : refuse l'utilisation silencieuse d'une variable non définie.
set -eu

# Le chemin est calculé depuis le script lui-même. La commande peut donc être
# lancée depuis la racine du projet ou depuis n'importe quel autre dossier.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validation.env"

# Préfixe toutes les sorties pour identifier facilement leur provenance dans
# un terminal ou dans le journal consolidé.
log() {
    printf '[validate-projects] %s\n' "$*"
}

# Active le journal complet et le rapport Markdown pour cette orchestration.
source "${SCRIPT_DIR}/reporting.sh"
init_report "projects-validation" "Verification de l'environnement et tests des projets"

# La vérification est un prérequis bloquant : aucun test ne doit être lancé
# sur un environnement incomplet.
report_step "Verification de l'environnement"
log "Vérification préalable de l'environnement"
if ! bash "${SCRIPT_DIR}/verify-environment.sh"; then
    log "Échec de la vérification : les tests ne seront pas lancés"
    exit 1
fi

# run-tests.sh détecte les projets frères et choisit automatiquement npm ou
# Gradle. Son code de sortie est propagé par ce script.
report_step "Tests backend et frontend"
log "Environnement validé, lancement des tests backend et frontend"
if ! bash "${SCRIPT_DIR}/run-tests.sh"; then
    log "Un ou plusieurs projets ont échoué aux tests"
    exit 1
fi

# Cette étape n'est atteinte que si les deux scripts précédents ont réussi.
log "Validation complète réussie"
report_step "Validation terminee"
