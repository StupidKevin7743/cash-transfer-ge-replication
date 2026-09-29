version 15.1
clear all
set more off
set varabbrev off

if "${REPO_ROOT}" == "" global REPO_ROOT "`c(pwd)'"
do "$REPO_ROOT/config.do"
global DYN_ROOT   "$REPO_ROOT/outputs/section3_8_dynamics_eq7"
global RUN_ROOT "$DYN_ROOT"

adopath ++ "$REPO_ROOT/ado"

cap mkdir "$REPO_ROOT/outputs"
cap mkdir "$DYN_ROOT"
cap mkdir "$DYN_ROOT/results"
cap mkdir "$DYN_ROOT/results/tables"
cap mkdir "$DYN_ROOT/results/tables/coeftables"
cap mkdir "$DYN_ROOT/results/figures"
cap mkdir "$DYN_ROOT/logs"
cap mkdir "$DYN_ROOT/temp"
cap mkdir "$DYN_ROOT/temp/IRF_values"
cap mkdir "$DYN_ROOT/temp/IRF_values/joint"
cap mkdir "$DYN_ROOT/temp/IRF_values/treated"
cap mkdir "$DYN_ROOT/temp/IRF_values/untreated"

capture program drop project
program define project, rclass
    syntax [, DOINFO DO(string asis) CREATES(string asis) USES(string asis) ORIGINAL(string asis) RELIES_ON(string asis) PRESERVE ]

    if "`doinfo'" != "" {
        return local pdir "$REPO_ROOT"
        return local pname "cash_transfer_replication_section3_8_dynamics_eq7"
        exit
    }

    if `"`do'"' != "" {
        do `"`do'"'
    }
end

capture log close
capture log close master
log using "$DYN_ROOT/logs/run_eq7_multiplier_outputs.log", replace text name(master)

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
di "Running section 3.8 multiplier sequence"
di "============================================================"

local runfiles ///
    "do/analysis/multiplier/ImportShares_globals_TablesD1_D2.do" ///
    "do/analysis/multiplier/multiplier_wildboot_deflated.do" ///
    "do/analysis/multiplier/multiplier_wildboot_deflated_inclRarieda.do" ///
    "do/analysis/multiplier/multiplier_wildboot_nominal.do" ///
    "do/analysis/multiplier/multiplier_wildboot_deflated_q4-q10.do" ///
    "do/analysis/multiplier/multiplier_compiledata.do" ///
    "do/analysis/multiplier/multiplier_tables.do"

local first_rc = 0
foreach f of local runfiles {
    di "============================================================"
    di "Running `f'"
    di "============================================================"

    clear
    capture mata clear
    set more off
    set varabbrev off

    capture noisily do "$REPO_ROOT/`f'"
    local rc = _rc

    if `rc' == 0 {
        di "Completed `f'"
    }
    else {
        di as error "FAILED `f' with return code `rc'"
        local first_rc = `rc'
        continue, break
    }
}

capture log close master
if `first_rc' != 0 exit `first_rc'
