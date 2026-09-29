/*
 * Filename: SW_code.do
 * Code for testing new SW F-stat code
 * Author: Michael Walker
 * Date: Aug 11, 2021
 */

 * Preliminaries
 return clear
 project, doinfo
 if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
 else {  // running directly
 	if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
 	do "${ge_dir}/do/set_environment.do"
 }

 ** defining globals **
 project, original("$dir/do/GE_global_setup.do")
 include "$dir/do/GE_global_setup.do"
 project, original("$dir/do/global_runGPS.do")
 include "$dir/do/global_runGPS.do"

** setting up log file **
cap log close
log using "$dl/SW_1stStage_Test_`c(current_date)'.log", replace text


project, original("$do/programs/calculate_sw_firststage_v3.do")
include "$do/programs/calculate_sw_firststage_v3.do"
adopath + "$dir/ado"

/** Setting up postfile for saving results:
  1. variable name
  2. endogenous variable name (will be conditional on others)
  3. specification (eligible, non-recipient, ent_t, ent_c)
  4. S-W F-statistic (in most cases, conditional; in some cases not)
  5. S-W F-stat p-value
  6. Main IV point estimates as a consistency check -- want to make sure these match
      include up to 2 for each specification
  **/

// not saving p-value for right now
  cap postclose sw_results
  local postname "$dtab/SW_1stStage_MainTables.dta"
  postfile sw_results str32(outcome endog) str128(endog_list exog_list) str20(spec) double(swf_spatial swf_spatial_indiv swf_clust ivest) str6(table) using "`postname'", replace

**Main Exhibits**

** Figure 1: Transfer multiplier -- we will get this off of multiplier table**

**Table 1: expenditure, saving, income**
* defining variable list
local outcomelist "p2_consumption_wins_PPP nondurables_exp_wins_PPP h2_1_foodcons_12mth_wins_PPP h2_3_temptgoods_12_wins_PPP durables_exp_wins_PPP p1_assets_wins_PPP h1_10_housevalue_wins_PPP h1_11_landvalue_wins_PPP p3_totincome_wins_PPP p11_6_nettransfers_wins2_PPP tottaxpaid_all_wins_PPP totprofit_wins_PPP p3_3_wageearnings_wins_PPP"


* looping through to calculate -- all are saved into postfile
foreach v in `outcomelist' {
    di "Loop for `v'"
    calculate_sw_firststage `v' using sw_results, hh maxrad(2) table("1")
}


**Table 2: input prices and quantities**
local outcomelist emp_cshsal_perh_winP hh_hrs_total landprice_wins_PPP own_land_acres lw_intrate_wins tot_loanamt_wins_PPP

foreach v of local outcomelist {
  di "Loop for `v'"
  calculate_sw_firststage `v' using sw_results, hh maxrad(2) table("2")
}


**Table 3: Enterprise Outcomes**
* need to update code for this part -- think through interactions vs other cases
local outcomelist "ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP  n_allents"

foreach v of local outcomelist {
  di "Loop for `v'"
  calculate_sw_firststage `v' using sw_results, ent maxrad(2) table("3")
}


**Table 4: Output prices **
* This table uses FEs, not IV spec -- appendix table will make use of IV

** Table 5: Transfer multiplier estimates **
* This is run separately by the sw_firststage_mult.do file



/*** CLOSING POSTFILE ***/
postclose sw_results

/***** GENERATING STATISTICS FOR PAPER AND REFEREE RESPONSE *****/
use "$dtab/SW_1stStage_MainTables.dta", clear

di "Cross-sectional summary"
summ swf_spatial, d

di "Minimum: " r(min)
di "5th percentile: " r(p5)

summ swf_clust, d

di "Minimum: " r(min)
di "5th percentile: " r(p5)

bys spec: summ swf_spatial
