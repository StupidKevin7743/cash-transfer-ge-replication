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
log using "$DYN_ROOT/logs/run_eq7_q4to10_only.log", replace text name(master)

if !fileexists("$REPO_ROOT/data/HH_ENT_Multiplier_Dataset_ECMA.dta") {
    di as error "Missing canonical analysis input: data/HH_ENT_Multiplier_Dataset_ECMA.dta"
    di as error "Obtain the authorized prepared replication file; public code does not reconstruct it."
    capture log close master
    exit 601
}

capture noisily do "$REPO_ROOT/do/analysis/multiplier/multiplier_wildboot_deflated_q4-q10.do"
local rc = _rc

capture log close master
if `rc' != 0 exit `rc'
