
** This sets bootstrap replications for the BIC split-sample estimates **
if "${BIC_REPS}" == "" {
    di as error "BIC_REPS is not configured. Run config.do first."
    exit 198
}
global bic_reps = ${BIC_REPS}
