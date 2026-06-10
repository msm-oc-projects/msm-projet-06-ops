#!/usr/bin/env bash

# Bibliothèque commune de génération de rapports.
#
# Ce fichier n'est pas destiné à être exécuté directement. Il est chargé avec
# `source` par les autres scripts du dépôt Ops. Le script appelant doit avoir
# défini SCRIPT_DIR avant d'appeler init_report.
#
# Deux fichiers sont produits pour chaque exécution :
# - un journal .log contenant toute la sortie texte détaillée ;
# - un rapport .md synthétique avec le statut, la durée et la dernière étape.
#
# Les couleurs ANSI restent visibles dans le terminal, mais elles sont retirées
# du journal afin que celui-ci soit lisible dans VS Code et les outils de CI.
#
# Un fichier `*-latest.md` est également mis à jour pour permettre à la
# documentation de toujours pointer vers le résultat le plus récent.

init_report() {
    local report_name=$1
    local report_title=$2

    # L'identifiant horodaté évite d'écraser l'historique des exécutions.
    REPORTS_DIR="${SCRIPT_DIR}/execution-reports"
    REPORT_RUN_ID=$(date '+%Y%m%d-%H%M%S')

    # Les deux formats de date servent à des usages différents :
    # - ISO 8601 pour un affichage non ambigu dans le rapport ;
    # - epoch pour calculer simplement la durée totale.
    REPORT_STARTED_AT=$(date -Iseconds)
    REPORT_STARTED_EPOCH=$(date +%s)

    # Ces variables restent globales afin que le script appelant puisse
    # enrichir le rapport au fil de son exécution.
    REPORT_NAME="${report_name}"
    REPORT_TITLE="${report_title}"
    REPORT_CURRENT_STEP="Initialisation"
    REPORT_EXTRA_ROWS=""
    REPORT_FILE="${REPORTS_DIR}/${REPORT_NAME}-${REPORT_RUN_ID}.md"
    REPORT_LATEST="${REPORTS_DIR}/${REPORT_NAME}-latest.md"
    REPORT_LOG="${REPORTS_DIR}/${REPORT_NAME}-${REPORT_RUN_ID}.log"

    mkdir -p "${REPORTS_DIR}"

    # À partir de cette ligne, stdout et stderr suivent deux destinations :
    # - la sortie standard de `tee`, qui conserve les couleurs du terminal ;
    # - strip_ansi, qui retire les séquences ESC avant d'écrire le journal.
    exec > >(tee >(strip_ansi >>"${REPORT_LOG}")) 2>&1

    # Le rapport est généré quelle que soit la manière dont le script se
    # termine : succès, erreur Bash ou interruption Ctrl+C.
    trap 'finish_report $?' EXIT
    trap 'exit 130' INT TERM
}

# Supprime les séquences de contrôle ANSI de type CSI, notamment les couleurs
# `ESC[...m`. Le filtre ne modifie pas le texte UTF-8 ni les retours à la ligne.
strip_ansi() {
    sed -E $'s/\x1B\\[[0-?]*[ -\\/]*[@-~]//g'
}

# Mémorise l'étape en cours. En cas d'échec, cette valeur indique précisément
# jusqu'où le script est arrivé.
report_step() {
    REPORT_CURRENT_STEP=$1
}

# Ajoute une ligne métier dans le tableau Markdown du rapport final.
# Exemple : report_detail "Tests réussis" "42"
report_detail() {
    REPORT_EXTRA_ROWS+="| $1 | $2 |"$'\n'
}

finish_report() {
    local exit_code=$1
    local finished_at
    local finished_epoch
    local duration
    local status

    # Désactive immédiatement le trap EXIT pour empêcher une récursion lorsque
    # cette fonction retourne le code de sortie initial.
    trap - EXIT

    # Certains scripts définissent une fonction cleanup pour arrêter les
    # processus ou conteneurs temporaires. Elle est appelée automatiquement si
    # elle existe, sans masquer le résultat principal en cas d'erreur de ménage.
    if declare -F cleanup >/dev/null 2>&1; then
        cleanup || true
    fi

    # Calcule la durée indépendamment du fuseau horaire ou du changement de
    # format de date affiché.
    finished_at=$(date -Iseconds)
    finished_epoch=$(date +%s)
    duration=$((finished_epoch - REPORT_STARTED_EPOCH))

    if [ "${exit_code}" -eq 0 ]; then
        status="SUCCES"
    else
        status="ECHEC"
    fi

    # Le rapport reste volontairement court : le détail complet se trouve dans
    # le journal référencé par son nom de fichier.
    {
        printf '# Rapport - %s\n\n' "${REPORT_TITLE}"
        printf '| Champ | Valeur |\n'
        printf '|---|---|\n'
        printf '| Statut | **%s** |\n' "${status}"
        printf '| Code de sortie | `%s` |\n' "${exit_code}"
        printf '| Debut | `%s` |\n' "${REPORT_STARTED_AT}"
        printf '| Fin | `%s` |\n' "${finished_at}"
        printf '| Duree | `%s secondes` |\n' "${duration}"
        printf '| Derniere etape | %s |\n' "${REPORT_CURRENT_STEP}"
        printf '| Journal | `%s` |\n' "$(basename "${REPORT_LOG}")"
        printf '%s' "${REPORT_EXTRA_ROWS}"
        printf '\n'
        printf 'Rapport genere automatiquement par `%s`.\n' "$(basename "$0")"
    } >"${REPORT_FILE}"

    # La copie "latest" fournit une URL stable dans les guides et checklists.
    cp "${REPORT_FILE}" "${REPORT_LATEST}"
    printf '[report] %s\n' "${REPORT_FILE}"

    # Conserve exactement le code de sortie du script appelant pour que la CI
    # ou le terminal puisse distinguer un succès d'un échec.
    return "${exit_code}"
}
