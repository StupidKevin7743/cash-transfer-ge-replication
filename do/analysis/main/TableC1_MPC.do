/*
 * Filename: create_MPC_table
 * Description: This .do file creates the final MPC table for the appendix
 * Author: Dennis Egger
 * Date created: 11 November 2020
 *
 */

/* Preliminaries */
/* do file header */
return clear
capture project, doinfo
if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
else {  // running directly
		if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
		do "${ge_dir}/do/set_environment.do"
}

* Import config - running globals
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"

project, original("$dir/do/analysis/multiplier/multiplier_setreps.do")
include "$dir/do/analysis/multiplier/multiplier_setreps.do"

// end preliminaries

* load commands
project, original("$do/programs/run_ge_build_programs.do")
include "$do/programs/run_ge_build_programs.do"

** create folders if not there **
cap mkdir "$dt/IRF_values"
cap mkdir "$dt/IRF_values/treated"
cap mkdir "$dt/IRF_values/untreated"
cap mkdir "$dt/IRF_values/treated/mpc"
cap mkdir "$dt/IRF_values/untreated/mpc"

loc plotindic = 0 // this turns on optional graphs, that show the overlap between the estimated Rarieda and GE spending responses
if `plotindic' == 1 {
	cap mkdir "$dfig/IRFs"
	cap mkdir "$dfig/IRFs/Rarieda"
}


** Rarieda data: Share of total non-durable expenditure treatment effect (over 18months) spent in the first 9 months / 3 quarters: **
global rarieda_shareeff_3q = 0.5

global rarieda_toteff_3q = 0.3
global rarieda_toteff_house_3q = 0.5

** Set import shares **
include "$dir/do/analysis/multiplier/ImportShares_globals_TablesD1_D2.do"
// this .do file calculates import shares for non-durable expenditure and assets
// it sets four globals:
// share_import_durables - share of durable purchases imported
// share_import_nondurables - share of non-durable purchases imported
// share_int_import_durables - share of intermediates in durables imported
// share_int_import_nondurables - share of intermediates in non-durables imported

** modularities **
loc reps = $bootstrap_reps

global includeBL = 0	// = 1 if we want to include baseline controls, where available
global radAlgo = 0		// = 1 if we want to select the optimal radius for each component
global fixRad = 2 		// this is a fixed maximum radius (conditional on radAlgo == 0)

project, original("$da/HH_ENT_Multiplier_Dataset_ECMA.dta")
use "$da/HH_ENT_Multiplier_Dataset_ECMA.dta", clear


** Fix average treatment amounts for each group of hh and enterprises **
************************************************************************

** Treated eligibles **
sum pac_ownvill_r [aweight=hhweight_EL] if eligible == 1 & treat == 1
global eligtreat_amt_ownvill = r(mean)

forval r = 2(2)20 {
	local r2 = `r' - 2
	sum pac_ov_`r2'to`r'km_r [aweight=hhweight_EL] if eligible == 1 & treat == 1
	global eligtreat_amt_ov_`r2'to`r'km = r(mean)
}

*****************************
** 1. Calculate actual MPC **
*****************************

scalar mpc = 0
scalar mpc_rar = 0
scalar mpc_adj = 0
scalar mpc_rar_adj = 0

***********************************
** I. Get static asset estimates **
***********************************

global outcomes_stat "totval_hhassets_h_wins_r"
** totval_hhassets_wins: Assets, excl. housing, excl. land, NOT net of lending, in KES
** totval_hhassets_h_wins: Assets, incl. housing value, excl. land value, NOT net of lending

