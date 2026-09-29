version 15.1
clear all
set more off
set varabbrev off

if "${REPO_ROOT}" == "" global REPO_ROOT "`c(pwd)'"
do "$REPO_ROOT/config.do"
global ENT_ROOT   "$REPO_ROOT/outputs/section4_3_enterprise_eq8_eq9"
global RUN_ROOT "$ENT_ROOT"

adopath ++ "$REPO_ROOT/ado"

cap mkdir "$REPO_ROOT/outputs"
cap mkdir "$ENT_ROOT"
cap mkdir "$ENT_ROOT/results"
cap mkdir "$ENT_ROOT/results/tables"
cap mkdir "$ENT_ROOT/results/tables/coeftables"
cap mkdir "$ENT_ROOT/logs"
cap mkdir "$ENT_ROOT/temp"
cap mkdir "$ENT_ROOT/temp/spatial_ri_draws"

capture program drop project
program define project, rclass
    syntax [, DOINFO DO(string asis) CREATES(string asis) USES(string asis) ORIGINAL(string asis) RELIES_ON(string asis) PRESERVE ]

    if "`doinfo'" != "" {
        return local pdir "$REPO_ROOT"
        return local pname "cash_transfer_replication_section4_3_enterprise_eq8_eq9"
        exit
    }

    if `"`do'"' != "" {
        do `"`do'"'
    }
end

capture log close
capture log close master
log using "$ENT_ROOT/logs/run_tablei12_ri_enterprise_only.log", replace text name(master)

local required_inputs ///
    "data/pp_GDP_calculated.dta" ///
    "data/GE_HHLevel_ECMA.dta" ///
    "data/GE_VillageLevel_ECMA.dta" ///
    "data/GE_Enterprise_ECMA.dta" ///
    "data/village_buffers_hhs_ge.dta" ///
    "data/village_buffers_hhs_gd.dta" ///
    "data/village_buffers_hhs_census.dta" ///
    "rawdata/CleanGeography_PUBLIC.dta" ///
    "rawdata/GE_Treat_Status_Master.dta"

foreach f of local required_inputs {
    if !fileexists("$REPO_ROOT/`f'") {
        di as error "Missing canonical prepared input: `f'"
        di as error "Obtain the authorized prepared replication file; public code does not reconstruct it."
        capture log close master
        exit 601
    }
}

di "============================================================"
di "Running do/analysis/main/TableI12_RI_Enterprise.do"
di "============================================================"

capture noisily do "$REPO_ROOT/do/analysis/main/TableI12_RI_Enterprise.do"
local rc = _rc

if `rc' == 0 {
    di "Completed do/analysis/main/TableI12_RI_Enterprise.do"
}
else {
    di as error "FAILED do/analysis/main/TableI12_RI_Enterprise.do with return code `rc'"
}

log close master

if `rc' != 0 {
    exit `rc'
}
