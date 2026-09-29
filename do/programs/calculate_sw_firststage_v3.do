************************************************************
** Defining program to calculate optimal radii band **
************************************************************
* Author: Michael Walker
* Description: this program runs a series of IV regressions to
* determine the optimal radii for spatial spillover effects as
* outlined in GE pre-analysis plans.
* It returns scalars with the maximum and minimum of the radii band.
* Note: we may want to transition this to an ado file.
cap program drop calculate_sw_firststage
program calculate_sw_firststage, rclass
  syntax anything [if] [aweight pweight fweight] [using], [maxrad(int 2) hh ent vill table(str)]

  di "Start of program"
  di "Max rad: `maxrad'"
  * hh: runs version for eligible households and non-recipient households
  * Ent: runs version for enterprises
  * One of these must be specified in order to develop endogenous and exogenous list of variables

  di "HH: `hh'"
  di "Ent: `ent'"
  postutil dir

  if "`hh'" == "" & "`ent'" == "" & "`vill'" == "" {
    di "hh, ent or vill must be specified"
    stop
  }
  * add in check to make sure more than one not selected
*******************************************************
* Program Set up
local v = "`anything'"

*
* HOUSEHOLD PORTION
*

/* only running for clustered SEs -- this means we don't generate F-stats for some clusters,
but see validation code for this */
foreach se in "cluster(sublocation_code)" {



if "`hh'" != "" {

** Find source for variable v **
use "$da/GE_HHIndividualWageProfits_ECMA.dta", clear
capture: confirm variable `v'
if _rc == 0 {
  local source = "$da/GE_HHIndividualWageProfits_ECMA.dta"
}

use "$da/GE_HHLevel_ECMA.dta", clear
capture: confirm variable `v'
if _rc == 0 {
  local source = "$da/GE_HHLevel_ECMA.dta"
}

disp "`source'"

** Load dataset **
use "`source'", clear
cap gen cons = 1
cap drop w_*

if "`if'" != "" {
  keep `if'
}


** set panel and time variables **
if inlist("`source'", "$da/Vill_SpatialData_FINAL.dta") {
  local timvar = "avgdate_vill"
  local panvar = "village_code"

  if $runGPS == 1 {
    merge 1:1 `panvar' using $dr/GE_Village_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
  }
}

if inlist("`source'", "$da/GE_HHLevel_ECMA.dta")  {
  local timvar = "survey_mth"
  local panvar = "hhid"

  if $runGPS == 1 {
    merge 1:1 hhid_key using $dr/GE_HH_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
  }

}

if inlist("`source'", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
  local timvar = "survey_mth"
  local panvar = "persid"

  if $runGPS == 1 {
    merge n:1 hhid_key using $dr/GE_HH_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
  }
}

di "Source: `source'"


** define weight / generate weighted variables **
if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
  gen weight = hhweight_EL
  gen ineligible = 1-eligible
  ** set quantity-based weight for price variables **
  if "`v'" == "landprice_wins_PPP" {
    replace weight = weight * own_land_acres
  }
  if "`v'" == "lw_intrate_wins" {
    replace weight = weight * tot_loanamt_wins_PPP
  }
  if "`v'" == "emp_cshsal_perh_winP" {
    replace weight = weight * emp_hrs
  }
}

** define sample **
if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
  gen sample = eligible
}

** adding baseline variables - if they are in the dataset **
    cap desc `v'_BL M`v'_BL
    if _rc == 0 {
        local blvars "`v'_BL M`v'_BL"
        cap gen `v'_BLe = eligible * `v'_BL
        cap gen M`v'_BLe = eligible * M`v'_BL
        local blvars_untreat "`blvars' `v'_BLe M`v'_BLe"
    }
    else {
        local blvars ""
        local blvars_untreat ""
    }

    di "Calculate SW First Stage Stat"
    di "V: `v'"
    di "Time var: `timvar'"
    di "Panel var: `panvar'"


*******************************************************
  /**** Outline
  1. RUN THE IV REGRESSION
  2. PREDICT RESIDUALS
  3. RUN FIRST STAGE USING OLS RESIDUALS, CALCULATING SPATIALLY CORRELATED STANDARD ERRORS
  4. RUN TEST, CALCULATE SW F-STATISTIC
  5. Post SW F-STATISTIC, as well as clustered version for comparison
  ****/


/** Set-up **/
keep if ~mi(`v') // need this, as when we do this ourselves, we may otherwise include some observations that aren't in the second stage


local weight "aweight=weight"

/***** REGRESSION TYPE 1: eligible households **/
* Here, we have 2 endogenous variables, 2 exogenous variables
local endog_list "pp_actamt_ownvill"
local exog_list "treat"

forval rad = 2(2)`maxrad' {
  local r2 = `rad' - 2
  local endog_list "`endog_list' pp_actamt_ov_`r2'to`rad'km"
  local exog_list "`exog_list' share_ge_elig_treat_ov_`r2'to`rad'km"
}


  ** what we are considering "truth"
  ivreg2 `v' `blvars' ( `endog_list' =  `exog_list') [`weight' `exp'] if sample == 1, first `se'

  loc ownvill_check = _b[pp_actamt_ownvill]
  loc 0to2_check    = _b[pp_actamt_ov_0to2km]

  matrix A = e(first)
  cap gen cons = 1



  ** setting it up separately -- x1
  ivreg2 pp_actamt_ownvill (pp_actamt_ov_0to2km  = treat share_ge_elig_treat_ov_0to2km ) `blvars' [`weight' `exp'] if sample == 1
  predict res1, r

  ** Adjustment for number of exogenous variables
  loc df_adjust = e(exexog_ct)
  di "DF adjust" `df_adjust'

  reg res1 `exog_list' `blvars' [`weight' `exp'] if sample == 1, `se'
  test `exog_list'
  scalar Fsw1_cluster = `df_adjust'*r(F)
  di "Comparing clustered SEs: should match, or IVReg be missing"
  di "S-W F-stat:" Fsw1_cluster
  di "IVReg, all: " A[8,1]

  sca sw_confirm = round(A[8,1], 0.01) - round(Fsw1_cluster, 0.01)
  assert sw_confirm == 0
  sca drop sw_confirm

  ** Now, estimating spatial S-W F-Stat
  if $runGPS == 1 {
    di "Running OLS spatial HAC"
    ols_spatial_HAC res1 cons `exog_list' `blvars' [`weight' `exp'] if sample == 1, lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    test `exog_list'
    scalar Fsw1_spatial = `df_adjust'*r(F)
    di "S-W F-stat, spatial:" Fsw1_spatial
  }
  else {
    sca Fsw1_spatial = .
  }


  ** posting results **
  * postfile reference list: postfile sw_results str32(outcome endog) str128(endog_list exog_list) str20(spec) double(swf swf_resid swf_clust ivest) str6(table)
  post sw_results ("`v'") ("pp_actamt_ownvill") ("`endog_list'") ("`exog_list'") ("elig") (Fsw1_spatial) (.) (Fsw1_cluster) (`ownvill_check') ("`table'")

  /*** Other village term, eligible specification ***/

  ivreg2 pp_actamt_ov_0to2km  ( pp_actamt_ownvill = treat share_ge_elig_treat_ov_0to2km ) `blvars' [`weight' `exp'] if sample == 1
  predict res2, r
  loc df_adjust = e(exexog_ct)
  di "DF adjust" `df_adjust'

  reg res2 `exog_list' `blvars' [`weight' `exp'] if sample == 1, `se'
  test `exog_list'
  scalar Fsw2_cluster = `df_adjust'*r(F)
  di "S-W F-stat:" Fsw2_cluster
  di "IVReg: " A[8,2]

  sca sw_confirm = round(A[8,2], 0.01) - round(Fsw2_cluster, 0.01)
  assert sw_confirm == 0
  sca drop sw_confirm

  *** Now running spatial version ***
  if $runGPS == 1 {
  di "Running OLS spatial HAC"
  ols_spatial_HAC res2 cons `blvars' `exog_list' [`weights'] if sample == 1, lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  test `exog_list'
  scalar Fsw2_spatial = `df_adjust'*r(F)
  di "S-W F-stat, x2:" Fsw2_spatial
}
  else {
    sca Fsw2_spatial = .
  }

  * postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
  post sw_results ("`v'") ("pp_actamt_ov_0to2km") ("`endog_list'") ("`exog_list'") ("elig") (Fsw2_spatial) (.) (Fsw2_cluster) (`0to2_check') ("`table'")

  di "XXX Displaying everything for elig households, `v' :"
  di "IVReg (cluster), S-W, F1|2 :" A[8,1]
  di "Check, S-W, F1|2 :" Fsw1_cluster
  di "Spatial, S-W, F1|2 :" Fsw1_spatial
  di "IVReg (cluster), S-W, F2|1 :" A[8,2]
  di "Check, S-W, F2|1 :" Fsw2_cluster
  di "Spatial, S-W, F1|2 :" Fsw2_spatial


  /******************************************************/
  /** Now, turning to non-recipient households **/

  estimates clear
  forval i = 1/3 {
    cap drop res`i'
    cap drop Fsw`i'_spatial
    cap drop Fsw`i'_cluster
  }
  cap drop sw_confirm
  local exog_list_el ""
  local endog_list_el ""
  local exog_list_in ""
  local endog_list_in ""

  forval rad = 2(2)`maxrad' {
    local r2 = `rad' - 2

    gen pp_amt_`r2'to`rad'km_el = pp_actamt_`r2'to`rad'km * eligible
    gen pp_amt_`r2'to`rad'km_in = pp_actamt_`r2'to`rad'km * ineligible

    gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
    gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible

    local endog_list_el = "`endog_list_el'" + " pp_amt_`r2'to`rad'km_el"
    local exog_list_el = "`exog_list_el'" + " share_ge_elig_treat_`r2'to`rad'km_el"
    local endog_list_in = "`endog_list_in'" + " pp_amt_`r2'to`rad'km_in"
    local exog_list_in = "`exog_list_in'" + " share_ge_elig_treat_`r2'to`rad'km_in"

  }

  di "Eligible:"
  di "`endog_list_el'"
  di "`exog_list_el'"

  di "Ineligible:"
  di "`endog_list_in'"
  di "`exog_list_in'"


  ** what we are considering "truth"
  // first, we estimate "full" specification to ensure point estimates will match. This may not give cluster SE S-W values though
  ivreg2 `v' `blvars_untreat' eligible ( `endog_list_el' `endog_list_in' =  `exog_list_el' `exog_list_in') [`weight' `exp'] if (eligible == 0 | treat == 0), first `se'

  loc iv_el = _b[pp_amt_0to2km_el]
  loc iv_in = _b[pp_amt_0to2km_in]

  matrix B = e(first)


  ** Now, doing full version for eligible households
  ivreg2 pp_amt_0to2km_el (pp_amt_0to2km_in  = `exog_list_el' `exog_list_in' ) ``blvars_untreat'' eligible [`weight' `exp'] if (eligible == 0 | treat == 0)
  predict res1, r
  loc df_adjust_start = e(exexog_ct)
  di "DF adjust" `df_adjust'

  reg res1 `exog_list_el' `exog_list_in' ``blvars_untreat'' eligible [`weight' `exp'] if (eligible == 0 | treat == 0), `se'
  test `exog_list_el' `exog_list_in'
  if r(drop) == 1 {
    local k = 1
    local c_drop = 0
    while `k' <= `df_adjust_start' {
      if r(dropped_`k') != . {
        local ++c_drop
      }
      local ++k
    }
  loc df_adjust = `df_adjust_start' - `c_drop'
  }
  else {
    loc df_adjust = `df_adjust_start'
  }
  scalar Fsw1_cluster = `df_adjust'*r(F)

  di "XX Elig and Inelig Together, for Eligible: XX"
  di "S-W F-stat, cluster:" Fsw1_cluster
  di "IVReg, clustered: " B[8,1]

  ** Now, estimating spatial SEs
  if $runGPS == 1 {
  di "Running OLS spatial HAC"
  ols_spatial_HAC res1 cons ``blvars_untreat'' eligible `exog_list_el' `exog_list_in' [`weights'] if (eligible == 0 | treat == 0), lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  test `exog_list_el' `exog_list_in'
  if r(drop) == 1 {
    local k = 1
    local c_drop = 0
    while `k' <= `df_adjust_start' {
      if r(dropped_`k') != . {
        local ++c_drop
      }
      local ++k
    }
  loc df_adjust = `df_adjust_start' - `c_drop'
  }
  else {
    loc df_adjust = `df_adjust_start'
  }
  scalar Fsw1_spatial = `df_adjust'*r(F)
  di "S-W F-stat, spatial x1:" Fsw1_spatial

  di "Running OLS spatial HAC -- Elig only version"
  ols_spatial_HAC pp_amt_0to2km_el cons ``blvars_untreat'' eligible `exog_list_el' [`weights'] if (eligible == 0 | treat == 0), lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  test `exog_list_el'
  scalar Fsw1_indiv = r(F) // no adjustment, only one exogenous variable
  di "S-W F-stat, elig only:" Fsw1_indiv

}
  else {
    sca Fsw1_spatial = .
    sca Fsw1_indiv = .
  }

  ** Exporting results **
  * postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
  post sw_results ("`v'") ("pp_amt_0to2km_el") ("pp_amt_0to2km_in") ("`exog_list_el' `exog_list_in'") ("nonrec") (Fsw1_spatial) (Fsw1_indiv) (Fsw1_cluster) (`iv_el') ("`table'")


  /*** Ineligible households ***/
    ivreg2 pp_amt_0to2km_in  ( pp_amt_0to2km_el = `exog_list_el' `exog_list_in' ) `blvars_untreat' eligible [`weight' `exp'] if (eligible == 0 | treat == 0)
    predict res2, r
    loc df_adjust_start = e(exexog_ct)

    reg res2 `exog_list_el' `exog_list_in' `blvars_untreat' eligible [`weight' `exp'] if (eligible == 0 | treat == 0), `se'
    test `exog_list_el' `exog_list_in'
    if r(drop) == 1 {
      local k = 1
      local c_drop = 0
      while `k' <= `df_adjust_start' {
        if r(dropped_`k') != . {
          local ++c_drop
        }
        local ++k
      }
    loc df_adjust = `df_adjust_start' - `c_drop'
    }
    else {
      loc df_adjust = `df_adjust_start'
    }
    di "DF adjust" `df_adjust'

    scalar Fsw2_cluster = `df_adjust'*r(F)

    di "XX Elig and Inelig Together, for Ineligible: XX"
    di "S-W F-stat, cluster :" Fsw2_cluster
    di "IVReg, cluster: " B[8,2]

    ** now running spatial version **
    if $runGPS == 1 {
    di "Running OLS spatial HAC"
    ols_spatial_HAC res2 cons `blvars_untreat' eligible `exog_list_el' `exog_list_in' [`weights'] if (eligible == 0 | treat == 0), lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    test `exog_list_el' `exog_list_in'
    if r(drop) == 1 {
      local k = 1
      local c_drop = 0
      while `k' <= `df_adjust_start' {
        if r(dropped_`k') != . {
          local ++c_drop
        }
        local ++k
      }
    loc df_adjust = `df_adjust_start' - `c_drop'
    }
    else {
      loc df_adjust = `df_adjust_start'
    }
    di "DF adjust" `df_adjust'

    scalar Fsw2_spatial = `df_adjust'*r(F)
    di "S-W F-stat, spatial x1:" Fsw2_spatial

    di "Running OLS spatial HAC -- Inelig only version"
    ols_spatial_HAC pp_amt_0to2km_in cons `blvars_untreat' eligible `exog_list_in' [`weights'] if (eligible == 0 | treat == 0), lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    test `exog_list_in'
    scalar Fsw2_indiv = r(F) // no adjustment, only 1 exogenous variable
    di "S-W F-stat, inelig only:" Fsw2_indiv

  }
  else {
    sca Fsw2_spatial = .
    sca Fsw2_indiv = .
  }

    ** Exporting results **
    * postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
    post sw_results ("`v'") ("pp_amt_0to2km_in") ("pp_amt_0to2km_el") ("`exog_list_el' `exog_list_in'") ("nonrec") (Fsw2_spatial) (Fsw2_indiv) (Fsw2_cluster) (`iv_in') ("`table'")


}
// end of household loop



/******************************************************/
/*              ENTERPRISE REGRESSIONS                */
/******************************************************/
/* Listing endogenous and exogenous variables. The following are present in all specifications. We then increment these by radii band */
if "`ent'" != "" {

** Running Preliminaries **
include "$do/analysis/prep/prep_VillageLevel.do"


** for village level outcomes **
if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {
use "$da/GE_VillageLevel_ECMA.dta", clear
gen run_id = _n
gen date = run_id // TG we have no time series here, so I just create a pseudo-panel of depth one.

if $runGPS == 1 {
  merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
}

cap la var n_allents "\emph{Panel C: Village-level} & & & & \\ Number of enterprises"
cap la var n_operates_from_hh "Number of enterprises, operated from hh"
cap la var n_operates_outside_hh "Number of enterprises, operated outside hh"
cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
cap la var n_ent_eligibletreat "Number of enterprises, owned by treated households"
cap la var n_ent_ineligible "Number of enterprises, owned by untreated households"

merge 1:1 village_code using `temphh'
gen phh_`v' = `v' / n_hh


local panvar "run_id"
local timvar "date"


* adding village-level baseline variables - if they are in the dataset **
di "NoBL: `nobl'"

if "`nobl'" == "" {
  cap desc `v'_BL
  if _rc == 0 {
      gen phh_`v'_BL = `v'_BL / n_hh
     local blvars "phh_`v'_BL"
  }
  else {
      local blvars ""
  }
  loc omit = 0
}
// if No BL is selected:
else {
  local blvars "" // don't want to include baseline variables
  cap desc `v'_BL // no BL value, display dash instead of estimate
  if _rc == 0 {
    local omit = 0
  }
  else {
    loc omit = 1
  }
}
// end No BL condition

  di "Check: baseline vars: `blvars'"
  di "Check: omit: `omit'; omit string `omitstring'"


** B. Spatial regressions **
****************************
cap gen cons = 1

keep if ~mi(phh_`v')

local endog_list = "pp_actamt_ownvill"
local exog_list = "treat"

forval rad = 2(2)`maxrad' {
  local r2 = `rad' - 2
  local endog_list "`endog_list' pp_actamt_ov_`r2'to`rad'km"
  local exog_list "`exog_list' share_ge_elig_treat_ov_`r2'to`rad'km"
}

** what we are considering "truth"
ivreg2 phh_`v' `blvars' ( `endog_list' =  `exog_list') [aweight=n_hh], first

loc ownvill_check = _b[pp_actamt_ownvill]
loc 0to2_check    = _b[pp_actamt_ov_0to2km]

matrix A = e(first)
cap gen cons = 1


** setting it up separately -- x1
ivreg2 pp_actamt_ownvill (pp_actamt_ov_0to2km  = treat share_ge_elig_treat_ov_0to2km ) `blvars' [aweight=n_hh]
predict res1, r
loc df_adjust = e(exexog_ct)
di "DF adjust" `df_adjust'

reg res1 `exog_list' `blvars' [aweight=n_hh]
test `exog_list'
scalar Fsw1_cluster = `df_adjust'*r(F)
di "S-W F-stat:" Fsw1_cluster
di "IVReg: " A[8,1]

sca sw_confirm = round(A[8,1], 0.01) - round(Fsw1_cluster, 0.01)
assert sw_confirm == 0

** If this works, then generate spatial OLS version
if $runGPS == 1 {
di "Running OLS spatial HAC"
ols_spatial_HAC res1 cons `blvars' `exog_list' [aweight=n_hh], lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
test `exog_list'
scalar Fsw1_spatial = `df_adjust'*r(F)
di "S-W F-stat, x1:" Fsw1_spatial
}
else {
  sca Fsw1_spatial = .
}

** Exporting results **
* postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
post sw_results ("`v'") ("pp_actamt_ownvill") ("`endog_list'") ("`exog_list'") ("ent_vill") (Fsw1_spatial) (.) (.) (`ownvill_check') ("`table'")
// this is not really a clustered SE so omitting from export


** x2
ivreg2 pp_actamt_ov_0to2km  ( pp_actamt_ownvill = treat share_ge_elig_treat_ov_0to2km ) `blvars' [aweight=n_hh]
predict res2, r
loc df_adjust = e(exexog_ct)
di "DF adjust" `df_adjust'

reg res2 `exog_list' `blvars' [aweight=n_hh]
test `exog_list'
scalar Fsw2_cluster = `df_adjust'*r(F)
di "S-W F-stat:" Fsw2_cluster
di "IVReg: " A[8,2]

sca sw_confirm = round(A[8,2], 0.01) - round(Fsw2_cluster, 0.01)
assert sw_confirm == 0
sca drop sw_confirm

if $runGPS == 1 {
di "Running OLS spatial HAC"
ols_spatial_HAC res2 cons `blvars' `exog_list' [aweight=n_hh], lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
test `exog_list'
scalar Fsw2_spatial = `df_adjust'*r(F)
di "S-W F-stat, x2:" Fsw2_spatial
}
else {
  sca Fsw2_spatial = .
}

** Exporting results **
* postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
post sw_results ("`v'") ("pp_actamt_ov_0to2km") ("pp_actamt_ownvill") ("treat share_ge_elig_ov_0to2km") ("ent_vill") (Fsw2_spatial) (.) (.) (`0to2_check') ("`table'")



di "Displaying everything for village-level enterprises:"
di "IVReg, S-W, F1|2 :" A[8,1]
di "Check, S-W, F1|2 :" Fsw1_cluster
di "Spatial, S-W, F1|2 :" Fsw1_spatial
di "IVReg, S-W, F2|1 :" A[8,2]
di "check (cluster), S-W, F2|1 :" Fsw2_cluster
di "Spatial, S-W, F2|1 :" Fsw2_spatial

}
// end of village enterprise loop
else {
project, original("$da/GE_Enterprise_ECMA.dta") preserve
use "$da/GE_Enterprise_ECMA.dta", clear
gen run_id = _n

local panvar "run_id"
local timvar "date"

if $runGPS == 1 {
  merge 1:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
}

ren ent_profmarg2_wins_vBL ent_profitmargin2_wins_vBL
ren Ment_profmarg2_wins_vBL Ment_profitmargin2_wins_vBL

merge m:1 village_code using `temphh'
drop _merge
merge m:1 village_code using `tempent_el'
drop _merge

tab ent_type // confirming 3 types
forval i = 1/3 {
  gen ent_type`i' = (ent_type == `i') if ~mi(ent_type)
}

** adding village-level baseline variables - if they are in the dataset **
di "NoBL: `nobl'"
if "`nobl'" == "" { // if nobl specified, set to blank
cap desc `v'_vBL M`v'_vBL
if _rc == 0 {
  loc vblvars ""
  forval i = 1/3 {
    gen `v'_vBL_ent`i' = `v'_vBL * ent_type`i'
    gen M`v'_vBL_ent`i' = M`v'_vBL * ent_type`i'
    local vblvars "`vblvars' `v'_vBL_ent`i' M`v'_vBL_ent`i'"
  }
}
else {
  local vblvars ""
}
loc omit = 0
}
else {
local vblvars "" // don't include baseline values
cap desc `v'_vBL M`v'_vBL // if no baseline values, omit from table
if _rc == 0 {
  loc omit = 0
}
else {
  local omit = 1
}
}

di "Baseline vars: `vblvars'"


** setting weights **
gen weight = entweight_EL
if "`v'" == "ent_profitmargin2_wins" {
  gen entweight_rev_EL = entweight_EL * ent_revenue2_wins_PPP
  replace weight = entweight_rev_EL
}

local weight "aweight=weight"

keep if ~mi(`v')

// setting max number of enterprise types -- for those that we don't have data from ag, this is 2, otherwise 3
if inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {
  local max_enttype = 2
}
else {
  loc max_enttype = 3
}



  forval i=1/`max_enttype' {
    gen pp_amt_ownvill_ent`i' = pp_actamt_ownvill * ent_type`i'
    gen treat_ent`i' = treat * ent_type`i'

    local endog_list_ent`i' = "pp_amt_ownvill_ent`i'"
    local exog_list_ent`i' = "treat_ent`i'"

  }


  forval rad = 2(2)`maxrad' {
    local r2 = `rad' - 2

    ** generating specific variables, rather than relying on canned interactions, for conditional regressions **
    forval i=1/`max_enttype' {
      gen pp_amt_ov_`r2'to`rad'km_ent`i' = pp_actamt_ov_`r2'to`rad'km * ent_type`i'
      gen s_ge_elig_treat_ov_`r2'to`rad'km_ent`i' = share_ge_elig_treat_ov_`r2'to`rad'km * ent_type`i'

      local endog_list_ent`i' = "`endog_list_ent`i''" + " pp_amt_ov_`r2'to`rad'km_ent`i'"
      local exog_list_ent`i' = "`exog_list_ent`i''" +  " s_ge_elig_treat_ov_`r2'to`rad'km_ent`i'"

    }
  }

  di "Endog: `endog_list_ent1' `endog_list_ent2' `endog_list_ent3'"
  di "Exog: `exog_list_ent1' `exog_list_ent2' `exog_list_ent3'"

  loc endog_list "`endog_list_ent1' `endog_list_ent2' `endog_list_ent3'"
  loc exog_list "`exog_list_ent1' `exog_list_ent2' `exog_list_ent3'"

  cap gen cons = 1

  /*** RUNNING EVERYTHING TOGETHER ***/
  ** what we consider as truth -- ivreg version **
  ivreg2 `v' (`endog_list' = `exog_list')  ent_type? `vblvars' [aweight=weight], first `se'

    loc exexog_ct_all = e(exexog_ct)
    di "Exog count:" `exexog_ct_all'


  forval i=1/`max_enttype' {
    loc iv_own_ent`i'_true = _b[pp_amt_ownvill_ent`i']
    loc iv_ov_ent`i'_true = _b[pp_amt_ov_0to2km_ent`i']
  }

  matrix B = e(first)
  cap gen cons = 1

  matrix list B


  ** setting it up separately -- x1
  ** residual with all ent type version
  local j = 1

  forval i = 1/`max_enttype' {
    cap drop res1 res2

    ** setting conditional locals **
    if `max_enttype' == 3 {
    if `i' == 1 {
      loc endog_cond "pp_amt_ownvill_ent2 pp_amt_ownvill_ent3 pp_amt_ov_0to2km_ent2 pp_amt_ov_0to2km_ent3"
    }
    else if `i' == 2 {
      loc endog_cond "pp_amt_ownvill_ent1 pp_amt_ownvill_ent3 pp_amt_ov_0to2km_ent1 pp_amt_ov_0to2km_ent3"
    }
    else if `i' == 3 {
      loc endog_cond "pp_amt_ownvill_ent1 pp_amt_ownvill_ent2 pp_amt_ov_0to2km_ent1 pp_amt_ov_0to2km_ent2"
    }
  }
  else if `max_enttype' == 2 {
    if `i' == 1 {
      loc endog_cond "pp_amt_ownvill_ent2 pp_amt_ov_0to2km_ent2 "
    }
    else if `i' == 2 {
      loc endog_cond "pp_amt_ownvill_ent1  pp_amt_ov_0to2km_ent1 "
    }
  }

  ** Own village term **
  ivreg2 pp_amt_ownvill_ent`i' (pp_amt_ov_0to2km_ent`i' `endog_cond'  = `exog_list') ent_type?  `vblvars' [aweight=weight]
  predict res1, r

  loc df_adjust_start = e(exexog_ct)

  reg res1 `exog_list' ent_type? `vblvars'  [aweight=weight], `se'
  test `exog_list'
  if r(drop) == 1 {
    local k = 1
    local c_drop = 0
    while `k' <= `df_adjust_start' {
      if r(dropped_`k') != . {
        local ++c_drop
      }
      local ++k
    }
  loc df_adjust = `df_adjust_start' - `c_drop'
  }
  else {
    loc df_adjust = `df_adjust_start'
  }
  di "DF adjust: `df_adjust'"
  scalar Fsw1_`i'_cluster = `df_adjust'*r(F) //*r(df_r)/(r(df_r) - 2)
  di "S-W cluster F-stat:" Fsw1_`i'_cluster
  di "IVReg cluster, full: " B[8,`j']


  ** Bringing in spatial regression **
  if $runGPS == 1 {
  di "Running OLS spatial HAC -- Enterprise `i', Own village"
  ols_spatial_HAC res1 cons `vblvars' `exog_list' ent_type? [`weights'], lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  test `exog_list'
  if r(drop) == 1 {
    local k = 1
    local c_drop = 0
    while `k' <= `df_adjust_start' {
      if r(dropped_`k') != . {
        local ++c_drop
      }
      local ++k
    }
  loc df_adjust = `df_adjust_start' - `c_drop'
  }
  else {
    loc df_adjust = `df_adjust_start'
  }
  scalar Fsw1_`i'_spatial = `df_adjust'*r(F)
  di "S-W spatial F-stat, x1:" Fsw1_`i'_spatial
}
  else {
    sca Fsw1_`i'_spatial = .
  }

  ** Exporting results **
  * postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
  post sw_results ("`v'") ("pp_amt_ownvill_ent`i'") ("pp_amt_ov_0to2km_ent`i' `endog_cond'") ("`exog_list'") ("ent") (Fsw1_`i'_spatial) (.) (Fsw1_`i'_cluster) (`iv_own_ent`i'_true') ("`table'")

  /***** OTHER VILLAGE *****/
  loc ++j

  ivreg2 pp_amt_ov_0to2km_ent`i' (pp_amt_ownvill_ent`i' `endog_cond'  = `exog_list') ent_type? `vblvars' [aweight=weight]
  predict res2, r

  loc df_adjust_start = e(exexog_ct)

  reg res2 `exog_list' ent_type? `vblvars'  [aweight=weight], `se'
  di "DF adjust: " `df_adjust'
  test `exog_list'
  if r(drop) == 1 {
    local k = 1
    local c_drop = 0
    while `k' <= `df_adjust_start' {
      if r(dropped_`k') != . {
        local ++c_drop
      }
      local ++k
    }
  loc df_adjust = `df_adjust_start' - `c_drop'
  }
  else {
    loc df_adjust = `df_adjust_start'
  }
  di "DF adjust" `df_adjust'

  scalar Fsw2_`i'_cluster = `df_adjust'*r(F) //*r(df_r)/(r(df_r) - 2)
  di "S-W cluster F-stat:" Fsw2_`i'_cluster
  di "IVReg cluster, all: " B[8,`j']

  ** Bringing in spatial regression **
  if $runGPS == 1 {
  di "Running OLS spatial HAC -- Enterprise `i', Other village"
  ols_spatial_HAC res2 cons `vblvars' `exog_list' ent_type? [`weights'], lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  test `exog_list'
  if r(drop) == 1 {
    local k = 1
    local c_drop = 0
    while `k' <= `df_adjust_start' {
      if r(dropped_`k') != . {
        local ++c_drop
      }
      local ++k
    }
  loc df_adjust = `df_adjust_start' - `c_drop'
  }
  else {
    loc df_adjust = `df_adjust_start'
  }
  scalar Fsw2_`i'_spatial = `df_adjust'*r(F)
  di "S-W spatial F-stat, x2:" Fsw2_`i'_spatial

}
else {
  sca Fsw2_`i'_spatial = .
}

  * postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
  post sw_results ("`v'") ("pp_amt_ov_0to2km_ent`i'") ("pp_amt_ownvill_ent`i' `endog_cond'") ("`exog_list'") ("ent") (Fsw2_`i'_spatial) (.) (Fsw2_`i'_cluster) (`iv_ov_ent`i'_true') ("`table'")

  loc ++j
}

** loopign through each enterprise type **
loc j = 1
forval i = 1/`max_enttype' {

  ivreg2 `v' (`endog_list_ent`i'' = `exog_list_ent`i'') ent_type? `vblvars' [aweight=weight], first `se'

  loc iv_own_ent`i'_indiv = _b[pp_amt_ownvill_ent`i']
  loc iv_oth_ent`i'_indiv = _b[pp_amt_ov_0to2km_ent`i']

  matrix B_`i' = e(first)

  cap drop res1 res2

  if `i' == 1 {
    loc endog_cond "pp_amt_ownvill_ent2 pp_amt_ownvill_ent3 pp_amt_ov_0to2km_ent2 pp_amt_ov_0to2km_ent3"
  }
  else if `i' == 2 {
    loc endog_cond "pp_amt_ownvill_ent1 pp_amt_ownvill_ent3 pp_amt_ov_0to2km_ent1 pp_amt_ov_0to2km_ent3"
  }
  else if `i' == 3 {
    loc endog_cond "pp_amt_ownvill_ent1 pp_amt_ownvill_ent2 pp_amt_ov_0to2km_ent1 pp_amt_ov_0to2km_ent2"
  }


** Running separately by enterprise type **
di "Check ##"
cap drop res1
ivreg2 pp_amt_ownvill_ent`i' (pp_amt_ov_0to2km_ent`i'  = `exog_list_ent`i'') `vblvars' ent_type? [`weight' `exp']
predict res1, r
local df_adjust_start = e(exexog_ct)

reg res1 `exog_list_ent`i'' `vblvars' ent_type? [`weight' `exp'], `se'
test `exog_list_ent`i''
if r(drop) == 1 {
  local k = 1
  local c_drop = 0
  while `k' <= `df_adjust_start' {
    if r(dropped_`k') != . {
      local ++c_drop
    }
    local ++k
  }
loc df_adjust = `df_adjust_start' - `c_drop'
}
else {
  loc df_adjust = `df_adjust_start'
}
di "DF adjust" `df_adjust'

scalar Fsw_check1_`i' = `df_adjust'*r(F) //*r(df_r)/(r(df_r) - 2)
di "S-W F-stat:" Fsw_check1_`i'
di "IVReg, all: " B[8,`j']
di "IV Reg, ent `i' only" B_`i'[8,1]


loc ++j

/***** OTHER VILLAGE *****/

*** Separately by enterprise type ***
cap drop res2
ivreg2 pp_amt_ov_0to2km_ent`i' (pp_amt_ownvill_ent`i' = `exog_list_ent`i'') `vblvars' ent_type? [`weight' `exp']
predict res2, r
local df_adjust_start = e(exexog_ct)

reg res2 `exog_list_ent`i'' `vblvars' ent_type? [`weight' `exp'], `se'
test `exog_list_ent`i''
if r(drop) == 1 {
  local k = 1
  local c_drop = 0
  while `k' <= `df_adjust_start' {
    if r(dropped_`k') != . {
      local ++c_drop
    }
    local ++k
  }
loc df_adjust = `df_adjust_start' - `c_drop'
}
else {
  loc df_adjust = `df_adjust_start'
}
di "DF adjust" `df_adjust'

scalar Fsw_check2_`i' = `df_adjust'*r(F) //*r(df_r)/(r(df_r) - 2)
di "S-W F-stat:" Fsw_check2_`i'
di "IVReg, all: " B[8,`j']
di "IV Reg, ent `i' only" B_`i'[8,2]

loc ++j

}

di "XXX Displaying everything for enterprises: `v' XXX"
di "Enterprise 1"
di "IVReg all, S-W, F1|2 :" B[8,1]
di "FSW cluster, F1|2 :" Fsw1_1_cluster
di "IVReg ent only, S-W, F1|2 :" B_1[8,1]
di "FSW spatial :" Fsw1_1_spatial
di ""
di "IVReg all, S-W, F2|1 :" B[8,2]
di "FSW Check, F2|1 :" Fsw2_1_cluster
di "IV Reg ent only, F2|1 :" B_1[8,2]
di "FSW spatial :" Fsw2_1_spatial
di ""
di "Enterprise 2"
di "IVReg, S-W, F1|2 :" B[8,3]
di "FSW Check, F1|2 :" Fsw1_2_cluster
di "IVReg ent only, S-W, F1|2 :" B_2[8,1]
di "FSW spatial :" Fsw1_2_spatial
di ""
di "IVReg, S-W, F2|1 :" B[8,4]
di "FSW Check, F2|1 :" Fsw2_2_cluster
di "IV Reg ent only, F2|1 :" B_2[8,2]
di "FSW spatial :" Fsw2_2_spatial
di ""
if `max_enttype' == 3 {
di "Enterprise 3"
di "IVReg, S-W, F1|2 :" B[8,5]
di "FSW Check, F1|2 :" Fsw1_3_cluster
di "IVReg ent only, S-W, F1|2 :" B_3[8,1]
di "FSW spatial :" Fsw1_3_spatial
di ""
di "IVReg, S-W, F2|1 :" B[8,6]
di "FSW Check, F2|1 :" Fsw2_3_cluster
di "IV Reg ent only, F2|1 :" B_3[8,2]
di "FSW spatial :" Fsw2_3_spatial
}

}
}
// end of enterprise loop

}
// end of SE loop


end