** a. Determine the optimal radii for all outcomes **
*****************************************************
foreach v of var $outcomes_stat{
	if $radAlgo == 1 {

		** Household variables **
		*************************
		if $includeBL == 1 {
			cap desc `v'_BL M`v'_BL
			if _rc == 0 {
				local blvars "`v'_BL M`v'_BL"
				cap gen `v'_BL_e = eligible * `v'_BL
				cap gen M`v'_BL_e = eligible * M`v'_BL
				local blvars_untreat "`blvars' `v'_BL_e M`v'_BL_e"
			}
			else {
				local blvars ""
				local blvars_untreat ""
				}
		}
		else {
			local blvars ""
			local blvars_untreat ""
		}

		** i. treated households **
		mata: optr = .,.,.,.,.,.,.,.,.,.

		forval r = 2(2)20 {
			local r2 = `r' - 2
			ivreg2 `v' (pac_ownvill_r pac_ov_0to2km_r-pac_ov_`r2'to`r'km_r = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) `blvars' [aweight=hhweight_EL] if eligible == 1
			estat ic
			mata: optr[`r'/2] = st_matrix("r(S)")[6]
		}

		mata: st_numscalar("`v'_toptr", select((1::10)', (optr :== min(optr)))*2)
	}
	else {
		scalar `v'_toptr = $fixRad
	}
}

** b. Now get static estimate **
********************************
foreach v in $outcomes_stat {
	di "Loop for `v'"

	if $includeBL == 1 {
	** add baseline variables **
		cap desc `v'_BL M`v'_BL
		if _rc == 0 {
			local blvars "`v'_BL M`v'_BL"
			cap gen `v'_BL_e = eligible * `v'_BL
			cap gen M`v'_BL_e = eligible * M`v'_BL
			local blvars_untreat "`blvars' `v'_BL_e M`v'_BL_e"
		}
		else {
			local blvars ""
			local blvars_untreat ""
		}
	}
	else {
		local blvars ""
		local blvars_untreat ""
	}

	** i. treated households **
	***************************
	local rad = `v'_toptr // this is the optimal radius as determined above
	local rad2 = `rad' - 2

	ivreg2 `v' (pac_ownvill_r pac_ov_0to2km_r-pac_ov_`rad2'to`rad'km_r = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`rad2'to`rad'km) `blvars' [aweight=hhweight_EL] if eligible == 1, cluster(sublocation_code)

	gen st_`v' = e(sample)
	predict et_`v' if st_`v', residuals
	predict ht_`v' if st_`v'

	** Get mean total effect on treated eligibles **
	local ATEstring_tot = "$eligtreat_amt_ownvill" + "*pac_ownvill_r"

	forval r = 2(2)`rad' {
		local r2 = `r' - 2
		local ATEstring_tot = "`ATEstring_tot'" + "+" + "${eligtreat_amt_ov_`r2'to`r'km}" + "*" + "pac_ov_`r2'to`r'km_r"
	}

	disp "Treated households, `v': `ATEstring_tot'"
	lincom "`ATEstring_tot'"

	scalar `v'_mpc = `r(estimate)'
	scalar mpc = mpc + `r(estimate)'
	scalar mpc_rar = mpc_rar + `r(estimate)'
	scalar mpc_adj= mpc_adj + `r(estimate)'*(1-$share_import_durables)
	scalar mpc_rar_adj = mpc_rar_adj + `r(estimate)'*(1-$share_import_durables)
}


*******************************
** II. Get dynamic estimates **
*******************************

***********
** A. GE **
***********

global outcomes_dyn_ge = "nondurables_exp_wins_r"
global outcomes_income = "p3_totincome_wins_r"
** p2_exp_mult_wins: Non-durable expenditure + expenditure on home improvement/maintenance
** nondurables_exp_wins: Non-durable expenditure
** p3_totincome_wins: total income gains (for dividing)

