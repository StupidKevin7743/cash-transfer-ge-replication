/*
 * Filename: Inequality_ByVillage_MainTables.do
 * Description: This do file constructs weighted gini coefficients (0-100 scale) based on consumption, income and assets by village, and runs the spatial/total effects specification.
 *              It also does extra conterfactual checks w/ counterfactual gini coefficients and hypothesis testing, assuming no spillovers and MPS = 0.1, Return = 0.2, and MPC = 0.4.
 */

 * Preliminaries
 return clear
 capture project, doinfo
 if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
 else {  // running directly
 	if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
 	do "${ge_dir}/do/set_environment.do"

}

** defining globals **
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"

project, original($dir/do/global_runGPS.do)
include "$dir/do/global_runGPS.do"

** ado files **

cap log close
log using "$dl/inequality_maintable_`c(current_date)'.txt", replace text


/** looping through values of counterfactuals **/
/* note that we still use local names for mpc and mps, but not direct analogue */

set seed 23456
set sortseed 23456


project, original("$da/GE_HHLevel_ECMA.dta") preserve // currently original to this pipeline

*** DEFINING PROGRAM TO RUN COUNTERFACTUAL EXERCISE ***
/*** Gini counterfactuals: expenditure and assets ***/
** impute counterfactual income distribution from control low sat villages for expenditure, from baseline values for assets **


