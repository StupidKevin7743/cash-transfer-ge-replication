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
log using "$DYN_ROOT/logs/run_eq7_compile_tables_only.log", replace text name(master)

local required_inputs ///
    "data/GE_Enterprise_ECMA.dta" ///
    "data/GE_HHLevel_ECMA.dta" ///
    "rawdata/IntermediateImportAssumptions_intimports.dta" ///
    "rawdata/IntermediateImportAssumptions_nondurables_entmatch.dta" ///
    "rawdata/IntermediateImportAssumptions_durables_entmatch.dta"

local required_generated ///
    "outputs/section3_8_dynamics_eq7/temp/IRF_values/bootstrap_rawoutput_r.dta" ///
    "outputs/section3_8_dynamics_eq7/temp/IRF_values/bootstrap_rawoutput_r_withRarieda.dta" ///
    "outputs/section3_8_dynamics_eq7/temp/IRF_values/bootstrap_rawoutput.dta" ///
    "outputs/section3_8_dynamics_eq7/temp/IRF_values/bootstrap_rawoutput_r_q4to10.dta"

foreach f of local required_inputs {
    if !fileexists("$REPO_ROOT/`f'") {
        di as error "Missing canonical prepared input: `f'"
        capture log close master
        exit 601
    }
}

foreach f of local required_generated {
    if !fileexists("$REPO_ROOT/`f'") {
        di as error "Missing generated multiplier prerequisite: `f'"
        di as error "Run scripts/run_eq7_multiplier_outputs.do before compiling tables."
        capture log close master
        exit 601
    }
}

foreach d in joint treated untreated {
    local irf_files ""
    capture local irf_files : dir "$DYN_ROOT/temp/IRF_values/`d'" files "*.txt"
    if _rc | `"`irf_files'"' == "" {
        di as error "Missing generated IRF text files in: $DYN_ROOT/temp/IRF_values/`d'"
        di as error "Run scripts/run_eq7_multiplier_outputs.do before compiling tables."
        capture log close master
        exit 601
    }
}

capture noisily do "$REPO_ROOT/do/analysis/multiplier/multiplier_compiledata.do"
local rc = _rc
if `rc' == 0 {
    capture noisily do "$REPO_ROOT/do/analysis/multiplier/multiplier_tables.do"
    local rc = _rc
}

capture log close master
if `rc' != 0 exit `rc'