** a. Determine the optimal radii for all outcomes **
*****************************************************
foreach v of var $outcomes_dyn_ge $outcomes_income {
	if $radAlgo == 1 {
		** Household variables **
		*************************
		if $includeBL == 1 {
			cap desc `v'_BL M`v'_BL
			if _rc == 0 {
				local blvars "`v'_BL M`v'_BL"
				cap gen `v'_BL_e = eligible * `v'_BL
				cap gen M`v'_BL_e = eligible * M`v'_BL
				local blvars_untreat "`blvars' `v'_BL_e M`v'_BL_e"
			}
			else {
				local blvars ""
				local blvars_untreat ""
				}
		}
		else {
			local blvars ""
			local blvars_untreat ""
		}

		** i. treated households **
		mata: optr = .,.,.,.,.,.,.,.,.,.

		forval r = 2(2)20 {
			local r2 = `r' - 2
			ivreg2 `v' (pac_ownvill_r pac_ov_0to2km_r-pac_ov_`r2'to`r'km_r = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) `blvars' [aweight=hhweight_EL] if eligible == 1
			estat ic
			mata: optr[`r'/2] = st_matrix("r(S)")[6]
		}

		mata: st_numscalar("`v'_toptr", select((1::10)', (optr :== min(optr)))*2)
	}
	else {
		scalar `v'_toptr = $fixRad
	}
}

** b. Now get dynamic estimate **
*********************************
foreach v of var $outcomes_dyn_ge $outcomes_income {

	if "`v'" != "p3_totincome_wins_r"  {
		scalar `v'_q1_q3 = 0
		scalar `v'_q4_q5 = 0
		scalar `v'_q4_q10 = 0
		scalar `v'_q1_q3_rar = 0
		scalar `v'_q4_q5_rar = 0
	}

	if "`v'" == "p3_totincome_wins_r" scalar `v'_mpc = 0

	** i. treated households **
	***************************
	local rad = `v'_toptr // this is the optimal radius as determined above

	if $includeBL == 1 {
		** add baseline variables **
		cap desc `v'_BL M`v'_BL
		if _rc == 0 {
			local blvars "`v'_BL M`v'_BL"
			cap gen `v'_BL_e = eligible * `v'_BL
			cap gen M`v'_BL_e = eligible * M`v'_BL
			local blvars_untreat "`blvars' `v'_BL_e M`v'_BL_e"
		}
		else {
			local blvars ""
			local blvars_untreat ""
		}
	}
	else {
		local blvars ""
		local blvars_untreat ""
	}

	** add all buffer variables **
	local endregs = "pac_ownvill_r_q1-pac_ownvill_r_q10"
	local exregs = "t_share_actamt_ownvill_r_q1-t_share_actamt_ownvill_r_q10"
	forval r = 2(2)`rad' {
		local r2 = `r' - 2

		local endregs = "`endregs'" + " pac_ov_`r2'to`r'km_r_q1-pac_ov_`r2'to`r'km_r_q10"
		local exregs = "`exregs'" + " t_share_actamt_ov_`r2'to`r'km_r_q1-t_share_actamt_ov_`r2'to`r'km_r_q10"
	}

	ivreg2 `v' (`endregs' = `exregs') ibn.quarter `blvars' [aweight=hhweight_EL] if eligible == 1, nocons

	gen st_`v' = e(sample)
	predict et_`v' if st_`v', residuals
	predict ht_`v' if st_`v'

	mata: effects = J(3,10,.)
	forval q = 1(1)10 {
		local lag1 = `q'
		local lag2 = `q' - 2

		if `q' < 3 {
			local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87)"

			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local irfstat = "`irfstat'"  + " + pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km} *(47/87)"
			}
		}

		else {
			local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87) + (pac_ownvill_r_q`lag2'*$eligtreat_amt_ownvill)*(40/87)"

			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local irfstat = "`irfstat'"  + " + (pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km})*(47/87) + (pac_ov_`r2'to`r'km_r_q`lag2'*${eligtreat_amt_ov_`r2'to`r'km})*(40/87)"
			}
		}

		lincom "`irfstat'"

		mata: effects[1,`q'] = st_numscalar("r(estimate)")
		mata: effects[2,`q'] = effects[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")
		mata: effects[3,`q'] = effects[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")

		if "`v'" != "p3_totincome_wins_r" {
			if `q' <= 3 {
				scalar `v'_q1_q3 = `v'_q1_q3 + `r(estimate)'
				scalar mpc = mpc + `r(estimate)'
				scalar mpc_adj = mpc_adj + `r(estimate)'*(1-$share_import_nondurables)
			}

			if `q' > 3 & `q' <= 5 {
				scalar `v'_q4_q10 = `v'_q4_q10 + `r(estimate)'
				scalar `v'_q4_q5 = `v'_q4_q5 + `r(estimate)'
				scalar mpc = mpc + `r(estimate)'
				scalar mpc_adj = mpc_adj + `r(estimate)'*(1-$share_import_nondurables)
				scalar mpc_rar = mpc_rar + `r(estimate)'
				scalar mpc_rar_adj = mpc_rar_adj + `r(estimate)'*(1-$share_import_nondurables)
			}

			if `q' > 5 {
				scalar `v'_q4_q10 = `v'_q4_q10 + `r(estimate)'
				scalar mpc = mpc + `r(estimate)'
				scalar mpc_adj = mpc_adj + `r(estimate)'*(1-$share_import_nondurables)
				scalar mpc_rar = mpc_rar + `r(estimate)'
				scalar mpc_rar_adj = mpc_rar_adj + `r(estimate)'*(1-$share_import_nondurables)
			}
		}

		if "`v'" == "p3_totincome_wins_r" scalar `v'_mpc = `v'_mpc + `r(estimate)'
	}

	mata: st_matrix("eff_`v'",effects)
	mat2txt, m(eff_`v') sav("$dt/IRF_values/treated/mpc/mpc_`v'_IRF_treat.txt") replace
}

****************
** B. Rarieda **
****************
preserve
use "$dr/Rarieda_Data_Temporal.dta", clear
drop if treatmentgroup == 9 // drop pure controls
tab svyd_midline svyd_endline, m
keep if svyd_midline == 1 & svyd_endline == 1

global includeBL = 0

ren cons_nondurable_house_wins_r c_nondur_house_wins_r
ren cons_nondurable_wins_r c_nondur_wins_r

** Generate at matrix for plots **
mata : at1 = J(1,10,.)
forvalues i = 1(1)10{
	mata: at1[1,`i'] = (`i'-1)*3
}
mata: st_matrix("at1", at1)


*******************************
** II. Get dynamic estimates **
*******************************
** p2_exp_mult_wins: Non-durable expenditure + expenditure on home improvement/maintenance
** nondurables_exp_wins: Non-durable expenditure

foreach v in $outcomes_dyn_ge {

	if "`v'" == "p2_exp_mult_wins_r" local vrb "c_nondur_house_wins_r"
	if "`v'" == "nondurables_exp_wins_r" local vrb "c_nondur_wins_r"

	if $includeBL == 1 {
		** add baseline variables **
		cap desc `vrb'_BL M`vrb'_BL
		if _rc == 0 {
			local blvars "`v'_BL M`v'_BL"
		}
		else {
			local blvars ""
		}
	}

	else {
		local blvars ""
	}

	** add all buffer variables **
	reg `vrb' actamt_r_q1-actamt_r_q5 ibn.quarter `blvars' if eligible == 1, nocons cluster(village)
	gen st_`vrb' = e(sample)
	predict et_`vrb' if st_`vrb', residuals
	predict ht_`vrb' if st_`vrb'

	mata: effects = J(3,10,.)

	local intstat = "0"
	forval q = 1(1)5 {
		local lag1 = `q'
		local lag2 = `q' - 2

		if `q' < 3 {
			local irfstat = "actamt_r_q`lag1'*47/87"
			local intstat = "`intstat'"  + " + actamt_r_q`lag1'*47/87"
		}

		else {
			local irfstat = "actamt_r_q`lag1'*47/87 + actamt_r_q`lag2'*40/87"
			local intstat = "`intstat'"  + " + actamt_r_q`lag1'*47/87 + actamt_r_q`lag2'*40/87"
		}

		lincom "`irfstat'"

		mata: effects[1,`q'] = st_numscalar("r(estimate)")
		mata: effects[2,`q'] = effects[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")
		mata: effects[3,`q'] = effects[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")

		if `q' <= 3 {
			scalar `v'_q1_q3_rar = `v'_q1_q3_rar + `r(estimate)'
			scalar mpc_rar = mpc_rar + `r(estimate)'
			scalar  mpc_rar_adj = mpc_rar_adj + `r(estimate)'*(1-$share_import_nondurables)
		}

		if `q' > 3 & `q' <= 5 {
			scalar `v'_q4_q5_rar = `v'_q4_q5_rar + `r(estimate)'
		}
	}

	mata: st_matrix("rar_eff_`v'",effects)

	** Plot **
	**********
	if `plotindic' == 1 {
		coefplot (matrix(rar_eff_`v'[1,.]), ci((rar_eff_`v'[2,.] rar_eff_`v'[3,.])) at(matrix(at1))), recast(line) color(navy) ciopts(recast(rarea) color(navy%25) alcolor(%0)) vertical yline(0) legend(off) scheme(tufte) ///
		/* ylabel(-0.1(0.1)0.2)*/ xlabel(0(3)18) xtitle("Months since first transfer") ytitle("Direct effect on the untreated - relative to size of transfer") title("`vrb' IRF - Untreated Households")
		graph export "$dfig/IRFs/Rarieda/`v'_rar_Treated.pdf", as(pdf) replace
	}

	** Export IRF for graph **
	mat2txt, m(rar_eff_`v') sav("$dt/IRF_values/treated/mpc/mpc_rar_`v'_IRF_treat.txt") replace
}

save "$dt/RariedaData_forbootstrap.dta", replace
restore

** Create graph to compare Rarieda with GE **
*********************************************

if `plotindic' == 1 {
	* This optional code creates a graph that shows the overlap between the IRFs from the Rarieda data, and the GE data
	foreach v in $outcomes_dyn_ge {
		coefplot (matrix(rar_eff_`v'[1,.]), ci((rar_eff_`v'[2,.] rar_eff_`v'[3,.])) label("Rarieda - Direct effect") at(matrix(at1)) recast(line) color(navy) ciopts(recast(rarea) color(navy%25) alcolor(%0))) ///
		(matrix(eff_`v'[1,.]), ci((eff_`v'[2,.] eff_`v'[3,.])) label("GE - Direct effect + Spillover") at(matrix(at1)) recast(line) color(maroon) ciopts(recast(rarea) color(maroon%25) alcolor(%0))), ///
		yline(0) scheme(tufte) legend(rows(2)) ylabel(-0.2(0.1)0.5) yscale(range(-0.1 0.2)) xlabel(0(3)27) xtitle("Months since first transfer") ytitle("Effect relative to size of transfer") name(gph2, replace)
		graph export "$dfig/IRFs/Rarieda/`v'_rar_GE_compare.pdf", as(pdf) replace
	}
}


