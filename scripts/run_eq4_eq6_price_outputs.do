version 15.1
clear all
set more off
set varabbrev off

if "${REPO_ROOT}" == "" global REPO_ROOT "`c(pwd)'"
do "$REPO_ROOT/config.do"
global PRICE_ROOT "$REPO_ROOT/outputs/section3_7_prices_eq4_eq6"
global RUN_ROOT "$PRICE_ROOT"

adopath ++ "$REPO_ROOT/ado"

cap mkdir "$REPO_ROOT/outputs"
cap mkdir "$PRICE_ROOT"
cap mkdir "$PRICE_ROOT/results"
cap mkdir "$PRICE_ROOT/results/tables"
cap mkdir "$PRICE_ROOT/results/tables/coeftables"
cap mkdir "$PRICE_ROOT/results/figures"
cap mkdir "$PRICE_ROOT/logs"
cap mkdir "$PRICE_ROOT/temp"
cap mkdir "$PRICE_ROOT/temp/PriceAnalysis_ProductLevel"

capture program drop project
program define project, rclass
    syntax [, DOINFO DO(string asis) CREATES(string asis) USES(string asis) ORIGINAL(string asis) RELIES_ON(string asis) PRESERVE ]

    if "`doinfo'" != "" {
        return local pdir "$REPO_ROOT"
        return local pname "cash_transfer_replication_section3_7_prices_eq4_eq6"
        exit
    }

    if `"`do'"' != "" {
        do `"`do'"'
    }
end

capture log close
capture log close master
log using "$PRICE_ROOT/logs/run_eq4_eq6_price_outputs.log", replace text name(master)

local required_inputs ///
    "data/GE_MarketData_Panel_ECMA.dta" ///
    "data/GE_MarketData_Panel_ProductLevel_ECMA.dta" ///
    "data/Ent_ML_SpatialData_long_FINAL.dta"

foreach f of local required_inputs {
    if !fileexists("$REPO_ROOT/`f'") {
        di as error "Missing canonical prepared input: `f'"
        di as error "Obtain the authorized prepared replication file; public code does not reconstruct it."
        capture log close master
        exit 601
    }
}

local runfiles ///
    "do/analysis/main/Table4_FigureB3_OutputPrices.do" ///
    "do/analysis/main/FigureH1_H2_AdditionalPriceAnalyses.do" ///
    "do/analysis/main/TableH2_OutputPrices_DistRoad.do" ///
    "do/analysis/main/TableH3_OutputPrices_RadiiRobustness.do" ///
    "do/analysis/main/TableH4_OutputPrices_IV.do" ///
    "do/analysis/main/TableH5_EntPrices.do"

local first_rc = 0
foreach f of local runfiles {
    di "============================================================"
    di "Running `f'"
    di "============================================================"

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
