
** This sets bootstrap replications for the multiplier estimates **
if "${MULTIPLIER_REPS}" == "" {
    di as error "MULTIPLIER_REPS is not configured. Run config.do first."
    exit 198
}
global bootstrap_reps = ${MULTIPLIER_REPS}
