/*
 * Reproducibility configuration.
 *
 * REPLICATION_MODE may be supplied as a Stata global or as an environment
 * variable. "paper" is the default and uses the published replication counts.
 * "smoke" is an explicit, non-inferential test mode; "fast" and "quick" are
 * accepted only as aliases and are normalized to "smoke".
 * REPLICATION_SEED may be overridden in the same way.
 */

version 15.1

if "${REPLICATION_MODE}" == "" {
    local env_mode : environment REPLICATION_MODE
    if "`env_mode'" != "" global REPLICATION_MODE "`env_mode'"
    else global REPLICATION_MODE "paper"
}

local normalized_mode = lower(strtrim("${REPLICATION_MODE}"))
global REPLICATION_MODE "`normalized_mode'"
if inlist("${REPLICATION_MODE}", "fast", "quick") global REPLICATION_MODE "smoke"

if !inlist("${REPLICATION_MODE}", "smoke", "paper") {
    di as error "REPLICATION_MODE must be paper or smoke (fast/quick are aliases for smoke)."
    exit 198
}

if "${REPLICATION_SEED}" == "" {
    local env_seed : environment REPLICATION_SEED
    if "`env_seed'" != "" global REPLICATION_SEED "`env_seed'"
    else global REPLICATION_SEED "20220930"
}

capture confirm number ${REPLICATION_SEED}
if _rc {
    di as error "REPLICATION_SEED must be an integer accepted by Stata."
    exit 198
}

if "${REPLICATION_MODE}" == "paper" {
    global MULTIPLIER_REPS 2000
    global RI_REPS 500
    global BIC_REPS 200
}
else {
    global MULTIPLIER_REPS 3
    global RI_REPS 3
    global BIC_REPS 3
}

set seed ${REPLICATION_SEED}
capture set sortseed ${REPLICATION_SEED}

di as text "Replication mode: ${REPLICATION_MODE}"
if "${REPLICATION_MODE}" == "smoke" {
    di as error "SMOKE MODE: outputs are not paper-grade inferential results."
}
di as text "Deterministic seed: ${REPLICATION_SEED}"
di as text "Replications (multiplier / RI / BIC): ${MULTIPLIER_REPS} / ${RI_REPS} / ${BIC_REPS}"
