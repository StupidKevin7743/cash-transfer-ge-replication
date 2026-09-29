version 15.1
clear all
set more off
set varabbrev off

if "${REPO_ROOT}" == "" global REPO_ROOT "`c(pwd)'"
do "$REPO_ROOT/config.do"
global MPC_ROOT   "$REPO_ROOT/outputs/section4_2_mpc"
global RUN_ROOT "$MPC_ROOT"

adopath ++ "$REPO_ROOT/ado"

cap mkdir "$REPO_ROOT/outputs"
cap mkdir "$MPC_ROOT"
cap mkdir "$MPC_ROOT/results"
cap mkdir "$MPC_ROOT/results/tables"
cap mkdir "$MPC_ROOT/results/tables/coeftables"
cap mkdir "$MPC_ROOT/results/figures"
cap mkdir "$MPC_ROOT/logs"
cap mkdir "$MPC_ROOT/temp"
cap mkdir "$MPC_ROOT/temp/IRF_values"

capture program drop project
program define project, rclass
    syntax [, DOINFO DO(string asis) CREATES(string asis) USES(string asis) ORIGINAL(string asis) RELIES_ON(string asis) PRESERVE ]

    if "`doinfo'" != "" {
        return local pdir "$REPO_ROOT"
        return local pname "cash_transfer_replication_section4_2_mpc"
        exit
    }

    if `"`do'"' != "" {
        do `"`do'"'
    }
end

capture log close
capture log close master
log using "$MPC_ROOT/logs/run_tablec1_mpc_output.log", replace text name(master)

local required_inputs ///
    "data/HH_ENT_Multiplier_Dataset_ECMA.dta" ///
    "data/GE_Enterprise_ECMA.dta" ///
    "data/GE_HHLevel_ECMA.dta" ///
    "rawdata/IntermediateImportAssumptions_intimports.dta" ///
    "rawdata/IntermediateImportAssumptions_nondurables_entmatch.dta" ///
    "rawdata/IntermediateImportAssumptions_durables_entmatch.dta" ///
    "rawdata/Rarieda_Data_Temporal.dta"

foreach f of local required_inputs {
    if !fileexists("$REPO_ROOT/`f'") {
        di as error "Missing canonical prepared input: `f'"
        di as error "Obtain the authorized prepared replication file; public code does not reconstruct it."
        capture log close master
        exit 601
    }
}

di "============================================================"
di "Running do/analysis/main/TableC1_MPC.do"
di "============================================================"

capture noisily do "$REPO_ROOT/do/analysis/main/TableC1_MPC.do"
local rc = _rc

if `rc' == 0 {
    di "Completed do/analysis/main/TableC1_MPC.do"
}
else {
    di as error "FAILED do/analysis/main/TableC1_MPC.do with return code `rc'"
}

log close master

if `rc' != 0 {
    exit `rc'
}