cap program drop gini_counterfactual
program define gini_counterfactual
  syntax [, mpc(real 0.6) mps(real 0.4)]


  use "$da/GE_HHLevel_ECMA.dta", clear

  * drop any pre-existing counterfactual values
  cap drop p2_consumption_wins_PPP1

  ** impute counterfactual consumption distribution from control low sat villages **
  gen p2_consumption_wins_PPP1=p2_consumption_wins_PPP if treat == 0 & hi_sat == 0
  sum hhid p2_consumption_wins_PPP1 p2_consumption_wins_PPP if treat==0&hi_sat==0 // 2 missings in non imputed data

  ** draw randomly from low-sat control distribution **
  ** randomly re-draw entire villages **

  preserve
  keep village_code treat hi_sat ///
  pop_hh p_total* p_elig_* p_ge_* share_* actamt_* pp_actamt_* cum_*
  bys village_code: drop if _n > 1
  tempfile treatvars
  save `treatvars'
  restore

  preserve

  keep hhid_key village_code eligible treat hi_sat hhweight_EL survey_mth p2_consumption_wins_PPP1

  bys village_code (hhid_key): drop if _n > 1 & (treat == 1 | hi_sat == 1)
  replace survey_mth = . if (treat == 1 | hi_sat == 1)
  replace eligible = . if (treat == 1 | hi_sat == 1)
  replace hhweight_EL = . if (treat == 1 | hi_sat == 1)

  gen sampvil = treat == 0 & hi_sat == 0
  drop treat hi_sat
  levelsof village_code if sampvil == 0
  foreach vil in `r(levels)' {
  	gen a = runiform() if sampvil
  	bys village_code: egen b = min(a)
  	sort b a
  	gen c = village_code != village_code[_n-1]

  	replace c = sum(c)
  	expand 2 if c == 1, gen(dupl)
  	replace village_code = `vil' if dupl == 1
  	replace sampvil = 0 if dupl == 1

  	drop dupl a b c
  }

  drop if sampvil == 1
  drop if sampvil == 0 & eligible == .
  merge m:1 village_code using `treatvars'
  drop if _merge == 2
  tempfile impdata
  save `impdata'
  restore

  append using `impdata'



  ** consumption **
  sum p2_consumption_wins_PPP1 if treat==0 & hi_sat==0
  sum p2_consumption_wins_PPP1 if treat==1 | hi_sat==1
  sum p2_consumption_wins_PPP1 p2_consumption_wins_PPP if treat==0 & hi_sat==0
  replace p2_consumption_wins_PPP1 = p2_consumption_wins_PPP1+$trans_amt*`mpc' if treat==1 & eligible==1
  sum p2_consumption_wins_PPP1 p2_consumption_wins_PPP if treat==0&hi_sat==0

  bys treat hi_sat eligible: sum p2_consumption_wins_PPP1 p2_consumption_wins_PPP

  ** construct counterfactual assets distribution from baseline assets distribution **
  gen p1_assets_wins_PPP_BL2=p1_assets_wins_PPP_BL
  replace p1_assets_wins_PPP_BL2= p1_assets_wins_PPP_BL2+$trans_amt*`mps' if treat==1&eligible==1


  ** recode negatives->zeros for meaningful Gini results **
  // counting number less than zero in non-imputed data
  count if p1_assets_wins_PPP_BL < 0
  count if p2_consumption_wins_PPP < 0 & treat == 0 & hi_sat == 0

  local outcomes_c p2_consumption_wins_PPP1 p1_assets_wins_PPP_BL p1_assets_wins_PPP_BL2
  foreach var in `outcomes_c'{
      di "`var'"
      replace `var' =0 if `var'<0
  	gen gini_`var'=.

  }
  //117 real changes made for assets; 270 for income


  ** construct weighted Gini for assets - baseline **
  levelsof village_code
  foreach lev in `r(levels)'  {
        ** Assets **
  		qui ineqdec0 p1_assets_wins_PPP_BL [aw=hhweight_EL] if village_code==`lev'
  		replace gini_p1_assets_wins_PPP_BL=r(gini) if village_code==`lev'
  }

  ** construct weighted Ginis - counterfactual **
  levelsof village_code
  foreach lev in `r(levels)'  {
        ** Assets **
  		qui ineqdec0 p1_assets_wins_PPP_BL2 [aw=hhweight_EL] if village_code==`lev'
  		replace gini_p1_assets_wins_PPP_BL2=r(gini) if village_code==`lev'

          ** expenditure **
  		qui ineqdec0 p2_consumption_wins_PPP1 [aw=hhweight_EL] if village_code==`lev'
  		replace gini_p2_consumption_wins_PPP1=r(gini) if village_code==`lev'
  }


  /*** endline Gini wins weighted: cons, inc, assets ***/
  gen gini_cons_wins_weighted=.
  gen gini_inc_wins_weighted=.
  gen gini_asset_wins_weighted=.

  replace p1_assets_wins_PPP =0 if p1_assets_wins_PPP<0
  //131 negatives, mean -519, s.d. 1249

  levelsof village_code
  foreach lev in `r(levels)'  {
          ** expenditure **
 		qui ineqdec0 p2_consumption_wins_PPP [aw=hhweight_EL] if village_code==`lev'
  		replace gini_cons_wins_weighted=r(gini) if village_code==`lev'

  		** Assets **
  		qui ineqdec0 p1_assets_wins_PPP [aw=hhweight_EL] if village_code==`lev'
  		replace gini_asset_wins_weighted=r(gini) if village_code==`lev'
  }

  ** from hh data to village level data **
  sort village_code hhid
  egen gini_unique = tag(village_code)
  keep if gini_unique==1

  //creating 3 new variables for hypothesis testing (actual gini vs counterfactual gini)
  gen gini_cons_diff = gini_cons_wins_weighted - gini_p2_consumption_wins_PPP1
  gen gini_assets_diff = gini_asset_wins_weighted - gini_p1_assets_wins_PPP_BL2
  save "$dt/HH_SpatialData_HHLevel_FINAL_Gini_temp.dta", replace

  use "$da/GE_VillageLevel_ECMA.dta", clear
  merge 1:1 village_code using "$dt/HH_SpatialData_HHLevel_FINAL_Gini_temp.dta", keepusing(gini*)
  drop _merge
  
  save "$dt/Vill_SpatialData_FINAL_Gini.dta", replace


  ** transform Gini coefficients from 0-1 to 0-100 & rename counterfactual Ginis **
  use "$dt/Vill_SpatialData_FINAL_Gini.dta", clear
  local outcomes_naming gini_cons_wins_weighted gini_p2_consumption_wins_PPP1 gini_cons_diff gini_asset_wins_weighted gini_p1_assets_wins_PPP_BL2 gini_p1_assets_wins_PPP_BL gini_assets_diff
  foreach var in `outcomes_naming'{
    replace `var'=`var'*100
  }
  rename gini_p2_consumption_wins_PPP1 gini_cons_wins_weighted_c
  rename gini_p1_assets_wins_PPP_BL2 gini_asset_wins_weighted_c
  rename gini_p1_assets_wins_PPP_BL gini_asset_wins_weighted_BL
  save "$dt/Vill_SpatialData_FINAL_Gini.dta", replace

  loc panvar = "village_code"
  loc timvar = "avgdate_vill"

  local mpc_name = substr("`mpc'", 2, .)
  local mps_name = substr("`mps'", 2, .)

  /*** tex for adding Gini counterfactuals: cons, assets ***/

  ** get total number of households by group and village **
  use "$da/GE_HHLevel_ECMA.dta", clear
  bys village_code: egen n_hh = sum(hhweight_EL)
  collapse (mean) n_hh, by(village_code)
  tempfile temphh
  save `temphh'


  local outcomes6 gini_cons_wins_weighted gini_cons_wins_weighted_c gini_cons_diff ///
    gini_asset_wins_weighted gini_asset_wins_weighted_c gini_assets_diff

  local outregopt "replace"
  local outregset "excel label(proper)"


  * setting up blank table *
  drop _all
  local ncols = 10
  local nrows = wordcount("`outcomes6'")

  *** CREATE EMPTY TABLE ***
  eststo clear
  est drop _all
  set obs `nrows'
  gen x = 1
  gen y = 1

  forvalues x = 1/`ncols' {
  	eststo col`x': reg x y
  }

  local varcount = 1
  local count = 1
  local countse = `count'+1
  local countspace = `count' + 2

  local varlabels ""
  local statnames ""
  local collabels ""

  scalar numoutcomes = 0
  foreach v in `outcomes6' {
  	scalar numoutcomes = numoutcomes + 1

  	use "$dt/Vill_SpatialData_FINAL_Gini.dta", clear
	
	if $runGPS == 1 {
		merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", nogen keep(1 3)
	}
 	
  	cap la var gini_cons_wins_weighted "\textbf{Panel A: Expenditure} & & & & \\ Gini coefficient"
  	cap la var gini_asset_wins_weighted "\textbf{Panel B: Assets} & & & & \\ Gini coefficient"
  	cap la var gini_asset_wins_weighted_c "Counterfactual Gini coefficient"
  	cap la var gini_cons_wins_weighted_c "Counterfactual Gini coefficient"
  	cap la var gini_cons_diff "P-value: effect = counterfactual effect"
  	cap la var gini_assets_diff "P-value: effect = counterfactual effect"

  	merge 1:1 village_code using `temphh'

      ** adding variable label to the table **
      local add : var label `v'
      local collabels `"`collabels' "`add'""'

  	** Col 1 Dummy regressions **
  	**************************
  	reg `v' treat hi_sat [aweight=n_hh], cluster(sublocation_code)
    outreg2 using "$dtab/coeftables/Inequality_RawCoefs.xls", `outregopt' `outregset'

    local outregopt "append"

  	** formatting for tex - column 1, indicator for treatment status **
  	if strpos("`v'", "diff") > 0 {
  	pstar treat, pnopar
  	estadd local thisstat`count' = "p = `r(pstar)'": col1
  	}
  	else{
  	pstar treat, precision(1)
  	estadd local thisstat`count' =  "`r(bstar)'": col1
  	estadd local thisstat`countse' = "`r(sestar)'": col1
  	}
  	** Col 2 & 3 Spatial regressions **
  	****************************
  	mata: optr = .,.,.,.,.,.,.,.,.,.
  	forval r = 2(2)20 {
  		local r2 = `r' - 2
  		if inlist("`v'", "gini_asset_wins_weighted", "gini_asset_wins_weighted_c", "gini_assets_diff"){
  			ivreg2 `v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) gini_asset_wins_weighted_BL [aweight=n_hh]
  		}
  		else{
  			ivreg2 `v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) [aweight=n_hh]
  		}
  		estat ic
  		mata: optr[`r'/2] = st_matrix("r(S)")[6]
  	}

  	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
  	local r = optr
  	local r2 = `r' - 2

  	cap gen cons = 1
  	if inlist("`v'", "gini_asset_wins_weighted", "gini_asset_wins_weighted_c", "gini_assets_diff"){
      if $runGPS == 1 {
        iv_spatial_HAC `v' cons gini_asset_wins_weighted_BL [aweight=n_hh], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
      if $runGPS == 0 {
        ivreg2 `v' gini_asset_wins_weighted_BL (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) [aweight=n_hh], cluster(sublocation_code)
      }
  		outreg2 using "$dtab/coeftables/Inequality_RawCoefs.xls", `outregopt' `outregset'
  	}
  	else{
      if $runGPS == 1 {
        iv_spatial_HAC `v' cons [aweight=n_hh], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
  		if $runGPS == 0 {
        ivreg2 `v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) [aweight=n_hh], cluster(sublocation_code)
      }
      outreg2 using "$dtab/coeftables/Inequality_RawCoefs.xls", `outregopt' `outregset'
  	}

  	** Get mean total effect in treatment villages **
  	sum pp_actamt_ownvill if treat == 1
  	local ATEstring_tot_t = "`r(mean)'" + "*pp_actamt_ownvill"
  	local ATEstring_tot_c = "0"

  	foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km {
  		sum `vrb' if treat == 1
  		local ATEstring_tot_t = "`ATEstring_tot_t'" + "+" + "`r(mean)'" + "*" + "`vrb'"

  		sum `vrb' if treat == 0
  		local ATEstring_tot_c = "`ATEstring_tot_c'" + "+" + "`r(mean)'" + "*" + "`vrb'"

  	}

  	** extra loops added to adjust for control village counterfactual Ginis and p-values **
      if strpos("`v'", "diff") > 0 {
  	disp "`ATEstring_tot_t'"
  	lincom "`ATEstring_tot_t'"
  	pstar, b(`r(estimate)') se(`r(se)') pnopar
  	estadd local thisstat`count' = "p = `r(pstar)'": col2

  	disp "`ATEstring_tot_c'"
  	lincom "`ATEstring_tot_c'"
  	if `count'==7 {
  	estadd local thisstat`count' = "p = $ccthisstat1": col3
  	}
  	else if `count'==16 {
  	estadd local thisstat`count' = "p = $ccthisstat10": col3
  	}
  	else {
  	estadd local thisstat`count' = "p = $ccthisstat19": col3
  	}
  	}
  	else{
  	if strpos("`v'", "d_c") > 0 {
  	disp "`ATEstring_tot_t'"
  	lincom "`ATEstring_tot_t'"
  	pstar, b(`r(estimate)') se(`r(se)') precision(1)
  	estadd local thisstat`count' = "`r(bstar)'": col2
  	estadd local thisstat`countse' = "`r(sestar)'": col2

  	disp "`ATEstring_tot_c'"
  	lincom "`ATEstring_tot_c'"
  	estadd local thisstat`count' = "0": col3
  	}
  	else{
  	disp "`ATEstring_tot_t'"
  	lincom "`ATEstring_tot_t'"
  	pstar, b(`r(estimate)') se(`r(se)') precision(1)
  	estadd local thisstat`count' = "`r(bstar)'": col2
  	estadd local thisstat`countse' = "`r(sestar)'": col2

  	disp "`ATEstring_tot_c'"
  	lincom "`ATEstring_tot_c'"
  	pstar, b(`r(estimate)') se(`r(se)') precision(1)
  	estadd local thisstat`count' = "`r(bstar)'": col3
  	estadd local thisstat`countse' = "`r(sestar)'": col3

  	disp "`ATEstring_tot_c'"
  	lincom "`ATEstring_tot_c'"
  	pstar, b(`r(estimate)') se(`r(se)') pnopar
  	global ccthisstat`count' = "`r(pstar)'"
  	}
  	}

  	** Col 4 Add mean of dependent variable **
  	****************************************
  	if strpos("`v'", "diff") ==0 {
  	sum `v' [weight=n_hh] if treat == 0 & hi_sat == 0
  	estadd local thisstat`count' = string(`r(mean)', "%9.1f") : col4
  	estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.1f") + ")": col4
  	}

  	** looping variables for tex table **
  	local thisvarlabel: variable label `v'

  	if numoutcomes == 1 {
  		local varlabels `" " "`varlabels' "`thisvarlabel'" " " " " "'
  		local statnames "thisstat`countspace' `statnames' thisstat`count' thisstat`countse' thisstat`countspace'"
  	}
  	else {
  		local varlabels `"`varlabels' "`thisvarlabel'" " " " " "'
  		local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countspace'"
  	}

  	local count = `count' + 3
  	local countse = `count' + 1
  	local countspace = `count' + 2

  	local ++varcount
  }


  ** end loop through outcomes
  di "End outcome loop"

  if $runGPS == 0 {
    local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
  }


  ** exporting tex table ***
  loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{5}{S}}\toprule"
  loc postfoot "\bottomrule\end{tabular}}"

  di "Exporting tex file"
  local name = "$dtab/TableB7_Inequality.tex"

  esttab col1 col2 col3 col4 using "`name'", cells(none) booktabs extracols(3) nonotes compress replace ///
  mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Treatment Villages}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Control Villages}}} & \\   \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ weighted mean (SD)}}") ///
  stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')
  project, creates(`name')

end
// end of program


**** RUNNING PROGRAM FOR DIFFERENT MPC AND MPS VALUES ****
gini_counterfactual, mpc(0.66) mps(0.34)


log close