** adjust for income **
foreach v in mpc mpc_rar mpc_adj mpc_rar_adj {
	scalar `v'_netinc = `v' / (1+p3_totincome_wins_r_mpc)
}

** Store estimates **
loc full_estimates = "mpc, mpc_rar, mpc_adj, mpc_rar_adj, mpc_netinc, mpc_rar_netinc, mpc_adj_netinc, mpc_rar_adj_netinc, p3_totincome_wins_r_mpc"

foreach v in $outcomes_stat {
	loc full_estimates = "`full_estimates', `v'_mpc"
}

foreach v in $outcomes_dyn_ge {
	loc full_estimates = "`full_estimates', `v'_q1_q3"
	loc full_estimates = "`full_estimates', `v'_q4_q10"
	loc full_estimates = "`full_estimates', `v'_q4_q5"
}

foreach v in $outcomes_dyn_ge {
	loc full_estimates = "`full_estimates', `v'_q1_q3_rar"
	loc full_estimates = "`full_estimates', `v'_q4_q5_rar"
}

matrix full_estimates = `full_estimates'
matrix list full_estimates


****************************************
** 	NOW SET UP THE WILD BOOTSTRAP 	****
****************************************
capture program drop wildboot_mpc
program define wildboot_mpc, rclass

	cap drop rand
	sort sublocation_code ent_id_universe hhid_key
	gen rand = runiform()
	bys sublocation_code (ent_id_universe hhid_key): replace rand = cond(rand[1] <= 0.5, 1, -1)

	scalar mpc = 0
	scalar mpc_adj = 0
	scalar mpc_rar = 0
	scalar mpc_rar_adj = 0

	** b. Now get static estimate **
	********************************
	foreach v of var $outcomes_stat {
		di "Loop for `v'"

		scalar `v'_mpc = 0

		if $includeBL == 1 {
		** add baseline variables **
			cap desc `v'_BL M`v'_BL
			if _rc == 0 {
				local blvars "`v'_BL M`v'_BL"
				cap gen `v'_BL_e = eligible * `v'_BL
				cap gen M`v'_BL_e = eligible * M`v'_BL
				local blvars_untreat "`blvars' `v'_BL_e M`v'_BL_e"
			}
			else {
				local blvars ""
				local blvars_untreat ""
			}
		}
		else {
			local blvars ""
			local blvars_untreat ""
		}

		** i. treated households **
		***************************
		local rad = `v'_toptr // this is the optimal radius as determined above
		local rad2 = `rad' - 2

		cap drop p_`v'
		gen p_`v' = ht_`v' + et_`v'*rand if st_`v'
		ivreg2 p_`v' (pac_ownvill_r pac_ov_0to2km_r-pac_ov_`rad2'to`rad'km_r = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`rad2'to`rad'km) `blvars' [aweight=hhweight_EL] if eligible == 1, cluster(sublocation_code)

		** Get mean total effect on treated eligibles **
		local ATEstring_tot = "$eligtreat_amt_ownvill" + "*pac_ownvill_r"

		forval r = 2(2)`rad' {
			local r2 = `r' - 2
			local ATEstring_tot = "`ATEstring_tot'" + "+" + "${eligtreat_amt_ov_`r2'to`r'km}" + "*" + "pac_ov_`r2'to`r'km_r"
		}

		disp "Treated households, `v': `ATEstring_tot'"
		lincom "`ATEstring_tot'"

		scalar `v'_mpc = `v'_mpc + `r(estimate)'
		scalar  mpc = mpc + `r(estimate)'
		scalar 	mpc_rar = mpc_rar + `r(estimate)'

		scalar  mpc_adj = mpc_adj + `r(estimate)'*(1-$share_import_durables)
		scalar 	mpc_rar_adj = mpc_rar_adj + `r(estimate)'*(1-$share_import_durables)

	}

	*******************************
	** II. Get dynamic estimates **
	*******************************
	foreach v of var $outcomes_dyn_ge $outcomes_income {

		if "`v'" != "p3_totincome_wins_r"  {
			scalar `v'_q1_q3 = 0
			scalar `v'_q4_q5 = 0
			scalar `v'_q4_q10 = 0
			scalar `v'_q1_q3_rar = 0
			scalar `v'_q4_q5_rar = 0
		}

		** Get first 3 quarters from Rarieda **
		***************************************
		if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {

		preserve
		project, original("$dr/Rarieda_Data_Temporal.dta")
		use "$dt/RariedaData_forbootstrap.dta", clear

		cap drop rand
		sort village surveyid wave
		gen rand = runiform()
		bys village (surveyid wave): replace rand = cond(rand[1] <= 0.5, 1, -1)

		if "`v'" == "p2_exp_mult_wins_r" local vrb "c_nondur_house_wins_r"
		if "`v'" == "nondurables_exp_wins_r" local vrb "c_nondur_wins_r"

		if $includeBL == 1 {
			** add baseline variables **
			cap desc `v'_BL M`v'_BL
			if _rc == 0 {
				local blvars "`v'_BL M`v'_BL"
			}
			else {
				local blvars ""
			}
		}

		else {
			local blvars ""
		}

		** Run regressions to get the direct effect **
		cap drop p_`vrb'
		gen p_`vrb' = ht_`vrb' + et_`vrb'*rand if st_`vrb'
		reg p_`vrb' actamt_r_q1-actamt_r_q5 ibn.quarter `blvars' if eligible == 1, nocons cluster(village)

		local intstat = "0"
		forval q = 1(1)5 { // only sum up to 3 quarters
			local lag1 = `q'
			local lag2 = `q' - 2

			if `q' < 3 {
				local irfstat = "actamt_r_q`lag1'*47/87"
				local intstat = "`intstat'"  + " + actamt_r_q`lag1'*47/87"
			}

			else {
				local irfstat = "actamt_r_q`lag1'*47/87 + actamt_r_q`lag2'*40/87"
				if `q' <= 3 local intstat = "`intstat'"  + " + actamt_r_q`lag1'*47/87 + actamt_r_q`lag2'*40/87"
			}

			lincom "`irfstat'"

			if `q' > 3 & `q' <= 5 {
				scalar `v'_q4_q5_rar = `v'_q4_q5_rar + `r(estimate)'
			}
		}

		** Store total consumption integral for adding later **
		disp "Treated households, `v': `intstat'"
		lincom "`intstat'"

		scalar `v'_q1_q3_rar = `v'_q1_q3_rar + `r(estimate)'
		scalar mpc_rar = mpc_rar + `r(estimate)'
		scalar 	mpc_rar_adj = mpc_rar_adj + `r(estimate)'*(1-$share_import_nondurables)
		restore
		}

		** Now add in GE data **
		************************
		local rad = `v'_toptr // this is the optimal radius as determined above

		if $includeBL == 1 {
			** add baseline variables **
			cap desc `v'_BL M`v'_BL
			if _rc == 0 {
				local blvars "`v'_BL M`v'_BL"
				cap gen `v'_BL_e = eligible * `v'_BL
				cap gen M`v'_BL_e = eligible * M`v'_BL
				local blvars_untreat "`blvars' `v'_BL_e M`v'_BL_e"
			}
			else {
				local blvars ""
				local blvars_untreat ""
			}
		}
		else {
			local blvars ""
			local blvars_untreat ""
		}

		** add all buffer variables **
		local endregs = "pac_ownvill_r_q1-pac_ownvill_r_q10"
		local exregs = "t_share_actamt_ownvill_r_q1-t_share_actamt_ownvill_r_q10"
		forval r = 2(2)`rad' {
			local r2 = `r' - 2
			local endregs = "`endregs'" + " pac_ov_`r2'to`r'km_r_q1-pac_ov_`r2'to`r'km_r_q10"
			local exregs = "`exregs'" + " t_share_actamt_ov_`r2'to`r'km_r_q1-t_share_actamt_ov_`r2'to`r'km_r_q10"
		}

		cap drop p_`v'
		gen p_`v' = ht_`v' + et_`v'*rand if st_`v'
		ivreg2 p_`v' (`endregs' = `exregs') ibn.quarter `blvars' [aweight=hhweight_EL] if eligible == 1, nocons

		forval q = 1(1)10 {
			local lag1 = `q'
			local lag2 = `q' - 2

			if `q' < 3 {
				local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87)"

				forval r = 2(2)`rad' {
					local r2 = `r' - 2
					local irfstat = "`irfstat'"  + " + pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km} *(47/87)"
				}
			}

			else {
				local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87) + (pac_ownvill_r_q`lag2'*$eligtreat_amt_ownvill)*(40/87)"

				forval r = 2(2)`rad' {
					local r2 = `r' - 2
					local irfstat = "`irfstat'"  + " + (pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km})*(47/87) + (pac_ov_`r2'to`r'km_r_q`lag2'*${eligtreat_amt_ov_`r2'to`r'km})*(40/87)"
				}
			}

			lincom "`irfstat'"

			if "`v'" != "p3_totincome_wins_r"  {
				if `q' <= 3 {
					scalar `v'_q1_q3 = `v'_q1_q3 + `r(estimate)'
					scalar mpc = mpc + `r(estimate)'
					scalar  mpc_adj = mpc_adj + `r(estimate)'*(1-$share_import_nondurables)
				}
				if `q' > 3 & `q' <= 5 {
					scalar `v'_q4_q5 = `v'_q4_q5 + `r(estimate)'
					scalar `v'_q4_q10 = `v'_q4_q10 + `r(estimate)'
					scalar mpc = mpc + `r(estimate)'
					scalar  mpc_adj = mpc_adj + `r(estimate)'*(1-$share_import_nondurables)
				}
				if `q' > 5 {
					scalar `v'_q4_q10 = `v'_q4_q10 + `r(estimate)'
					scalar mpc_rar = mpc_rar + `r(estimate)'
					scalar 	mpc_rar_adj = mpc_rar_adj + `r(estimate)'*(1-$share_import_nondurables)
				}
			}
			if "`v'" == "p3_totincome_wins_r"  scalar `v'_mpc = `r(estimate)'
		}
	}

	foreach vrb in $outcomes_stat {
		return scalar `vrb'_mpc = `vrb'_mpc
	}

	foreach vrb in $outcomes_dyn_ge {
		return scalar `vrb'_q1_q3 = `vrb'_q1_q3
		return scalar `vrb'_q4_q10 = `vrb'_q4_q10
		return scalar `vrb'_q4_q5 = `vrb'_q4_q5
		return scalar `vrb'_q1_q3_rar = `vrb'_q1_q3_rar
		return scalar `vrb'_q4_q5_rar = `vrb'_q4_q5_rar
	}

	return scalar mpc = mpc
	return scalar mpc_rar = mpc_rar

	return scalar mpc_adj = mpc_adj
	return scalar mpc_rar_adj = mpc_rar_adj

	return scalar p3_totincome_wins_r_mpc = p3_totincome_wins_r_mpc
	foreach v in mpc mpc_rar mpc_adj mpc_rar_adj {
		scalar `v'_netinc = `v' / (1 + p3_totincome_wins_r_mpc)
		return scalar `v'_netinc = `v'_netinc
	}
end

**************************************
** Now run the bootstrap simulation **
**************************************

loc simulationstring = "mpc = r(mpc) mpc_rar = r(mpc_rar) mpc_adj = r(mpc_adj) mpc_rar_adj = r(mpc_rar_adj) mpc_netinc = r(mpc_netinc) mpc_rar_netinc = r(mpc_rar_netinc) mpc_adj_netinc = r(mpc_adj_netinc) mpc_rar_adj_netinc = r(mpc_rar_adj_netinc) p3_totincome_wins_r_mpc = r(p3_totincome_wins_r_mpc)"

foreach v in $outcomes_stat {
	loc simulationstring = "`simulationstring' `v'_mpc = r(`v'_mpc)"
}

foreach v in $outcomes_dyn_ge {
	loc simulationstring = "`simulationstring' `v'_q1_q3 = r(`v'_q1_q3)"
	loc simulationstring = "`simulationstring' `v'_q4_q10 = r(`v'_q4_q10)"
	loc simulationstring = "`simulationstring' `v'_q4_q5 = r(`v'_q4_q5)"
	loc simulationstring = "`simulationstring' `v'_q1_q3_rar = r(`v'_q1_q3_rar)"
	loc simulationstring = "`simulationstring' `v'_q4_q5_rar = r(`v'_q4_q5_rar)"
}

disp "`simulationstring'"
simulate `simulationstring', reps(`reps') seed(34567): wildboot_mpc

** Output the bootstrap result **
save "$dt/IRF_values/mpc_bootstrap_rawoutput.dta", replace
project, creates("$dt/IRF_values/mpc_bootstrap_rawoutput.dta") preserve



*******************************
** NOW -- Create final table **
*******************************
loc bstatstring = "mpc mpc_rar mpc_adj mpc_rar_adj mpc_netinc mpc_rar_netinc mpc_adj_netinc mpc_rar_adj_netinc p3_totincome_wins_r_mpc"

foreach v in $outcomes_stat {
	loc bstatstring = "`bstatstring' `v'_mpc"
}

foreach v in $outcomes_dyn_ge {
	loc bstatstring = "`bstatstring' `v'_q1_q3"
	loc bstatstring = "`bstatstring' `v'_q4_q10"
	loc bstatstring = "`bstatstring' `v'_q4_q5"
}
foreach v in $outcomes_dyn_ge {
	loc bstatstring = "`bstatstring' `v'_q1_q3_rar"
	loc bstatstring = "`bstatstring' `v'_q4_q5_rar"
}

disp "`bstatstring'"
bstat `bstatstring', stat(full_estimates)


********************************
*** Test for overlapping IRFS **
********************************
log using "$dtab/../mpc_Rarieda_overlap_test.txt", replace
bstat `bstatstring', stat(full_estimates)

disp "This tests whether the IRF on recpient non-durables consumption in quarters 4 and 5 are equal for Rarieda data vs. our data"
test nondurables_exp_wins_r_q4_q5_rar = nondurables_exp_wins_r_q4_q5
log close


****************************
** Prepare table contents **
****************************

foreach v in $outcomes_dyn_ge {
	pstar `v'_q1_q3
	global GE_nondur_q1_q3_cum: disp %3.2f _b[`v'_q1_q3]
	global GE_nondur_q1_q3_cum_se = "`r(sestar)'"

	pstar `v'_q4_q10
	global GE_nondur_q4_q10_cum: disp %3.2f _b[`v'_q4_q10]
	global GE_nondur_q4_q10_cum_se = "`r(sestar)'"

	pstar `v'_q1_q3_rar
	global RAR_nondur_q1_q3_cum: disp %3.2f _b[`v'_q1_q3_rar]
	global RAR_nondur_q1_q3_cum_se = "`r(sestar)'"
}

foreach v in $outcomes_stat {
	pstar `v'_mpc
	global GE_dur_cum: disp %3.2f _b[`v'_mpc]
	global GE_dur_cum_se= "`r(sestar)'"
}

foreach v in mpc mpc_adj mpc_rar mpc_rar_adj mpc_netinc mpc_adj_netinc mpc_rar_netinc mpc_rar_adj_netinc {
	pstar `v'
	global `v': disp %3.2f _b[`v']
	global `v'_se = "`r(sestar)'"
}

