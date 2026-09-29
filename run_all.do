version 15.1
clear all
set more off
set varabbrev off

* Run this file from the repository root:
*     cd "path/to/cash-transfer-ge-replication"
*     do run_all.do

if "${REPO_ROOT}" == "" global REPO_ROOT "`c(pwd)'"

capture confirm file "$REPO_ROOT/config.do"
if _rc {
    di as error "Run run_all.do from the repository root, or set REPO_ROOT explicitly."
    exit 601
}

do "$REPO_ROOT/config.do"
do "$REPO_ROOT/scripts/preflight.do"

do "$REPO_ROOT/scripts/run_eq1_eq2_outputs.do"
do "$REPO_ROOT/scripts/run_eq3_outputs.do"
do "$REPO_ROOT/scripts/run_eq4_eq6_price_outputs.do"
do "$REPO_ROOT/scripts/run_eq7_multiplier_outputs.do"
do "$REPO_ROOT/scripts/run_tablec1_mpc_output.do"
do "$REPO_ROOT/scripts/run_eq8_eq9_enterprise_outputs.do"
