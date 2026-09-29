
** Defining program to generate BIC split sample tables **
************************************************************
/* Program outline:
* 1. Replicate main results, record main radii bands (these are stored in rep 0 in postfile)
* 2. Go through split sample approach
* For both of these, there are 3 main cases:
a. Households
b. Enterprises
c. Village-level enterprise numbers
*/

cap program drop bic_splitsample
program define bic_splitsample
syntax using, outcomes(string) reps(integer) enterprise(integer) postfile(string) [tableonly]


* setting up blank table *
quietly {
  drop _all
  local ncols = 8
  local nrows = max(2,wordcount("`outcomes'"))

  *** CREATE EMPTY TABLE ***
  eststo clear
  est drop _all
  set obs `nrows'
  gen x = 1
  gen y = 1

  forvalues x = 1/`ncols' {
    qui eststo col`x': reg x y
  }
}

local varcount = 1
local count = 1
local countse = `count'+1
local countspace = `count' + 2

local varlabels ""


scalar numoutcomes = 0

** Randomization Set-up **
cap postclose bic_reps
postfile bic_reps str32(outcome est_type) int(rep split radii) double(estimate se lower_ci upper_ci) using "`postfile'", replace

set seed 311 // time when doing early run

/******************************************************/
/*    PART 0: SET-UP (APPLIES TO ALL CASES)           */
/******************************************************/


foreach v in `outcomes' {
  di "Loop for `v'"

  ** Find source for variable v **
  use "$da/GE_VillageLevel_ECMA.dta", clear
  capture: confirm variable `v'
  if _rc == 0 {
    local source = "$da/GE_VillageLevel_ECMA.dta"
  }

  use "$da/GE_Enterprise_ECMA.dta", clear
  capture: confirm variable `v'
  if _rc == 0 {
    local source = "$da/GE_Enterprise_ECMA.dta"
  }

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

  if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {
    loc source = "$da/GE_VillageLevel_ECMA.dta"
  }

  disp "`source'"

  ** Load dataset **
  use "`source'", clear
  cap gen cons = 1
  cap drop w_*


  ** set panel and time variables **
  if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
    local timvar = "avgdate_vill"
    local panvar = "village_code"
    if $runGPS == 1 {
      merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
    }
  }

  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta")  {
    local timvar = "survey_mth"
    local panvar = "hhid"
    if $runGPS == 1 {
      merge 1:1 hhid using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
    }
  }

  if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
    local timvar = "date"
    local panvar = "run_id"
    //adjusted time and panel variables according to the main enterprise analysis
    if $runGPS == 1 {
      merge 1:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
    }
  }

  if inlist("`source'", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
    local timvar = "survey_mth"
    local panvar = "persid"
    if $runGPS == 1 {
      merge n:1 hhid using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
    }
  }



  ge_label_variables

  ** define weight / generate weighted variables **
  if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
    gen weight = 1

  }

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


  if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
    gen weight = entweight_EL

    ** set quantity-based weight for price variables **
    if "`v'" == "wage_h_wins_PPP" {
      replace weight = weight * emp_h_tot
    }
    if "`v'" == "ent_profitmargin2_wins" {
      replace weight = weight * ent_revenue2_wins_PPP
    }
  }

  scalar numoutcomes = numoutcomes + 1


  ** define sample **
  if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
    gen sample = 1
  }

  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
    gen sample = eligible
  }

  if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
    gen sample = 1
  }

  ** setting baseline variables **
  // household baseline variables
  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {

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
  }

  ** for enterprises (enterprise or village-level) -- generate counts **

  if inlist("`source'", "$da/GE_Enterprise_ECMA.dta", "$da/GE_VillageLevel_ECMA.dta") {
    preserve
    ** Running Preliminaries **
    include "$do/analysis/prep/prep_VillageLevel.do"
    restore
  }

  *** Case B: enterprises use village-level baseline variables ***
  if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
    cap desc `v'_vBL M`v'_vBL
    if _rc == 0 {
      local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
    }
    else {
      local vblvars ""
    }
  }
  // end baseline vars for case B

  **** n_allents slightly different than rest ****
  if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {

    merge 1:1 village_code using `temphh'
    gen phh_`v' = `v' / n_hh

    * adding village-level baseline variables - if they are in the dataset **
    cap desc `v'_BL
    if _rc == 0 {
      gen phh_`v'_BL = `v'_BL / n_hh
      local blvars "phh_`v'_BL"
    }
    else {
      local blvars ""
    }
  }
  // end baseline vars for case C


  /******************************************************/
  /*        PART 1: GENERATING MAIN ESTIMATES           */
  /******************************************************/

  ***** Case A: Households  *****

  ** 1. Total treamtment effect on the treated (eligibles) from the 'optimal' spatial regression **
  *****************************************************************************************************
  ** calculate optimal radii - for subcomponents of an index, we use the overall index
  // opening loop for households
  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
    ** for consumption, use overall consumption
    if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
      calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if sample == 1, elig // no bl vars
    }
    ** for assets, use total assets
    else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
      calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if sample == 1, elig blvars("`blvars'") // no bl vars
    }
    ** for hours or salary by ag/non-ag, use overall
    else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
      local vrb = subinstr("`v'","_agri","",.)
      local vrb = subinstr("`v'","_nag","",.)
      calculate_optimal_radii `vrb' [aweight=weight] if sample == 1, elig // no baseline vars for individual obs
    }
    ** for all others -- use variable
    else {
      calculate_optimal_radii `v' [aweight=weight] if sample == 1, elig blvars("`blvars'")
    }

    local r = r(r_max)
    local rec_r_full = `r'

    di "full r for `v' for recipients is `r_full'"

    local endregs "pp_actamt_ownvill"
    local exregs "treat"


    forval rad = 2(2)`r' {
      local r2 = `rad' - 2
      local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
      local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
    }

    if $runGPS == 1 {
      iv_spatial_HAC `v' cons `blvars' [aweight=weight] if sample == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    }
    if $runGPS == 0 {
      ivreg2 `v' `blvars' (`endregs' = `exregs') [aweight=weight] if sample == 1, cluster(sublocation_code)
    }


    ** Get mean total effect on treated eligibles **
    local ATEstring_tot "0"

    foreach vrb of local endregs {
      qui sum `vrb' [aweight=weight] if (sample == 1 & treat == 1)
      local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
    }

    qui disp "`ATEstring_tot'"
    qui lincom "`ATEstring_tot'", level(95)
    local ATE_tot = `r(estimate)'
    local SE_tot = `r(se)'

    **new to this program :obtain 95%-CI for recipient effects **

    loc rec_ci95lo = `ATE_tot' - 1.96 * `SE_tot'
    loc rec_ci95hi = `ATE_tot' + 1.96 * `SE_tot'

    ** storing main results in rep 0
    post bic_reps ("`v'") ("recipient") (0) (0) (`rec_r_full') (`ATE_tot') (`SE_tot') (`rec_ci95lo') (`rec_ci95hi')


    macro drop r r2

    * Total treatment effect for non-recipient households *
    ****************************************************
    if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
      calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec // no bl vars
      loc keep_r "p2_consumption_wins_PPP"
    }
    ** for assets, use total assets
    else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
      calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'")
      loc keep_r "p1_assets_wins_PPP"
    }
    ** for hours or salary by ag/non-ag, use overall
    else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
      local vrb = subinstr("`v'","_agri","",.)
      local vrb = subinstr("`v'","_nag","",.)
      calculate_optimal_radii `vrb' [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec  // no baseline vars for individual obs
      loc keep_r "`vrb'"
    }
    ** for all others -- use variable
    else {
      calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'")
    }

    local r = r(r_max)
    local nonrec_r_full = `r'

    di "full r for `v' for non-recipients is `r'"

    local endregs = ""
    local exregs = ""
    local amount_list = ""

    forval rad = 2(2)`r' {
      local r2 = `rad' - 2

      gen pp_actamt_`r2'to`rad'km_eligible = pp_actamt_`r2'to`rad'km * eligible
      gen pp_actamt_`r2'to`rad'km_ineligible = pp_actamt_`r2'to`rad'km * ineligible

      gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
      gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible

      local endregs = "`endregs'" + " pp_actamt_`r2'to`rad'km_eligible" + " pp_actamt_`r2'to`rad'km_ineligible"
      local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`rad'km_el"  + " share_ge_elig_treat_`r2'to`rad'km_in"

      local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
    }

    if $runGPS == 1 {
      iv_spatial_HAC `v' cons eligible `blvars_untreat' [aweight=weight] if (eligible == 0 | treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    }
    if $runGPS == 0 {
      ivreg2 `v' eligible `blvars_untreat' (`endregs' = `exregs') [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
    }

    eststo e_ivie

    ** Get mean total spillover effect on eligibles in control villages and ineligibles **
    sum weight if (eligible == 1 & treat == 0)
    local mean1 = r(sum)
    sum weight if (eligible == 0)
    local mean2 = r(sum)

    local eligcontrolweight = `mean1' / (`mean1' + `mean2')
    local ineligweight = `mean2' / (`mean1' + `mean2')

    local ATEstring_spillover = "0"
    foreach vrb of local amount_list {
      sum `vrb' [weight=weight] if (eligible == 1 & treat == 0)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`eligcontrolweight'" + "*`r(mean)'" + "*`vrb'_eligible"

      sum `vrb' [aweight=weight] if eligible == 0
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ineligweight'" + "*`r(mean)'" + "*`vrb'_ineligible"
    }

    disp "`ATEstring_spillover'"
    lincom "`ATEstring_spillover'", level(95)
    local ATE_spill = `r(estimate)'
    local SE_spill = `r(se)'

    ** new to this program: obtain 95% CI for non-recipient effects **
    loc nonrec_ci95lo = `ATE_spill' - 1.96 * `SE_spill'
    loc nonrec_ci95hi = `ATE_spill' + 1.96 * `SE_spill'


    ** storing main results in rep 0
    post bic_reps ("`v'") ("nonrecipient") (0) (0) (`nonrec_r_full') (`ATE_spill') (`SE_spill') (`nonrec_ci95lo') (`nonrec_ci95hi')

    ** saving dataset containing only variables needed for rest of program
    loc idkeep "hhid* village_code"
    if inlist("`v'", "emp_cshsal_perh_winP"){
      loc idkeep "`idkeep' persid"
    }

    keep `idkeep' *`v'* eligible ineligible treat pp_actamt_* share_* *weight* sample `keep_r'

    tempfile fullsample
    save `fullsample'

  }
  // ending households -- main table

  ***** Case B: Enterprises *****
  if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {

    gen run_id = _n

    /** Part 1: reproduce main table estimates **/
    merge m:1 village_code using `temphh', nogen
    merge m:1 village_code using `tempent_el', nogen

    ** Get number of enterprises of each group by treatment **
    sum entweight_EL if ent_type == 2 & treat == 1
    local n_ent_from_hh_treatall = r(sum)
    sum entweight_EL if ent_type == 2 & treat == 0
    local n_ent_from_hh_control = r(sum)
    sum entweight_EL if ent_type == 2 & hi_sat == 0 & treat == 0
    local n_ent_from_hh_lowsatcontrol = r(sum)
    sum entweight_EL if ent_type == 2
    local n_ent_from_hh_tot = r(sum)

    sum entweight_EL if ent_type == 1 & treat == 1
    local n_ent_outside_hh_treatall = r(sum)
    sum entweight_EL if ent_type == 1 & treat == 0
    local n_ent_outside_hh_control = r(sum)
    sum entweight_EL if ent_type == 1 & hi_sat == 0 & treat == 0
    local n_ent_outside_hh_lowsatcontrol = r(sum)
    sum entweight_EL if ent_type == 1
    local n_ent_outside_hh_tot = r(sum)

    sum entweight_EL if ent_type == 3 & treat == 1
    local n_ent_ownfarm_treatall = r(sum)
    sum entweight_EL if ent_type == 3 & treat == 0
    local n_ent_ownfarm_control = r(sum)
    sum entweight_EL if ent_type == 3 & hi_sat == 0 & treat == 0
    local n_ent_ownfarm_lowsatcontrol = r(sum)
    sum entweight_EL if ent_type == 3
    local n_ent_ownfarm_tot = r(sum)

    ** Here, we want to get the effect on the profit margin for the average enterprise **
    if "`v'" == "ent_profitmargin2_wins" {
      gen entweight_rev_EL = entweight_EL * ent_revenue2_wins_PPP

      sum entweight_rev_EL if (ent_type == 2)
      local mean1 = r(sum)
      sum entweight_rev_EL if (ent_type == 1)
      local mean2 = r(sum)
      sum entweight_rev_EL if (ent_type == 3)
      local mean3 = r(sum)

      local withinhhweight = `mean1' / (`mean1' + `mean2' + `mean3')
      local outsidehhweight = `mean2' / (`mean1' + `mean2' + `mean3')
      local ownfarmweight = `mean3' / (`mean1' + `mean2' + `mean3')

      disp "`withinhhweight'"
      disp "`outsidehhweight'"
      disp "`ownfarmweight'"
    }

    // note that weight here is entweight_EL or entweight_rev_EL, depending on outcome

    calculate_optimal_radii `v' [aweight=weight], ent blvars("`vblvars'")

    local r = r(r_max)
    local r2 = `r' - 2
    local r_full = `r'

    di "full r for `v' is `r_full'"

    local endregs = "c.pp_actamt_ownvill#ent_type"
    local exregs = "treat#ent_type"
    local amount_list = ""


    forval rad = 2(2)`r' {
      local r2 = `rad' - 2
      local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`rad'km#ent_type"
      local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`rad'km#ent_type"
      local amount_list = "`amount_list' pp_actamt_ov_`r2'to`rad'km"
    }
    cap gen cons = 1

    if $runGPS == 1 {
      iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=weight], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    }
    if $runGPS == 0 {
      ivreg2 `v' i.ent_type `vblvars' (`endregs' = `exregs') [aweight=weight], cluster(sublocation_code)
    }

    local ATEstring_total = "0"
    local ATEstring_spillover = "0"


    if "`v'" == "ent_profitmargin2_wins" {
      ** Here, we want to get the effect on the profit margin for the average enterprise **
      sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 2)
      local ATEstring_total = "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill"

      sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 1)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + "*`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill"

      sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 3)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + "*`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill"


      foreach vrb of local amount_list  {
        sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 2)
        local ATEstring_total = "`ATEstring_total'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"
        sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 2)
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"

        sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 1)
        local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

        sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 1)
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

        sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 3)
        local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"

        sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 3)
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"
      }
    }
    // close revenue-weighted loops, start non-revenue weighted loop
    else {
      sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 2)
      local ATEstring_total = "`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill * `n_ent_from_hh_treatall' / `n_hh_treatall'"

      sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 1)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

      if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
      sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 3)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill * `n_ent_ownfarm_treatall' / `n_hh_treatall'"
    }

    foreach vrb of local amount_list {
      sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 2)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_treatall' / `n_hh_treatall'"

      sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 2)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_control' / `n_hh_controlall'"

      sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 1)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

      sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 1)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_control' / `n_hh_controlall'"

      if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
      sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 3)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_treatall' / `n_hh_treatall'"

      sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 3)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_control' / `n_hh_controlall'"
    }
  }
}
// end non-revenue weighted