** Output .tex table **
***********************
cap erase "$dtab/TableC1_MPC.tex"
texdoc init "$dtab/TableC1_MPC.tex", replace force
tex \begin{tabular}{lcccccccccc}
tex \toprule
tex & (1) & (2) & & (3) & & (4) & (5) & & (6) & (7) \\[0.3cm]
tex & \multicolumn{7}{c}{\textbf{Transfer}} & & \multicolumn{2}{c}{\textbf{Transfer + Income Gains}} \\
tex \cline{2-8} \cline{10-11} \\
tex & \multicolumn{2}{c}{\shortstack{\textbf{MPC} \\ \textbf{non-durables}}} & & \multicolumn{1}{c}{\shortstack{\textbf{MPC} \\ \textbf{durables}}} & & \multicolumn{1}{c}{\shortstack{\textbf{MPC} \\ \textbf{total}}} & \multicolumn{1}{c}{\shortstack{\textbf{MPC} \\ \textbf{local}}} & & \multicolumn{1}{c}{\shortstack{\textbf{MPC} \\ \textbf{total}}} & \multicolumn{1}{c}{\shortstack{\textbf{MPC} \\ \textbf{local}}} \\
tex & q1-q3 & q4-q10 & & & & & & & & \\ \midrule
tex \shortstack[l]{Our data only}  & $GE_nondur_q1_q3_cum & $GE_nondur_q4_q10_cum & & $GE_dur_cum & & $mpc	& $mpc_adj & & $mpc_netinc & $mpc_adj_netinc \\
tex & $GE_nondur_q1_q3_cum_se & $GE_nondur_q4_q10_cum_se & & $GE_dur_cum_se & & $mpc_se	& $mpc_adj_se & & $mpc_netinc_se & $mpc_adj_netinc_se \\[0.3cm]
tex \shortstack[l]{Rarieda data q1-3, our data q4-10}  & $RAR_nondur_q1_q3_cum & $GE_nondur_q4_q10_cum	& & $GE_dur_cum & & $mpc_rar	& $mpc_rar_adj  & & $mpc_rar_netinc & $mpc_rar_adj_netinc \\
tex & $RAR_nondur_q1_q3_cum_se & $GE_nondur_q4_q10_cum_se	& & $GE_dur_cum_se & & $mpc_rar_se	& $mpc_rar_adj_se & & $mpc_rar_netinc_se & $mpc_rar_adj_netinc_se \\[0.3cm]
tex \bottomrule
tex \end{tabular}
texdoc close
project, creates("$dtab/TableC1_MPC.tex") preserve
