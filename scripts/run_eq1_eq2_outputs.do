version 15.1
clear all
set more off
set varabbrev off

if "${REPO_ROOT}" == "" global REPO_ROOT "`c(pwd)'"
do "$REPO_ROOT/config.do"
global EQ12_ROOT "$REPO_ROOT/outputs/section3_2_eq1_eq2"
global RUN_ROOT "$EQ12_ROOT"

adopath ++ "$REPO_ROOT/ado"

cap mkdir "$REPO_ROOT/outputs"
cap mkdir "$EQ12_ROOT"
cap mkdir "$EQ12_ROOT/results"
cap mkdir "$EQ12_ROOT/results/tables"
cap mkdir "$EQ12_ROOT/results/tables/coeftables"
cap mkdir "$EQ12_ROOT/results/figures"
cap mkdir "$EQ12_ROOT/logs"
cap mkdir "$EQ12_ROOT/temp"

capture program drop project
program define project, rclass
    syntax [, DOINFO DO(string asis) CREATES(string asis) USES(string asis) ORIGINAL(string asis) RELIES_ON(string asis) PRESERVE ]

    if "`doinfo'" != "" {
        return local pdir "$REPO_ROOT"
        return local pname "cash_transfer_replication"
        exit
    }

    if `"`do'"' != "" {
        do `"`do'"'
    }
end

capture log close
capture log close master
log using "$EQ12_ROOT/logs/run_eq1_eq2_outputs.log", replace text name(master)

local required_inputs ///
    "data/GE_HHLevel_ECMA.dta" ///
    "data/GE_HHIndividualWageProfits_ECMA.dta" ///
    "data/GE_Enterprise_ECMA.dta" ///
    "data/GE_VillageLevel_ECMA.dta"

foreach f of local required_inputs {
    if !fileexists("$REPO_ROOT/`f'") {
        di as error "Missing canonical prepared input: `f'"
        di as error "Obtain the authorized prepared replication file; public code does not reconstruct it."
        capture log close master
        exit 601
    }
}

local runfiles ///
    "do/analysis/main/Table1_B8_F3_ExpSavingsIncome.do" ///
    "do/analysis/main/Table2_InputPricesQuantities.do" ///
    "do/analysis/main/TableB1_HHAssets.do" ///
    "do/analysis/main/TableB5_AddLandOutcomes.do" ///
    "do/analysis/main/TableB6_ExternalityOutcomes.do" ///
    "do/analysis/main/TableB9_ExpSavingsIncome_NoMigrants.do" ///
    "do/analysis/main/FigureB1_LinearityChecks.do"

local first_rc = 0
foreach f of local runfiles {
    di "============================================================"
    di "Running `f'"
    di "============================================================"
    capture noisily do "$REPO_ROOT/`f'"
    local rc = _rc
    if `rc' != 0 {
        di as error "FAILED `f' with return code `rc'"
        local first_rc = `rc'
        continue, break
    }
}

capture log close master
if `first_rc' != 0 exit `first_rc'
