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
cap mkdir "$ENT_ROOT/results/figures"
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
log using "$ENT_ROOT/logs/run_eq8_eq9_enterprise_outputs.log", replace text name(master)

local required_inputs ///
    "data/GE_Enterprise_ECMA.dta" ///
    "data/GE_Enterprise_BL_ECMA.dta" ///
    "data/GE_HHLevel_ECMA.dta" ///
    "data/GE_HHIndividualWageProfits_ECMA.dta" ///
    "data/GE_VillageLevel_ECMA.dta" ///
    "rawdata/GE_Treat_Status_Master.dta"

foreach f of local required_inputs {
    if !fileexists("$REPO_ROOT/`f'") {
        di as error "Missing canonical prepared input: `f'"
        di as error "Obtain the authorized prepared replication file; public code does not reconstruct it."
        capture log close master
        exit 601
    }
}

local runfiles ///
    "do/analysis/main/Table3_EntOutcomes.do" ///
    "do/analysis/main/TableB2_EntSector_Revenue.do" ///
    "do/analysis/main/TableB3_EntOutcomes_Eligibility.do" ///
    "do/analysis/main/TableG2_EntOutcomes_NoBL.do" ///
    "do/analysis/main/TableG3_EntBalance.do" ///
    "do/analysis/main/TableI3_EntOutcomes_RadiiRobustness.do" ///
    "do/analysis/main/TableI6_BIC_splitsample_Enterprise.do" ///
    "do/analysis/main/TableI9_MaxRadius_EntOutcomes.do"

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

if `first_rc' == 0 {
    local ri_inputs ///
        "data/pp_GDP_calculated.dta" ///
        "data/village_buffers_hhs_ge.dta" ///
        "data/village_buffers_hhs_gd.dta" ///
        "data/village_buffers_hhs_census.dta" ///
        "rawdata/CleanGeography_PUBLIC.dta"

    foreach f of local ri_inputs {
        if !fileexists("$REPO_ROOT/`f'") {
            di as error "Missing additional prepared input for Table I.12: `f'"
            di as error "Earlier enterprise outputs completed; Table I.12 was not run."
            local first_rc = 601
            continue, break
        }
    }
}

if `first_rc' == 0 {
    local f "do/analysis/main/TableI12_RI_Enterprise.do"
    di "============================================================"
    di "Running `f'"
    di "============================================================"

    clear
    capture mata clear
    set more off
    set varabbrev off

    capture noisily do "$REPO_ROOT/`f'"
    local rc = _rc
    if `rc' != 0 {
        di as error "FAILED `f' with return code `rc'"
        local first_rc = `rc'
    }
    else di "Completed `f'"
}

capture log close master
if `first_rc' != 0 exit `first_rc'
