#!/bin/sh
# Recherche de secrets (tokens, mots de passe, clés...) dans le projet avec gitleaks.
#
# Variables :
#   GITLEAKS_SCAN_MODE    auto (défaut) | diff | history | dir
#                         auto    : "diff" sur un push, "history" sinon (schedule, web)
#                         diff    : seulement les commits du push (CI_COMMIT_BEFORE_SHA..CI_COMMIT_SHA)
#                         history : tout l'historique git
#                         dir     : seulement les fichiers actuels, sans l'historique
#   GITLEAKS_REPORT_PATH  rapport JUnit (défaut : gitleaks-report.xml)
#   GITLEAKS_EXTRA_ARGS   arguments gitleaks supplémentaires (ex : "--max-target-megabytes 5")
#
# Personnalisation par projet (lus automatiquement par gitleaks à la racine du projet) :
#   .gitleaks.toml    règles et allowlist
#   .gitleaksignore   empreintes (fingerprints) de faux positifs à ignorer
set -eu

ZERO_SHA="0000000000000000000000000000000000000000"
MODE="${GITLEAKS_SCAN_MODE:-auto}"
REPORT_PATH="${GITLEAKS_REPORT_PATH:-gitleaks-report.xml}"
EXTRA_ARGS="${GITLEAKS_EXTRA_ARGS:-}"
BEFORE_SHA="${CI_COMMIT_BEFORE_SHA:-$ZERO_SHA}"

cd "${CI_PROJECT_DIR:-.}"
git config --global --add safe.directory "$(pwd)"

if [ "$MODE" = "auto" ]; then
    if [ "${CI_PIPELINE_SOURCE:-}" = "push" ] && [ "$BEFORE_SHA" != "$ZERO_SHA" ]; then
        MODE="diff"
    else
        MODE="history"
    fi
fi

# Commit précédent introuvable (force push, clone partiel...) : on scanne tout l'historique
if [ "$MODE" = "diff" ] && ! git cat-file -e "${BEFORE_SHA}^{commit}" 2>/dev/null; then
    echo "Commit ${BEFORE_SHA} introuvable, scan de tout l'historique à la place."
    MODE="history"
fi

COMMON_ARGS="--no-banner --redact --verbose --report-format junit --report-path ${REPORT_PATH}"

echo "Mode de scan gitleaks : ${MODE}"
case "$MODE" in
    diff)
        # shellcheck disable=SC2086
        gitleaks git $COMMON_ARGS $EXTRA_ARGS --log-opts="${BEFORE_SHA}..${CI_COMMIT_SHA}" .
        ;;
    history)
        # shellcheck disable=SC2086
        gitleaks git $COMMON_ARGS $EXTRA_ARGS .
        ;;
    dir)
        # shellcheck disable=SC2086
        gitleaks dir $COMMON_ARGS $EXTRA_ARGS .
        ;;
    *)
        echo "Erreur : GITLEAKS_SCAN_MODE inconnu : ${MODE} (valeurs possibles : auto, diff, history, dir)"
        exit 2
        ;;
esac
