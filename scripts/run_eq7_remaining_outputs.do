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
log using "$DYN_ROOT/logs/run_eq7_remaining_outputs.log", replace text name(master)

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

if !fileexists("$DYN_ROOT/temp/IRF_values/bootstrap_rawoutput_r.dta") {
    di as error "Missing base deflated multiplier output under $DYN_ROOT/temp/IRF_values."
    di as error "Run the base stage or scripts/run_eq7_multiplier_outputs.do first."
    capture log close master
    exit 601
}

foreach d in joint treated untreated {
    local irf_files ""
    capture local irf_files : dir "$DYN_ROOT/temp/IRF_values/`d'" files "*.txt"
    if _rc | `"`irf_files'"' == "" {
        di as error "Missing base IRF text files in: $DYN_ROOT/temp/IRF_values/`d'"
        capture log close master
        exit 601
    }
}

local runfiles ///
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
