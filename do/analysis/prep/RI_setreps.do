*** setting spatial RI number of replications ***
if "${RI_REPS}" == "" {
    di as error "RI_REPS is not configured. Run config.do first."
    exit 198
}
global RI_reps = ${RI_REPS}
global RI_draw = 1
