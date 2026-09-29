/*
 * Filename: GE_global_setup.do
 * Description: This do file loads conversion factors and other
 *     variables that are used across the project. In cases where this requires calculations, clearly notes where these are coming from.
 * Author: Michael Walker
 * Note: file created in May 2019, still need to ensure that some of these calculations and numbers are consolidated into this do file.
 */

version 15.1

global USDKES = 97

glo ppprate = 1/46.49 // World Bank PPP conversion factor for private consumption, accessed Sep 28 2018
global ugx_kes = 0.0309 /*UGX to KES exchange rate, 18 Aug 2014 to 31 Aug 2015 from oanda.com */

glo trans_amt = 87000*$ppprate

glo adult_age = 18 // setting age at which we consider people adults -- this matters for household roster, and some education-related outcomes

** Stata options
set more off
set matsize 1000
//set maxvar 32000

** directory structure
project, doinfo

global dir=r(pdir)
if "${REPO_ROOT}" != "" global dir "${REPO_ROOT}"

local output_root "$dir"
if "${RUN_ROOT}" != "" local output_root "${RUN_ROOT}"

glo ado="$dir/ado"
glo do="$dir/do"
glo dl="`output_root'/logs"
glo dr="$dir/rawdata"
glo da="$dir/data"
glo dt="`output_root'/temp"
glo dtab="`output_root'/results/tables"
glo dfig="`output_root'/results/figures"

capture confirm file "$dir/config.do"
if _rc {
    di as error "Missing replication configuration: $dir/config.do"
    exit 601
}
quietly do "$dir/config.do"