** these are for all enterprise-level outcomes **
disp "`ATEstring_total'"
lincom "`ATEstring_total'"
loc ATE_tot = `r(estimate)'
loc SE_tot = `r(se)'

loc rec_ci95lo = `ATE_tot' - 1.96 * `SE_tot'
loc rec_ci95hi = `ATE_tot' + 1.96 * `SE_tot'

** post main results for treatment villages
post bic_reps ("`v'") ("ent_t") (0) (0) (`r') (`ATE_tot') (`SE_tot') (`rec_ci95lo') (`rec_ci95hi')


disp "`ATEstring_spillover'"
lincom "`ATEstring_spillover'", level(95)
loc ATE_spill = `r(estimate)'
loc SE_spill = `r(se)'

loc nonrec_ci95lo = `ATE_spill' - 1.96 * `SE_spill'
loc nonrec_ci95hi = `ATE_spill' + 1.96 * `SE_spill'

** post main results for treatment villages
post bic_reps ("`v'") ("ent_c") (0) (0) (`r') (`ATE_spill') (`SE_spill') (`nonrec_ci95lo') (`nonrec_ci95hi')


macro drop r r2

** keeping only variables that are needed
keep `panvar' `timvar' *`v'* *weight* treat pp_actamt_* share_* ent_type hi_sat

tempfile fullsample
save `fullsample'

di "End main estimates - enterprises"

}
// ending enterprises -- main table

***** CASE C: VILLAGE-LEVEL ENTERPRISES *****
if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {

  gen run_id = _n
  gen date = run_id

  ** calculate optimal radii
  calculate_optimal_radii phh_`v' [aweight=n_hh], vill blvars("`blvars'")

  local r = optr
  local r2 = `r'- 2
  local rec_r_full = `r'

  di "full r for `v' for recipients is `r_full'"

  cap gen cons = 1

  local endregs = "pp_actamt_ownvill"
  local exregs = "treat"
  local amount_list = ""

  forval rad = 2(2)`r' {
    local r2 = `r' - 2
    local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
    local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
    local amount_list "`amount_list' pp_actamt_ov_`r2'to`rad'km"
  }


  if $runGPS == 1 {
    iv_spatial_HAC phh_`v' cons `blvars' [aweight=n_hh], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  }
  if $runGPS == 0 {
    ivreg phh_`v' `blvars' (`endregs' = `exregs') [aweight=n_hh], cluster(sublocation_code)
  }


  ** Get mean total effect in treatment villages **
  sum pp_actamt_ownvill [weight=n_hh] if treat == 1
  local ATEstring_tot = "`r(mean)'" + "*pp_actamt_ownvill"
  local ATEstring_spillover = "0"

  foreach vrb of local amount_list {
    sum `vrb' [aweight=n_hh] if treat == 1
    local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"

    sum `vrb' [aweight=n_hh] if treat == 0
    local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*" + "`vrb'"
  }

  disp "`ATEstring_tot'"
  lincom "`ATEstring_tot'", level(95)
  loc ATE_tot = `r(estimate)'
  loc SE_tot = `r(se)'

  loc rec_ci95lo = `ATE_tot' - 1.96 * `SE_tot'
  loc rec_ci95hi = `ATE_tot' + 1.96 * `SE_tot'


  ** posting main treat results to rep 0
  post bic_reps ("`v'") ("ent_t") (0) (0) (`rec_r_full') (`ATE_tot') (`SE_tot') (`rec_ci95lo') (`rec_ci95hi')

  disp "`ATEstring_spillover'"
  lincom "`ATEstring_spillover'", level(95)

  local ATE_spill = `r(estimate)'
  local SE_spill = `r(se)'

  loc nonrec_ci95lo = `ATE_spill' - 1.96 * `SE_spill'
  loc nonrec_ci95hi = `ATE_spill' + 1.96 * `SE_spill'

  ** posting main control results to rep 0
  post bic_reps ("`v'") ("ent_c") (0) (0) (`rec_r_full') (`ATE_spill') (`SE_spill') (`nonrec_ci95lo') (`nonrec_ci95hi')

  macro drop r r2

  ** keeping only needed variables **
  keep village_code *`v'* treat hi_sat pp_actamt_* share_* n_hh

  tempfile fullsample
  save `fullsample'


}
// ending village-level enterprises -- main table


/******************************************************/
/*      PART B: BIC SPLIT SAMPLE APPLICATION          */
/******************************************************/

di "Starting BIC reps"

forvalues q = 1/`reps' {

  use `fullsample', clear



  *** DETERMINING SPLITS ***

  isid `panvar'
  sort `panvar', stable

  gen rand = uniform()
  gen splitsample = 1

  *** CASE A: HOUSEHOLDS ***
  * split sample into halfs by eligibility and treatment status
  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
    * eligible, treat
    summ rand if eligible == 1 & treat == 1, d
    replace splitsample = 2 if rand <= `r(p50)' & eligible == 1 & treat == 1
    * eligible, control
    summ rand if eligible == 1 & treat == 0, d
    replace splitsample = 2 if rand <= `r(p50)' & eligible == 1 & treat == 0
    * ineligible, treat
    summ rand if eligible == 0 & treat == 1, d
    replace splitsample = 2 if rand <= `r(p50)' & eligible == 0 & treat == 1
    * ineligible, control
    summ rand if eligible == 0 & treat == 0, d
    replace splitsample = 2 if rand <= `r(p50)' & eligible == 0 & treat == 0

    tab splitsample
    tab splitsample treat if eligible == 1
    tab splitsample treat if eligible == 0
  }
  ***  CASES B & C: Enterprise & Village-level ***
  di "`source'"

  if inlist("`source'", "$da/GE_Enterprise_ECMA.dta", "$da/GE_VillageLevel_ECMA.dta") {
    * treated village
    summ rand if treat == 1, d
    replace splitsample = 2 if rand <= `r(p50)' & treat == 1

    * control village
    summ rand if treat == 0, d
    replace splitsample = 2 if rand <= `r(p50)' & treat == 0

    tab splitsample
  }

di "check 2"

  *******************************************
  *   LOOPTING THROUGH SPLIT SAMPLES        *
  *******************************************
  forval i = 1 / 2 {
    assert splitsample != .

    di "Running split 1"

    cap drop trainingsample
    gen trainingsample = (splitsample == `i') // splitsample takes on values of 1 and 2 -- first time through, 1/2 in training, second time through, other 1/2

    *           case A: Households            *
    *******************************************
    if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {

      ** RECIPIENT HOUSEHOLDS TOTAL EFFECT **
      ** for consumption, use overall consumption
      if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
        calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if sample == 1 & trainingsample == 1, elig // no bl vars
      }
      ** for assets, use total assets
      else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
        calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if sample == 1 & trainingsample == 1, elig blvars("`blvars'") // no bl vars
      }
      ** for hours or salary by ag/non-ag, use overall
      else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
        local vrb = subinstr("`v'","_agri","",.)
        local vrb = subinstr("`v'","_nag","",.)
        calculate_optimal_radii `vrb' [aweight=weight] if sample == 1 & trainingsample == 1, elig // no baseline vars for individual obs
      }
      ** for all others -- use variable
      else {
        calculate_optimal_radii `v' [aweight=weight] if sample == 1 & trainingsample == 1, elig blvars("`blvars'")
      }

      local r = r(r_max)
      local r2 = `r' - 2


      * we only need point estimate, so we do not need to run the full spatial HAC command
      local endregs "pp_actamt_ownvill"
      local exregs "treat"


      forval rad = 2(2)`r' {
        local r2 = `rad' - 2
        local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
        local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
      }

      qui ivreg2 `v' `blvars' (`endregs' = `exregs') [aweight=weight] if sample == 1 & trainingsample == 0

      ** Get mean total effect on treated eligibles **
      local ATEstring_tot = "0"
      foreach vrb of local endregs {
        qui sum `vrb' [aweight=weight] if (sample == 1 & treat == 1 & trainingsample == 0)
        local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
      }

      disp "`ATEstring_tot'"
      lincom "`ATEstring_tot'"

      ** posting results for recipients
      post bic_reps ("`v'") ("recipient") (`q') (`i') (`r') (`r(estimate)') (`r(se)') (.) (.)

      *      NON-RECIPIENT HOUSEHOLDS                 *
      *************************************************

      ** for consumption, use overall consumption
      if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
        calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if (eligible == 0 | treat == 0) & trainingsample == 1, hhnonrec // no bl vars
      }
      ** for assets, use total assets
      else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
        calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if  (eligible == 0 | treat == 0) & trainingsample == 1, hhnonrec  blvars("`blvars_untreat'")
      }
      ** for hours or salary by ag/non-ag, use overall
      else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
        local vrb = subinstr("`v'","_agri","",.)
        local vrb = subinstr("`v'","_nag","",.)
        calculate_optimal_radii `vrb' [aweight=weight] if (eligible == 0 | treat == 0) & trainingsample == 1, hhnonrec  // no baseline vars for individual obs
      }
      ** for all others -- use variable
      else {
        calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0) & trainingsample == 1, hhnonrec  blvars("`blvars_untreat'")
      }

      local r = r(r_max)
      local r2 = `r' - 2

      * we only need point estimate, so we do not need to run the full spatial HAC command
      local endregs = ""
      local exregs = ""
      local amount_list = ""

      forval rad = 2(2)`r' {
        local r2 = `rad' - 2

        cap drop pp_actamt_`r2'to`rad'km_eligible
        cap drop pp_actamt_`r2'to`rad'km_ineligible
        cap drop share_ge_elig_treat_`r2'to`rad'km_el
        cap drop share_ge_elig_treat_`r2'to`rad'km_in

        gen pp_actamt_`r2'to`rad'km_eligible = pp_actamt_`r2'to`rad'km * eligible
        gen pp_actamt_`r2'to`rad'km_ineligible = pp_actamt_`r2'to`rad'km * ineligible

        gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
        gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible

        local endregs = "`endregs'" + " pp_actamt_`r2'to`rad'km_eligible" + " pp_actamt_`r2'to`rad'km_ineligible"
        local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`rad'km_el"  + " share_ge_elig_treat_`r2'to`rad'km_in"

        local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
      }

      qui ivreg2 `v' `blvars' (`endregs' = `exregs') [aweight=weight] if (eligible == 0 | treat == 0) & trainingsample == 0
      loc firststage_p `e(idp)'


      ** Get mean total spillover effect on eligibles in control villages and ineligibles **
      sum weight if (eligible == 1 & treat == 0) & trainingsample == 0
      local mean1 = r(sum)
      sum weight if (eligible == 0) & trainingsample == 0
      local mean2 = r(sum)

      local eligcontrolweight = `mean1' / (`mean1' + `mean2')
      local ineligweight = `mean2' / (`mean1' + `mean2')

      local ATEstring_spillover = "0"
      foreach vrb of local amount_list {
        sum `vrb' [weight=weight] if (eligible == 1 & treat == 0) & trainingsample == 0
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`eligcontrolweight'" + "*`r(mean)'" + "*`vrb'_eligible"

        sum `vrb' [aweight=weight] if eligible == 0 & trainingsample == 0
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ineligweight'" + "*`r(mean)'" + "*`vrb'_ineligible"
      }

      disp "`ATEstring_spillover'"
      lincom "`ATEstring_spillover'"

      * posting for non-recipients
      post bic_reps ("`v'") ("nonrecipient") (`q') (`i') (`r') (`r(estimate)') (`r(se)') (.) (.)

    }
    // end household condition

    *** Case B: Enterprises ***
    if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
      *          Treated Villages            *
      **************************************************
      calculate_optimal_radii `v' [aweight=weight] if trainingsample == 1, ent blvars("`vblvars'")

      local r = r(r_max)

      * we only need point estimate, so we do not need to run the full spatial HAC command
      local endregs = "c.pp_actamt_ownvill#ent_type"
      local exregs = "treat#ent_type"
      local amount_list = ""

      forval rad = 2(2)`r' {
        local r2 = `rad' - 2
        local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`rad'km#ent_type"
        local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`rad'km#ent_type"
        local amount_list = "`amount_list' pp_actamt_ov_`r2'to`rad'km"
      }

      qui ivreg2 `v' i.ent_type `vblvars' (`endregs' = `exregs') [aweight=weight] if trainingsample == 0


      ** recalculating weights for split sample
      if inlist("`v'", "ent_profitmargin2_wins") {
        sum entweight_rev_EL if (ent_type == 2) & trainingsample == 0
        local mean1 = r(sum)
        sum entweight_rev_EL if (ent_type == 1) & trainingsample == 0
        local mean2 = r(sum)
        sum entweight_rev_EL if (ent_type == 3) & trainingsample == 0
        local mean3 = r(sum)

        local withinhhweight = `mean1' / (`mean1' + `mean2' + `mean3')
        local outsidehhweight = `mean2' / (`mean1' + `mean2' + `mean3')
        local ownfarmweight = `mean3' / (`mean1' + `mean2' + `mean3')

        disp "`withinhhweight'"
        disp "`outsidehhweight'"
        disp "`ownfarmweight'"

        ** Get mean total effect on treated eligibles **
        ** Here, we want to get the effect on the profit margin for the average enterprise **
        sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 2) & trainingsample == 0
        local ATEstring_total = "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill"

        sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 1) & trainingsample == 0
        local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + "*`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill"

        sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 3) & trainingsample == 0
        local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + "*`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill"

        local ATEstring_spillover = "0"
        foreach vrb of local amount_list {
          sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 2) & trainingsample == 0
          local ATEstring_total = "`ATEstring_total'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"
          sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 2) & trainingsample == 0
          local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"

          sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 1) & trainingsample == 0
          local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

          sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 1) & trainingsample == 0
          local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

          sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 3) & trainingsample == 0
          local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"

          sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 3) & trainingsample == 0
          local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"
        }
      }
      // end ent profit margin loop, start all other enterprise outcomes
      else{

        ** recalculating for non-training sample**
        sum entweight_EL if ent_type == 2 & treat == 1 & trainingsample == 0
        local n_ent_from_hh_treatall = r(sum)
        sum entweight_EL if ent_type == 2 & treat == 0 & trainingsample == 0
        local n_ent_from_hh_control = r(sum)
        sum entweight_EL if ent_type == 2 & hi_sat == 0 & treat == 0 & trainingsample == 0
        local n_ent_from_hh_lowsatcontrol = r(sum)
        sum entweight_EL if ent_type == 2 & trainingsample == 0
        local n_ent_from_hh_tot = r(sum)

        sum entweight_EL if ent_type == 1 & treat == 1 & trainingsample == 0
        local n_ent_outside_hh_treatall = r(sum)
        sum entweight_EL if ent_type == 1 & treat == 0 & trainingsample == 0
        local n_ent_outside_hh_control = r(sum)
        sum entweight_EL if ent_type == 1 & hi_sat == 0 & treat == 0 & trainingsample == 0
        local n_ent_outside_hh_lowsatcontrol = r(sum)
        sum entweight_EL if ent_type == 1
        local n_ent_outside_hh_tot = r(sum)

        sum entweight_EL if ent_type == 3 & treat == 1 & trainingsample == 0
        local n_ent_ownfarm_treatall = r(sum)
        sum entweight_EL if ent_type == 3 & treat == 0 & trainingsample == 0
        local n_ent_ownfarm_control = r(sum)
        sum entweight_EL if ent_type == 3 & hi_sat == 0 & treat == 0 & trainingsample == 0
        local n_ent_ownfarm_lowsatcontrol = r(sum)
        sum entweight_EL if ent_type == 3 & trainingsample == 0
        local n_ent_ownfarm_tot = r(sum)

        ** Get mean total effect on treated eligibles **
        ** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
        sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 2) & trainingsample == 0
        local ATEstring_total = "`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill * `n_ent_from_hh_treatall' / `n_hh_treatall'"

        sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 1) & trainingsample == 0
        local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

        if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
        sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 3) & trainingsample == 0
        local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill * `n_ent_ownfarm_treatall' / `n_hh_treatall'"
      }

      local ATEstring_spillover = "0"
      foreach vrb of local amount_list {
        sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 2) & trainingsample == 0
        local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_treatall' / `n_hh_treatall'"

        sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 2) & trainingsample == 0
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_control' / `n_hh_controlall'"

        sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 1) & trainingsample == 0
        local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

        sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 1) & trainingsample == 0
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_control' / `n_hh_controlall'"

        if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
        sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 3) & trainingsample == 0
        local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_treatall' / `n_hh_treatall'"

        sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 3) & trainingsample == 0
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_control' / `n_hh_controlall'"
      }
    }
  }
  // end weight re-calculation

  **treatment villages
  disp "`ATEstring_total'"
  lincom "`ATEstring_total'"

  post bic_reps ("`v'") ("ent_t") (`q') (`i') (`r') (`r(estimate)') (`r(se)') (.) (.)


  disp "`ATEstring_spillover'"
  lincom "`ATEstring_spillover'"


  post bic_reps ("`v'") ("ent_c") (`q') (`i') (`r') (`r(estimate)') (`r(se)') (.) (.)


}
// end enterprise outcomes

*** Case C: Village-level enterprises ***
if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
  *          Treated Villages            *
  **************************************************
  calculate_optimal_radii phh_`v' [aweight=n_hh] if trainingsample == 1, vill blvars("`blvars'")

  local r = optr
  local r2 = `r'- 2


  local endregs = "pp_actamt_ownvill"
  local exregs = "treat"
  local amount_list = ""

  forval rad = 2(2)`r' {
    local r2 = `rad' - 2

    local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
    local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
    local amount_list "`amount_list' pp_actamt_ov_`r2'to`rad'km"
  }

  ivreg2 phh_`v' (`endregs' = `exregs') `blvars' if trainingsample==0

  ** Get mean total effect in treatment villages **
  sum pp_actamt_ownvill [weight=n_hh] if treat == 1 & trainingsample == 0
  local ATEstring_tot = "`r(mean)'" + "*pp_actamt_ownvill"
  local ATEstring_spillover = "0"

  foreach vrb of local amount_list {
    sum `vrb' [aweight=n_hh] if treat == 1 & trainingsample == 0
    local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"

    sum `vrb' [aweight=n_hh] if treat == 0  & trainingsample == 0
    local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*" + "`vrb'"
  }

  **treatment villages
  disp "`ATEstring_tot'"
  lincom "`ATEstring_tot'"

  post bic_reps ("`v'") ("ent_t") (`q') (`i') (`r') (`r(estimate)') (`r(se)') (.) (.)


  disp "`ATEstring_spillover'"
  lincom "`ATEstring_spillover'"

  * results for control villages for rep q, split i
  post bic_reps ("`v'") ("ent_c") (`q') (`i') (`r') (`r(estimate)') (`r(se)') (.) (.)

}
// end village-level

}
// end split sample loop
}
// end rep loop


** looping variables for tex table **
local thisvarlabel: variable label `v'
local varlabels `"`varlabels' "`thisvarlabel'" " " " " "'


}
// end of outcome loop

postclose bic_reps

/**********************************************************************/
/*        END OF BIC SPLIT-SAMPLE REPS -- ASSEMBLING TABLE            */
/**********************************************************************/

use `postfile', clear

* resetting these to loop through for the rest of the table
local varcount = 1
local count = 1
local countse = `count'+1
local countspace = `count' + 2

local statnames ""

// averaging split estimates within reps
bys outcome est_type rep: egen mean_est = mean(estimate) if rep > 0 & ~mi(rep)

if `enterprise' == 1 {
  local type_list "ent_t ent_c"
}
else {
  local type_list "recipient nonrecipient"
}

foreach v of local outcomes {
  loc colnum = 1

  foreach type of local type_list {
  ** column 1: original estimate in rep 0
  summ estimate if outcome == "`v'" & rep == 0 & est_type == "`type'"
  local mainest = r(mean)
  summ se if outcome == "`v'" & rep == 0 & est_type == "`type'"
  local se = r(mean)

  pstar, b(`mainest') se(`se')
  estadd local thisstat`count' = "`r(bstar)'": col`colnum'
  estadd local thisstat`countse' = "`r(sestar)'": col`colnum'

  loc ++colnum

  ** Column 2: original radii estimate **
  summ radii if outcome == "`v'" & rep == 0 & est_type == "`type'"
  local main_r = r(mean)
  estadd local thisstat`count' = "`main_r'km": col`colnum'

  loc ++colnum

  ** column 3: share in 95% CI **
  // setting upper and lower CIs as locals
  summ lower_ci if outcome == "`v'" & rep == 0 & est_type == "`type'"
  local lower_ci = r(mean)
  summ upper_ci if outcome == "`v'" & rep == 0 & est_type == "`type'"
  local upper_ci = r(mean)

  gen rec_within = (mean_est > `lower_ci' & mean_est < `upper_ci') if rep > 0 & split == 1 & outcome == "`v'" & est_type == "`type'" // value same for both splits
  summ rec_within if split == 1 & outcome == "`v'" & est_type == "`type'"
  loc share_within_ci = string(r(mean)*100, "%4.0f")
  estadd local thisstat`count' = "`share_within_ci'\%": col`colnum'

  loc ++colnum

  ** column 4: share with same radii **
  gen same_radii = (radii == `main_r') if rep > 0 & split == 1 & outcome == "`v'" & est_type == "`type'"
  summ same_radii if rep > 0 & split == 1 & outcome == "`v'" & est_type == "`type'"
  loc share_samer = string(r(mean)*100, "%4.0f")
  estadd local thisstat`count' = "`share_samer'\%": col`colnum'

  loc ++colnum

  drop rec_within same_radii
  }



local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countspace'"

local count = `count' + 3
local countse = `count' + 1
local countspace = `count' + 2
local ++varcount
}


if `enterprise'==1{
loc mtitle `""\shortstack{Total Effect \\ (IV)}"  "\shortstack{Share in \\ 95\% CI}" "'
** dropping column 2 **
loc prehead "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{6}{S}} \toprule & \multicolumn{2}{c}{Treatment Villages} & \multicolumn{2}{c}{Control Villages} & \multicolumn{2}{c}{Radii Selected} \\ \cmidrule(lr){2-3} \cmidrule(lr){4-5} \cmidrule(lr){6-7}"
loc postfoot "\bottomrule \end{tabular}"

di "Exporting tex file"
esttab col1 col2 col3 col4 col5 col6 `using', cells(none) booktabs nonotes compress replace ///
mtitle(`mtitle' `mtitle' "\shortstack{Main \\ Estimate}" "\shortstack{Share selecting \\ same radius}") ///
stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot') ///
//mgroups("Main Estimate" "`reps' Split Sets" "Main Estimate" "`reps' Split Sets", pattern(1 0 1 0 1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))
}


else{

** Household Table **
loc mtitle `""\shortstack{Total Effect \\ (IV)}" "\shortstack{Selected \\ Radius}" "\shortstack{Share in \\ 95\% CI}" "\shortstack{Share selecting \\ same radius}""'

loc prehead "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{8}{S}} \toprule & \multicolumn{4}{c}{Recipient Households} & \multicolumn{4}{c}{Non-Recipient Households} \\ \cmidrule(lr){2-5} \cmidrule(lr){6-9}"
loc postfoot "\bottomrule \end{tabular}"

if $runGPS == 0 {
  local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
}


di "Exporting tex file"
esttab col1 col2 col3 col4 col5 col6 col7 col8 `using', cells(none) booktabs nonotes compress replace ///
mtitle(`mtitle' `mtitle') ///
stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot') ///
mgroups("Main Estimate" "`reps' Split Sets" "Main Estimate" "`reps' Split Sets", pattern(1 0 1 0 1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))
}

end
