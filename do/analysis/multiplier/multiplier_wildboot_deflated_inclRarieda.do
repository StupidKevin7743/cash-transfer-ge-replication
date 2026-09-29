/*
 * Filename: multiplier_wildboot_deflated_inclRarieda.do
 * Description: This do file constructs data for the multiplier that that adds Rarieda for first 3 quarters and applies the wild bootstrap to obtain standard errors
 * Author: Tilman Graff
 * Date created: 3 June 2020
 *
 */

/* Preliminaries */
/* do file header */
return clear
cap project, doinfo
disp _rc
if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
else {  // running directly
		if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
		do "${ge_dir}/do/set_environment.do"
}

* Import config - running globals
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"

// end preliminaries
set varabbrev on
clear matrix
set maxvar 32000

** create folders, in case not already generated
cap mkdir $dt/IRF_values/
cap mkdir $dt/IRF_values/untreated/
cap mkdir $dt/IRF_values/treated/
cap mkdir $dt/IRF_values/joint/

loc plotindic = 0 // This local turns on the plotting of all IRFs for the individual subcomponents of the multiplier
** Since these are not shown in the paper, they are turned off by default

if `plotindic' == 1 {
	cap mkdir $dfig/IRFs/
	cap mkdir $dfig/IRFs/HHs/
	cap mkdir $dfig/IRFs/HHs/deflated/
	cap mkdir $dfig/IRFs/ENTs/
	cap mkdir $dfig/IRFs/ENTs/deflated/
}


** Set variables to be added up **
**********************************
gl firstquarter = 1

** Set replications **
project, original("$dir/do/analysis/multiplier/multiplier_setreps.do")
include "$dir/do/analysis/multiplier/multiplier_setreps.do"

loc reps = $bootstrap_reps

** modularities **
global includeBL = 0	// = 1 if we want to include baseline controls, where available
global radAlgo = 0		// = 1 if we want to select the optimal radius for each component
global fixRad = 2 		// this is a fixed maximum radius (conditional on radAlgo == 0)

** Expenditure multiplier **
*global hhflowvar_exp p2_exp_mult_wins_r
global hhflowvar_exp nondurables_exp_wins_r
*global hhstockvar_exp totval_hhassets_wins_r
global hhstockvar_exp totval_hhassets_h_wins_r
global entflowvar_exp ent_inv_wins_r
global entstockvar_exp ent_inventory_wins_r

** Income multiplier **
global hhflowvar_inc p3_3_wageearnings_wins_r
global hhstockvar_inc
global entflowvar_inc ent_profit2_wins_r ent_rentcost_wins_r ent_totaltaxes_wins_r
global entstockvar_inc

preserve
eststo clear
est drop _all
qui set obs 10
gen x = 1
gen y = 1

forvalues x1 = 1/3 {
	qui eststo col`x1': reg x y
	qui eststo col_adj_`x1': reg x y
	}
local varcount = 1
restore

** Generate at matrix for plots **
mata : at1 = J(1,10,.)
forvalues i = 1(1)10{
	mata: at1[1,`i'] = (`i'-1)*3
}
mata: st_matrix("at1", at1)


scalar multiplier_exp = 0
scalar multiplier_inc = 0

loc full_estimates = ""

foreach type in "exp" "inc" {

	if "`full_estimates'" != "" loc full_estimates = "`full_estimates', multiplier_`type'"
	if "`full_estimates'" == "" loc full_estimates = "multiplier_`type'"


	foreach var in ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
		scalar `var'_mult = 0
		loc full_estimates = "`full_estimates', `var'_mult"
	}

}

di "`full_estimates'"


** b. Fix weights for the different groups of hh and enterprises **
*******************************************************************
project, original("$da/HH_ENT_Multiplier_Dataset_ECMA.dta")
use "$da/HH_ENT_Multiplier_Dataset_ECMA.dta", clear

** get eligible controls vs. ineligibles weight for untreated effects **
sum hhweight_EL if (eligible == 1 & treat == 0)
local mean1 = r(sum)
sum hhweight_EL if (eligible == 0)
local mean2 = r(sum)

global eligcontrolweight = `mean1' / (`mean1' + `mean2')
global ineligweight = `mean2' / (`mean1' + `mean2')


sum hhweight_EL if treat == 1
global n_hh_treatall = `r(sum)'

sum hhweight_EL if treat == 0
global n_hh_controlall = `r(sum)'

sum hhweight_EL if treat == 0 & hi_sat == 0
global n_hh_lowsatcontrol = `r(sum)'

sum hhweight_EL if eligible == 1 & treat == 1
global n_hh_treat = `r(sum)'
sum hhweight_EL if eligible == 0 | treat == 0
global n_hh_untreat = `r(sum)'
sum hhweight_EL
global n_hh_tot = `r(sum)'

** get untreated weight relative to treated **
sum hhweight_EL if eligible == 1 & treat == 1
local mean1 = `r(sum)'
sum hhweight_EL if eligible == 0 | treat == 0
local mean2 = `r(sum)'
global untreatweight = `mean2' / `mean1'
disp "`untreatweight'"

** Get number of enterprises of each group by treatment **
sum entweight_EL if ent_type == 2 & treat == 1
global n_ent_from_hh_treatall = r(sum)
sum entweight_EL if ent_type == 2 & treat == 0
global n_ent_from_hh_control = r(sum)
sum entweight_EL if ent_type == 2 & hi_sat == 0 & treat == 0
global n_ent_from_hh_lowsatcontrol = r(sum)
sum entweight_EL if ent_type == 2
global n_ent_from_hh_tot = r(sum)

sum entweight_EL if ent_type == 1 & treat == 1
global n_ent_outside_hh_treatall = r(sum)
sum entweight_EL if ent_type == 1 & treat == 0
global n_ent_outside_hh_control = r(sum)
sum entweight_EL if ent_type == 1 & hi_sat == 0 & treat == 0
global n_ent_outside_hh_lowsatcontrol = r(sum)
sum entweight_EL if ent_type == 1
global n_ent_outside_hh_tot = r(sum)

sum entweight_EL if ent_type == 3 & treat == 1
global n_ent_ownfarm_treatall = r(sum)
sum entweight_EL if ent_type == 3 & treat == 0
global n_ent_ownfarm_control = r(sum)
sum entweight_EL if ent_type == 3 & hi_sat == 0 & treat == 0
global n_ent_ownfarm_lowsatcontrol = r(sum)
sum entweight_EL if ent_type == 3
global n_ent_ownfarm_tot = r(sum)

** c. Fix average treatment amounts for each group of hh and enterprises **
***************************************************************************

** Treated eligibles **
sum pac_ownvill_r [aweight=hhweight_EL] if eligible == 1 & treat == 1
global eligtreat_amt_ownvill = r(mean)

forval r = 2(2)20 {
	local r2 = `r' - 2
	sum pac_ov_`r2'to`r'km_r [aweight=hhweight_EL] if eligible == 1 & treat == 1
	global eligtreat_amt_ov_`r2'to`r'km = r(mean)
}

** Untreated eligibles **
forval r = 2(2)20 {
	local r2 = `r' - 2
	sum pac_`r2'to`r'km_r [weight=hhweight_EL] if eligible == 1 & treat == 0
	global eligcontrol_amt_`r2'to`r'km = r(mean)
}

** Ineligibles **
forval r = 2(2)20 {
	local r2 = `r' - 2
	sum pac_`r2'to`r'km_r [weight=hhweight_EL] if eligible == 0
	global inelig_amt_`r2'to`r'km = r(mean)
}

** treat, ent_type == 2 **
sum pac_ownvill_r [aweight=entweight_EL] if (treat == 1 & ent_type == 2)
global treatent2_amt_ownvill = r(mean)

forval r = 2(2)20 {
	local r2 = `r' - 2
	sum pac_ov_`r2'to`r'km_r [aweight=entweight_EL] if (treat == 1 & ent_type == 2)
	global treatent2_amt_ov_`r2'to`r'km = r(mean)

	sum pac_ov_`r2'to`r'km_r [aweight=entweight_EL] if (treat == 0 & ent_type == 2)
	global controlent2_amt_ov_`r2'to`r'km = r(mean)
}

** treat, ent_type == 1 **
sum pac_ownvill_r [aweight=entweight_EL] if (treat == 1 & ent_type == 1)
global treatent1_amt_ownvill = r(mean)

forval r = 2(2)20 {
	local r2 = `r' - 2
	sum pac_ov_`r2'to`r'km_r [aweight=entweight_EL] if (treat == 1 & ent_type == 1)
	global treatent1_amt_ov_`r2'to`r'km = r(mean)

	sum pac_ov_`r2'to`r'km_r [aweight=entweight_EL] if (treat == 0 & ent_type == 1)
	global controlent1_amt_ov_`r2'to`r'km = r(mean)
}

** treat, ent_type == 3 **
sum pac_ownvill_r [aweight=entweight_EL] if (treat == 1 & ent_type == 3)
global treatent3_amt_ownvill = r(mean)

forval r = 2(2)20 {
	local r2 = `r' - 2
	sum pac_ov_`r2'to`r'km_r [aweight=entweight_EL] if (treat == 1 & ent_type == 3)
	global treatent3_amt_ov_`r2'to`r'km = r(mean)

	sum pac_ov_`r2'to`r'km_r [aweight=entweight_EL] if (treat == 0 & ent_type == 3)
	global controlent3_amt_ov_`r2'to`r'km = r(mean)
}



** d. Determine the optimal radii for all outcomes **
*****************************************************

foreach type in "exp" "inc"{

	if $radAlgo == 1 {

	** Household variables **
	*************************
		if "${hhstockvar_`type'} ${hhflowvar_`type'}" != " " {
			foreach v of var ${hhstockvar_`type'} ${hhflowvar_`type'} {

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

				** ii. untreated households **
				mata: optr = .,.,.,.,.,.,.,.,.,.

				local endregs = ""
				local exregs = ""
				forval r = 2(2)20 {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pac_`r2'to`r'km_r#eligible"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#eligible"
					ivreg2 `v' (`endregs' = `exregs') eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0)
					estat ic
					mata: optr[`r'/2] = st_matrix("r(S)")[6]
				}

				mata: st_numscalar("`v'_utoptr", select((1::10)', (optr :== min(optr)))*2)
			}
		}

		** Enterprise variables **
		**************************
		if "${entstockvar_`type'} ${entflowvar_`type'}" != " " {
			foreach v of var ${entstockvar_`type'} ${entflowvar_`type'} {

				if $includeBL == 1 {
					cap desc `v'_vBL M`v'_vBL
					if _rc == 0 {
						local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
					}
					else {
						local vblvars ""
					}
				}
				else {
					local vblvars ""
				}

				mata: optr = .,.,.,.,.,.,.,.,.,.

				local endregs = "c.pac_ownvill_r#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)20 {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pac_ov_`r2'to`r'km_r#ent_type"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
					ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]
					estat ic
					mata: optr[`r'/2] = st_matrix("r(S)")[6]
				}

				mata: st_numscalar("`v'_optr", select((1::10)', (optr :== min(optr)))*2)
			}
		}
	}

	else {
		if "${hhstockvar_`type'} ${hhflowvar_`type'}" != " " {
			foreach v of var ${hhstockvar_`type'} ${hhflowvar_`type'} {
				scalar `v'_toptr = $fixRad
				scalar `v'_utoptr = $fixRad
			}
		}

		if "${entstockvar_`type'} ${entflowvar_`type'}" != " " {
			foreach v of var ${entstockvar_`type'} ${entflowvar_`type'} {
				scalar `v'_optr = $fixRad
			}
		}
	}

	if "${hhstockvar_`type'} ${hhflowvar_`type'}" != " " {
		foreach v of var ${hhstockvar_`type'} ${hhflowvar_`type'} {
			disp "`v' optimal radius: treated "
			disp `v'_toptr
			disp "`v' optimal radius: untreated "
			disp `v'_utoptr
		}
	}

	if "${entstockvar_`type'} ${entflowvar_`type'}" != " " {
		foreach v of var ${entstockvar_`type'} ${entflowvar_`type'} {
			disp "`v' optimal radius"
			disp `v'_optr
		}
	}
}


****************************************
** 2. Calculate the actual multiplier **
****************************************

timer on 1

*********************************
** a. Household flow variables **
*********************************

foreach type in "exp" "inc"{

if "${hhflowvar_`type'}" != "" {
	foreach v of var ${hhflowvar_`type'} {

		** i. treated households **
		***************************

		** Get first 3 quarters from Rarieda **
		***************************************
		if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {

		preserve
		project, original("$dr/Rarieda_Data_Temporal.dta")
		use "$dr/Rarieda_Data_Temporal.dta", clear
		drop if treatmentgroup == 9 // drop pure controls
		tab svyd_midline svyd_endline, m
		keep if svyd_midline == 1 & svyd_endline == 1 // keep consistent panel

		ren cons_nondurable_house_wins_r c_nondur_house_wins_r
		ren cons_nondurable_wins_r c_nondur_wins_r

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
		reg `vrb' actamt_r_q1-actamt_r_q5 ibn.quarter `blvars' if eligible == 1, nocons cluster(village)

		gen st_`vrb' = e(sample)
		predict et_`vrb' if st_`vrb', residuals
		predict ht_`vrb' if st_`vrb'

		mata: effects = J(3,10,.)

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

			mata: effects[1,`q'] = st_numscalar("r(estimate)")
			mata: effects[2,`q'] = effects[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")
			mata: effects[3,`q'] = effects[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")
		}

		** storing estimates to add afterwards **
		lincom "`intstat'"
		scalar br_q1_q3_`v' = `r(estimate)'
		scalar sr_q1_q3_`v' = `r(se)'

		mata: st_matrix("rar_effects`b'",effects)

		** Export IRF for graph **
		mat2txt, m(rar_effects`b') sav("$dt/IRF_values/treated/rar_`v'_IRF_treat.txt") replace
		project, creates("$dt/IRF_values/treated/rar_`v'_IRF_treat.txt") preserve

		save "$dt/RariedaData_forbootstrap.dta", replace
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

		ivreg2 `v' (`endregs' = `exregs') ibn.quarter `blvars' [aweight=hhweight_EL] if eligible == 1, nocons

		gen st_`v' = e(sample)
		predict et_`v' if st_`v', residuals
		predict ht_`v' if st_`v'

		if !inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") mata: effects = J(3,10,.)

		local intstat = "0"

		if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") global firstquarter = 4

		forval q = $firstquarter(1)10 {
			local lag1 = `q'
			local lag2 = `q' - 2

			if `q' < 3 {
				local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87)"
				local intstat = "`intstat'"  + " + (pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87)"

				forval r = 2(2)`rad' {
					local r2 = `r' - 2
					local intstat = "`intstat'"  + " + pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km} *(47/87)"
					local irfstat = "`irfstat'"  + " + pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km} *(47/87)"
				}
			}

			else {
				local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87) + (pac_ownvill_r_q`lag2'*$eligtreat_amt_ownvill)*(40/87)"
				local intstat = "`intstat'"  + " + (pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87) + (pac_ownvill_r_q`lag2'*$eligtreat_amt_ownvill)*(40/87)"

				forval r = 2(2)`rad' {
					local r2 = `r' - 2
					local intstat = "`intstat'"  + " + (pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km})*(47/87) + (pac_ov_`r2'to`r'km_r_q`lag2'*${eligtreat_amt_ov_`r2'to`r'km})*(40/87)"
					local irfstat = "`irfstat'"  + " + (pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km})*(47/87) + (pac_ov_`r2'to`r'km_r_q`lag2'*${eligtreat_amt_ov_`r2'to`r'km})*(40/87)"

					}
			}

		lincom "`irfstat'"

		mata: effects[1,`q'] = st_numscalar("r(estimate)")
		mata: effects[2,`q'] = effects[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")
		mata: effects[3,`q'] = effects[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")
		}


		** Plot **
		**********
		mata: st_matrix("effects",effects)

		if `plotindic' == 1 coefplot (matrix(effects[1,.]), ci((effects[2,.] effects[3,.])) at(matrix(at1))), recast(line) color(navy) ciopts(recast(rarea) color(navy%25) alcolor(%0)) vertical yline(0) legend(off) scheme(tufte) ///
				ylabel(-0.1(0.1)0.2) xlabel(0(3)27) xtitle("Months since first transfer") ytitle("Direct effect on the treated - relative to size of transfer") title("`v' IRF - Treated Households")
		if `plotindic' == 1 {
			if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") graph export "$dfig/IRFs/HHs/deflated/`v'_Treated_withRarieda.pdf", as(pdf) replace
			if !inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") graph export "$dfig/IRFs/HHs/deflated/`v'_Treated.pdf", as(pdf) replace
		}

		** Total consumption integral **
		disp "Treated households, `v': `intstat'"
		lincom "`intstat'"

		if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
			scalar `v'_mult = `v'_mult + `r(estimate)' + br_q1_q3_`v'
			scalar multiplier_`type' = multiplier_`type' + `r(estimate)' + br_q1_q3_`v'
			global firstquarter = 1
		}

		if !inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
			scalar `v'_mult = `v'_mult + `r(estimate)'
			scalar multiplier_`type' = multiplier_`type' + `r(estimate)'
		}

		mata: effectstreat = effects

		mata: st_matrix("effectstreat",effectstreat)
		if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
			mat2txt, m(effectstreat) sav("$dt/IRF_values/treated/`v'_IRF_treat_r_withRarieda.txt") replace
			project, creates("$dt/IRF_values/treated/`v'_IRF_treat_r_withRarieda.txt") preserve
		}
		/*
		if !inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
			mat2txt, m(effectstreat) sav("$dt/IRF_values/treated/`v'_IRF_treat_r.txt") replace
			project, creates("$dt/IRF_values/treated/`v'_IRF_treat_r.txt") preserve
		}
		*/

		** ii. untreated households **
		******************************
		local rad = `v'_utoptr // this is the optimal radius as determined above

		** add all buffer variables **
		local endregs = ""
		local exregs = ""
		forval r = 2(2)`rad' {
			local r2 = `r' - 2

			local endregs = "`endregs'" + "pac_`r2'to`r'km_r_el_q1-pac_`r2'to`r'km_r_el_q10 pac_`r2'to`r'km_r_in_q1-pac_`r2'to`r'km_r_in_q10"
			local exregs = "`exregs'" + "t_shr_actamt_`r2'to`r'km_r_el_q1-t_shr_actamt_`r2'to`r'km_r_el_q10 t_shr_actamt_`r2'to`r'km_r_in_q1-t_shr_actamt_`r2'to`r'km_r_in_q10"
		}


		ivreg2 `v' (`endregs' = `exregs') ibn.quarter#i.eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0), nocons


		gen su_`v' = e(sample)
		predict eu_`v' if su_`v', residuals
		predict hu_`v' if su_`v'

		local intstat = "0"
		forval q = $firstquarter(1)10 {
			local lag1 = `q'
			local lag2 = `q' - 2

			if `q' < 3 {
				forval r = 2(2)`rad' {
					local r2 = `r' - 2
					local intstat = "`intstat'"  + " + (pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87)"
					local irfstat = "(pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87)"

				}
			}

			else {
				forval r = 2(2)`rad' {
					local r2 = `r' - 2
					local intstat = "`intstat'"  + " + (pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87) + (pac_`r2'to`r'km_r_el_q`lag2'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag2'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(40/87)"
					local irfstat = "(pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87) + (pac_`r2'to`r'km_r_el_q`lag2'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag2'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(40/87)"
				}
			}

		lincom "`irfstat'"

		mata: effects[1,`q'] = st_numscalar("r(estimate)")
		mata: effects[2,`q'] = effects[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")
		mata: effects[3,`q'] = effects[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")

		}

		** Plot **
		**********
		mata: st_matrix("effects",effects)

		if `plotindic' == 1 coefplot (matrix(effects[1,.]), ci((effects[2,.] effects[3,.])) at(matrix(at1))), recast(line) color(navy) ciopts(recast(rarea) color(navy%25) alcolor(%0)) vertical yline(0) legend(off) scheme(tufte) ///
				ylabel(-0.1(0.1)0.2) xlabel(0(3)27) xtitle("Months since first transfer") ytitle("Direct effect on the untreated - relative to size of transfer") title("`v' IRF - Untreated Households")
		if `plotindic' == 1 graph export "$dfig/IRFs/HHs/deflated/`v'_Untreated.pdf", as(pdf) replace

		mata: effectsuntreat = effects

		mata: st_matrix("effectsuntreat",effectsuntreat*$untreatweight)
		*if $firstquarter == 1 mat2txt, m(effectsuntreat) sav("$dt/IRF_values/untreated/`v'_IRF_untreat_r.txt") replace
		*project, creates("$dt/IRF_values/untreated/`v'_IRF_untreat_r.txt") preserve

		** Total consumption integral **
		disp "Untreated households, `v': `intstat'"
		lincom "`intstat'"
		scalar `v'_mult = `v'_mult + ($untreatweight *`r(estimate)')
		scalar multiplier_`type' = multiplier_`type' + ($untreatweight * `r(estimate)')


		** Export joint IRF for epic graph **
		mata: jointeffects = J(1,10,.)
		forval q = $firstquarter(1)10 {
			mata: jointeffects[1,`q'] = effectstreat[1,`q'] + $untreatweight * effectsuntreat[1,`q']
		}
		mata: st_matrix("jointeffects",jointeffects)
		if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
			mat2txt, m(jointeffects) sav("$dt/IRF_values/joint/`v'_IRF_joint_r_withRarieda.txt") replace
			project, creates("$dt/IRF_values/joint/`v'_IRF_joint_r_withRarieda.txt") preserve
		}
		/*
		if !inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
			mat2txt, m(jointeffects) sav("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") replace
			project, creates("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") preserve
		}
		*/
	}
}


**********************************
** b. Household stock variables **
**********************************

if "${hhstockvar_`type'}" != "" {
	foreach v of var ${hhstockvar_`type'} {

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
		scalar `v'_mult = `v'_mult + `r(estimate)'
		scalar multiplier_`type' = multiplier_`type' + `r(estimate)'

		scalar smoothed_mult = `r(estimate)' / (10-$firstquarter + 1)

		mata: effectstreat = J(3,10,.)

		forval q = $firstquarter(1)10 {
			mata: effectstreat[1,`q'] = st_numscalar("smoothed_mult")
			mata: effectstreat[2,`q'] = effectstreat[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")/(10-$firstquarter + 1)
			mata: effectstreat[3,`q'] = effectstreat[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")/(10-$firstquarter + 1)
		}



		mata: st_matrix("effectstreat",effectstreat)
		*if $firstquarter == 1 mat2txt, m(effectstreat) sav("$dt/IRF_values/treated/`v'_IRF_treat_r.txt") replace
		*project, creates("$dt/IRF_values/treated/`v'_IRF_treat_r.txt") preserve

		** ii. untreated households **
		******************************
		local rad = `v'_utoptr // this is the optimal radius as determined above
		local rad2 = `rad' - 2

		local endregs = ""
		local exregs = ""
		forval r = 2(2)`rad' {
			local r2 = `r' - 2

			local endregs = "`endregs'" + " pac_`r2'to`r'km_r_eligible" + " pac_`r2'to`r'km_r_ineligible"
			local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`r'km_el"  + " share_ge_elig_treat_`r2'to`r'km_in"
		}

		ivreg2 `v' (`endregs' = `exregs') eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0), cluster(sublocation_code)

		gen su_`v' = e(sample)
		predict eu_`v' if su_`v', residuals
		predict hu_`v' if su_`v'


		** Get mean total spillover effect on eligibles in control villages and ineligibles **
		local ATEstring_spillover = "0"
		forval r = 2(2)`rad' {
			local r2 = `r' - 2
			local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "$eligcontrolweight" + "*${eligcontrol_amt_`r2'to`r'km}" + "*pac_`r2'to`r'km_r_eligible"
			local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "$ineligweight" + "*${inelig_amt_`r2'to`r'km}" + "*pac_`r2'to`r'km_r_ineligible"
		}

		disp "Untreated households, `v': `ATEstring_spillover'"
		lincom "`ATEstring_spillover'"
		scalar `v'_mult = `v'_mult + ($untreatweight *`r(estimate)')
		scalar multiplier_`type' = multiplier_`type' + ($untreatweight * `r(estimate)')


		scalar smoothed_mult = ($untreatweight *`r(estimate)') / (10-$firstquarter + 1)

		mata: effectsuntreat = J(3,10,.)


		forval q = $firstquarter(1)10 {
			mata: effectsuntreat[1,`q'] = st_numscalar("smoothed_mult")
			mata: effectsuntreat[2,`q'] = effectsuntreat[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")/(10-$firstquarter + 1)
			mata: effectsuntreat[3,`q'] = effectsuntreat[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")/(10-$firstquarter + 1)
		}



		mata: st_matrix("effectsuntreat",effectsuntreat)
		*if $firstquarter == 1 mat2txt, m(effectsuntreat) sav("$dt/IRF_values/untreated/`v'_IRF_untreat_r.txt") replace
		*project, creates("$dt/IRF_values/untreated/`v'_IRF_untreat_r.txt") preserve

		** Export joint IRF for epic graph **
		mata: jointeffects = J(1,10,.)
		forval q = $firstquarter(1)10 {
			mata: jointeffects[1,`q'] = effectstreat[1,`q'] + effectsuntreat[1,`q']
		}

		mata: st_matrix("jointeffects",jointeffects)
		*if $firstquarter == 1 mat2txt, m(jointeffects) sav("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") replace
		*project, creates("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") preserve

	}
}


**********************************
** c. Enterprise flow variables **
**********************************
if "${entflowvar_`type'}" != "" {
	foreach v of var ${entflowvar_`type'} {

		local rad = `v'_optr // this is the optimal radius as determined above
		local rad2 = `rad' - 2

		if $includeBL == 1 {
			** add baseline variables **
			cap desc `v'_vBL M`v'_vBL
			if _rc == 0 {
				local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
			}
			else {
				local vblvars ""
			}
		}
		else {
			local vblvars ""
		}

		** add all buffer variables **
		local endregs = ""
		local exregs ""
		forval q = 1(1)10 {
			local endregs = "`endregs'" + " c.pac_ownvill_r_q`q'#ent_type"
			local exregs = "`exregs'" + " c.t_share_actamt_ownvill_r_q`q'#ent_type"

			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pac_ov_`r2'to`r'km_r_q`q'#ent_type"
				local exregs = "`exregs'" + " c.t_share_actamt_ov_`r2'to`r'km_r_q`q'#ent_type"
			}
		}

		ivreg2 `v' (`endregs' = `exregs') ibn.quarter#i.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code)

		gen s_`v' = e(sample)
		predict e_`v' if s_`v', residuals
		predict h_`v' if s_`v'

		mata: effects_total = J(3,10,.)
		mata: effects_spillover = J(3,10,.)


		** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
		** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
		** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

		local intstat_total = "0"
		local intstat_spillover = "0"

		forval q = $firstquarter(1)10 {
			local lag1 = `q'
			local lag2 = `q' - 2

			local irfstat_total = ""
			local irfstat_spillover = ""

			if `q' < 3 {
				*local intstat_total = "`intstat_total'"  + " + $treatent2_amt_ownvill" + "*2.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall * (47/87)"
				*local intstat_total = "`intstat_total'" + " + $treatent1_amt_ownvill" + "*1.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall * (47/87)"

				local irfstat_total = "$treatent2_amt_ownvill" + "*2.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall * (47/87)"
				local irfstat_total = "`irfstat_total'" + " + $treatent1_amt_ownvill" + "*1.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall * (47/87)"


				sum `v' if ent_type == 3
				if r(N) != 0 {  // we don't have this information for agricultural businesses
					*local intstat_total = "`intstat_total'" + " + $treatent3_amt_ownvill" + "*3.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall * (47/87)"
					local irfstat_total = "`irfstat_total'" + " + $treatent3_amt_ownvill" + "*3.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall * (47/87)"
				}

				forval r = 2(2)`rad' {
					local r2 = `r' - 2

					*local intstat_total = "`intstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall *(47/87)"
					*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_control / $n_hh_controlall * (47/87)"

					*local intstat_total = "`intstat_total'" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall *(47/87)"
					*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_control / $n_hh_controlall * (47/87)"

					local irfstat_total = "`irfstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall *(47/87)" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall *(47/87)"
					local irfstat_spillover = "${controlent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_control / $n_hh_controlall * (47/87)"  + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_control / $n_hh_controlall * (47/87)"

					sum `v' if ent_type == 3
					if r(N) != 0 {  // we don't have this information for agricultural businesses
						*local intstat_total = "`intstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall *(47/87)"
						*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_control / $n_hh_controlall * (47/87)"

						local irfstat_total = "`irfstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall *(47/87)"
						local irfstat_spillover = "`irfstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_control / $n_hh_controlall * (47/87)"
					}
				}
			}

			else {
				*local intstat_total = "`intstat_total'"  + " + $treatent2_amt_ownvill" + "*(2.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
				*local intstat_total = "`intstat_total'" + " + $treatent1_amt_ownvill" + "*(1.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"

				local irfstat_total = "$treatent2_amt_ownvill" + "*(2.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
				local irfstat_total = "`irfstat_total'" + " + $treatent1_amt_ownvill" + "*(1.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"

				sum `v' if ent_type == 3
				if r(N) != 0 {  // we don't have this information for agricultural businesses
					*local intstat_total = "`intstat_total'" + " + $treatent3_amt_ownvill" + "*(3.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 3.ent_type#c.pac_ownvill_r_q`lag2' * (40/87))* $n_ent_ownfarm_treatall / $n_hh_treatall"
					local irfstat_total = "`irfstat_total'" + " + $treatent3_amt_ownvill" + "*(3.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 3.ent_type#c.pac_ownvill_r_q`lag2' * (40/87))* $n_ent_ownfarm_treatall / $n_hh_treatall"
				}

				forval r = 2(2)`rad' {
					local r2 = `r' - 2

					*local intstat_total = "`intstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
					*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_control / $n_hh_controlall"

					*local intstat_total = "`intstat_total'" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"
					*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_control / $n_hh_controlall"

					local irfstat_total = "`irfstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
					local irfstat_spillover = "${controlent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_control / $n_hh_controlall"

					local irfstat_total = "`irfstat_total'" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"
					local irfstat_spillover = "`irfstat_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_control / $n_hh_controlall"


					sum `v' if ent_type == 3
					if r(N) != 0 {  // we don't have this information for agricultural businesses
						*local intstat_total = "`intstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' *(47/87) +  3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_treatall / $n_hh_treatall"
						*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' *(47/87) + 3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_control / $n_hh_controlall"

						local irfstat_total = "`irfstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' *(47/87) +  3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_treatall / $n_hh_treatall"
						local irfstat_spillover = "`irfstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_control / $n_hh_controlall"
				}
			}
		}

		di "`irfstat_total'"
		lincom "`irfstat_total'"

		local intstat_total = "`intstat_total'" + "+ `r(estimate)'"

		mata: effects_total[1,`q'] = st_numscalar("r(estimate)")
		mata: effects_total[2,`q'] = effects_total[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")
		mata: effects_total[3,`q'] = effects_total[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")


		di "`irfstat_spillover'"
		lincom "`irfstat_spillover'"

		local intstat_spillover = "`intstat_spillover '" + "+ `r(estimate)'"

		mata: effects_spillover[1,`q'] = st_numscalar("r(estimate)")
		mata: effects_spillover[2,`q'] = effects_spillover[1,`q'] - invnormal(0.975)*st_numscalar("r(se)")
		mata: effects_spillover[3,`q'] = effects_spillover[1,`q'] + invnormal(0.975)*st_numscalar("r(se)")

		}

		** Plot **
		**********
		mata: st_matrix("effects_total",effects_total)

		if `plotindic' == 1 coefplot (matrix(effects_total[1,.]), ci((effects_total[2,.] effects_total[3,.])) at(matrix(at1))), recast(line) color(navy) ciopts(recast(rarea) color(navy%25) alcolor(%0)) vertical yline(0) legend(off) scheme(tufte) ///
				ylabel(-0.1(0.1)0.2) xlabel(0(3)27) xtitle("Months since first transfer") ytitle("Direct effect - relative to size of transfer") title("`v' IRF - Enterprise Treatment Effect")
		if `plotindic' == 1 graph export "$dfig/IRFs/ENTs/deflated/`v'_TreatedVills.pdf", as(pdf) replace

		mata: st_matrix("effects_total",effects_total*$n_hh_treatall / $n_hh_treat)
		*if $firstquarter == 1 mat2txt, m(effects_total) sav("$dt/IRF_values/treated/`v'_IRF_total_r.txt") replace
		*project, creates("$dt/IRF_values/treated/`v'_IRF_total_r.txt") preserve

		** Plot **
		**********
		mata: st_matrix("effects_spillover",effects_spillover)

		if `plotindic' == 1 coefplot (matrix(effects_spillover[1,.]), ci((effects_spillover[2,.] effects_spillover[3,.])) at(matrix(at1))), recast(line) color(navy) ciopts(recast(rarea) color(navy%25) alcolor(%0)) vertical yline(0) legend(off) scheme(tufte) ///
				ylabel(-0.1(0.1)0.2) xlabel(0(3)27) xtitle("Months since first transfer") ytitle("Spillover effect - relative to size of transfer") title("`v' IRF - Enterprise Spillover")
		if `plotindic' == 1 graph export "$dfig/IRFs/ENTs/deflated/`v'_UntreatedVills.pdf", as(pdf) replace

		mata: st_matrix("effects_spillover",effects_spillover*$n_hh_controlall / $n_hh_treat)
		*if $firstquarter == 1 mat2txt, m(effects_spillover) sav("$dt/IRF_values/untreated/`v'_IRF_spillover_r.txt") replace
		*project, creates("$dt/IRF_values/untreated/`v'_IRF_spillover_r.txt") preserve


		** Total integral **
		lincom "`intstat_total'" // this is per household in treated villages, in fractions of the transfer
		scalar `v'_mult = `v'_mult + ($n_hh_treatall / $n_hh_treat * `r(estimate)')
		scalar multiplier_`type' = multiplier_`type' + ($n_hh_treatall / $n_hh_treat * `r(estimate)')

		lincom "`intstat_spillover'" // this is per household in control villages, in fractions of the transfer
		scalar `v'_mult = `v'_mult + ($n_hh_controlall / $n_hh_treat * `r(estimate)')
		scalar multiplier_`type' = multiplier_`type' + ($n_hh_controlall / $n_hh_treat * `r(estimate)')


		** Export joint IRF for epic graph **
		mata: jointeffects = J(1,10,.)
		forval q = $firstquarter(1)10 {
			mata: jointeffects[1,`q'] = ($n_hh_treatall / $n_hh_treat * effects_total[1,`q']) + ($n_hh_controlall / $n_hh_treat * effects_spillover[1,`q'])
		}
		mata: st_matrix("jointeffects",jointeffects)
		*if $firstquarter == 1 mat2txt, m(jointeffects) sav("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") replace
		*project, creates("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") preserve
	}
}


***********************************
** d. Enterprise stock variables **
***********************************
if "${entstockvar_`type'}" != "" {
	foreach v of var ${entstockvar_`type'} {

		local rad = `v'_optr // this is the optimal radius as determined above
		local rad2 = `rad' - 2

		if $includeBL == 1 {
			** add baseline variables **
			cap desc `v'_vBL M`v'_vBL
			if _rc == 0 {
				local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
			}
			else {
				local vblvars ""
			}
		}
		else {
			local vblvars ""
		}

		local endregs = "c.pac_ownvill_r#ent_type"
		local exregs = "treat#ent_type"
		forval r = 2(2)`rad' {
			local r2 = `r' - 2
			local endregs = "`endregs'" + " c.pac_ov_`r2'to`r'km_r#ent_type"
			local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
		}

		ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code)


		gen s_`v' = e(sample)
		predict e_`v' if s_`v', residuals
		predict h_`v' if s_`v'

		mata: effects_total = J(3,10,.)
		mata: effects_spillover = J(3,10,.)


		** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
		** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
		** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

		local ATEstring_total = "$treatent2_amt_ownvill" + "*2.ent_type#c.pac_ownvill_r * $n_ent_from_hh_treatall / $n_hh_treatall"
		local ATEstring_total = "`ATEstring_total'" + "+" + "$treatent1_amt_ownvill" + "*1.ent_type#c.pac_ownvill_r * $n_ent_outside_hh_treatall / $n_hh_treatall"

		sum `v' if ent_type == 3
		if r(N) != 0 {  // we don't have this information for agricultural businesses
			local ATEstring_total = "`ATEstring_total'" + "+" + "$treatent3_amt_ownvill" + "*3.ent_type#c.pac_ownvill_r * $n_ent_ownfarm_treatall / $n_hh_treatall"
		}

		local ATEstring_spillover = "0"
		forval r = 2(2)`rad' {
			local r2 = `r' - 2

			local ATEstring_total = "`ATEstring_total'" + "+" + "${treatent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_from_hh_treatall / $n_hh_treatall"
			local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "${controlent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_from_hh_control / $n_hh_controlall"

			local ATEstring_total = "`ATEstring_total'" + "+" + "${treatent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_outside_hh_treatall / $n_hh_treatall"
			local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_outside_hh_control / $n_hh_controlall"

			sum `v' if ent_type == 3
			if r(N) != 0 {  // we don't have this information for agricultural businesses
				local ATEstring_total = "`ATEstring_total'" + "+" + "${treatent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_ownfarm_treatall / $n_hh_treatall"
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_ownfarm_control / $n_hh_controlall"
			}
		}

		disp "Treated villages, investment: `ATEstring_total'"
		lincom "`ATEstring_total'" // this is per household in treated villages, in fractions of the transfer
		scalar `v'_mult = `v'_mult + ($n_hh_treatall / $n_hh_treat * `r(estimate)')
		scalar multiplier_`type' = multiplier_`type' + ($n_hh_treatall / $n_hh_treat * `r(estimate)')

		forval q = $firstquarter(1)10 {
			mata: effects_total[1,`q'] = st_numscalar("r(estimate)") / (10-$firstquarter + 1)
			mata: effects_total[2,`q'] = effects_total[1,`q'] - invnormal(0.975)*st_numscalar("r(se)") / (10-$firstquarter + 1)
			mata: effects_total[3,`q'] = effects_total[1,`q'] + invnormal(0.975)*st_numscalar("r(se)") / (10-$firstquarter + 1)
		}

		mata: st_matrix("effects_total",effects_total*$n_hh_treatall / $n_hh_treat)
		*if $firstquarter == 1 mat2txt, m(effects_total) sav("$dt/IRF_values/treated/`v'_IRF_total_r.txt") replace
		*project, creates("$dt/IRF_values/treated/`v'_IRF_total_r.txt") preserve

		disp "Control villages, investment: `ATEstring_spillover'"
		lincom "`ATEstring_spillover'" // this is per household in control villages, in fractions of the transfer
		scalar `v'_mult = `v'_mult + ($n_hh_controlall / $n_hh_treat * `r(estimate)')
		scalar multiplier_`type' = multiplier_`type' + ($n_hh_controlall / $n_hh_treat * `r(estimate)')

		forval q = $firstquarter(1)10 {
			mata: effects_spillover[1,`q'] = st_numscalar("r(estimate)") / (10-$firstquarter + 1)
			mata: effects_spillover[2,`q'] = effects_spillover[1,`q'] - invnormal(0.975)*st_numscalar("r(se)") / (10-$firstquarter + 1)
			mata: effects_spillover[3,`q'] = effects_spillover[1,`q'] + invnormal(0.975)*st_numscalar("r(se)") / (10-$firstquarter + 1)
		}

		mata: st_matrix("effects_spillover",effects_spillover*$n_hh_controlall / $n_hh_treat)
		*if $firstquarter == 1 mat2txt, m(effects_spillover) sav("$dt/IRF_values/untreated/`v'_IRF_spillover_r.txt") replace
		*project, creates("$dt/IRF_values/untreated/`v'_IRF_spillover_r.txt") preserve

		scalar smoothed_mult = `v'_mult / (10-$firstquarter + 1)

		** Export joint IRF for epic graph **
		mata: jointeffects = J(1,10,.)
		forval q = $firstquarter(1)10 {
			mata: jointeffects[1,`q'] = st_numscalar("smoothed_mult")
		}
		mata: st_matrix("jointeffects",jointeffects)
		*if $firstquarter == 1 mat2txt, m(jointeffects) sav("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") replace
		*project, creates("$dt/IRF_values/joint/`v'_IRF_joint_r.txt") preserve

	}
}


*************************************
** f. Local government expenditure **
*************************************

}

******************************************
** Save main estimate of the multiplier **
******************************************

matrix full_estimates = `full_estimates'
scalar mean_mult = (multiplier_inc + multiplier_exp) / 2

timer off 1
timer list
loc runtime = `r(t1)'



****************************************
** 	NOW SET UP THE WILD BOOTSTRAP 	****
****************************************
capture program drop wildboot
program define wildboot, rclass

	cap drop rand
	sort sublocation_code ent_id_universe hhid_key
	gen rand = runiform()
	bys sublocation_code (ent_id_universe hhid_key): replace rand = cond(rand[1] <= 0.5, 1, -1)

	foreach type in "exp" "inc"{

		foreach var in ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
			scalar `var'_mult = 0
		}

		scalar multiplier_`type' = 0


		forvalues q = $firstquarter(1)10{
			scalar multiplier_`type'_q`q' = 0
		}

	*********************************
	** a. Household flow variables **
	*********************************
	if "${hhflowvar_`type'}" != "" {
		foreach v of var ${hhflowvar_`type'} {

			** i. treated households **
			***************************

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
			forval q = 1(1)3 { // only sum up to 3 quarters
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
				scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + `r(estimate)'

			}

			** Store total consumption integral for adding later **
			disp "Treated households, `v': `intstat'"
			lincom "`intstat'"

			scalar br_q1_q3_`v' = `r(estimate)'
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
			*ivreg2 `v' (pac_ownvill_q1-pac_ownvill_q10 pac_ov_0to2km_q1-pac_ov_0to2km_q10 = t_share_actamt_ownvill_q1-t_share_actamt_ownvill_q10 t_share_actamt_ov_0to2km_q1-t_share_actamt_ov_0to2km_q10) ibn.quarter [aweight=hhweight_EL] if eligible == 1, nocons

			local intstat = "0"
			if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") global firstquarter = 4
			if !inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") global firstquarter = 1
			forval q = $firstquarter(1)10 {
				local lag1 = `q'
				local lag2 = `q' - 2

				if `q' < 3 {
					local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87)"
					local intstat = "`intstat'"  + " + (pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87)"

					forval r = 2(2)`rad' {
						local r2 = `r' - 2
						local intstat = "`intstat'"  + " + pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km} *(47/87)"
						local irfstat = "`irfstat'"  + " + pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km} *(47/87)"
					}
				}

				else {
					local irfstat = "(pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87) + (pac_ownvill_r_q`lag2'*$eligtreat_amt_ownvill)*(40/87)"
					local intstat = "`intstat'"  + " + (pac_ownvill_r_q`lag1'*$eligtreat_amt_ownvill)*(47/87) + (pac_ownvill_r_q`lag2'*$eligtreat_amt_ownvill)*(40/87)"

					forval r = 2(2)`rad' {
						local r2 = `r' - 2
						local intstat = "`intstat'"  + " + (pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km})*(47/87) + (pac_ov_`r2'to`r'km_r_q`lag2'*${eligtreat_amt_ov_`r2'to`r'km})*(40/87)"
						local irfstat = "`irfstat'"  + " + (pac_ov_`r2'to`r'km_r_q`lag1'*${eligtreat_amt_ov_`r2'to`r'km})*(47/87) + (pac_ov_`r2'to`r'km_r_q`lag2'*${eligtreat_amt_ov_`r2'to`r'km})*(40/87)"

						}
				}

			lincom "`irfstat'"
			scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + `r(estimate)'

			}

			** Total consumption integral **
			disp "Treated households, `v': `intstat'"
			lincom "`intstat'"
			if inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
				scalar `v'_mult = `v'_mult + `r(estimate)' + br_q1_q3_`v'
				scalar multiplier_`type' = multiplier_`type' + `r(estimate)' + br_q1_q3_`v'
				global firstquarter = 1
			}

			if !inlist("`v'", "p2_exp_mult_wins_r", "nondurables_exp_wins_r") {
				scalar `v'_mult = `v'_mult + `r(estimate)'
				scalar multiplier_`type' = multiplier_`type' + `r(estimate)'
			}


			** ii. untreated households **
			******************************
			local rad = `v'_utoptr // this is the optimal radius as determined above

			** add all buffer variables **
			local endregs = ""
			local exregs = ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2

				local endregs = "`endregs'" + "pac_`r2'to`r'km_r_el_q1-pac_`r2'to`r'km_r_el_q10 pac_`r2'to`r'km_r_in_q1-pac_`r2'to`r'km_r_in_q10"
				local exregs = "`exregs'" + "t_shr_actamt_`r2'to`r'km_r_el_q1-t_shr_actamt_`r2'to`r'km_r_el_q10 t_shr_actamt_`r2'to`r'km_r_in_q1-t_shr_actamt_`r2'to`r'km_r_in_q10"
			}

			cap drop p_`v'
			gen p_`v' = hu_`v' + eu_`v'*rand if su_`v'

			ivreg2 p_`v' (`endregs' = `exregs') ibn.quarter#i.eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0), nocons
			*ivreg2 `v' (pac_0to2km_el_q1-pac_0to2km_el_q10 pac_0to2km_in_q1-pac_0to2km_in_q10 = t_shr_actamt_0to2km_el_q1-t_shr_actamt_0to2km_el_q10 t_shr_actamt_0to2km_in_q1-t_shr_actamt_0to2km_in_q10) ibn.quarter#i.eligible [aweight=hhweight_EL] if (eligible == 0 | treat == 0), nocons

			local intstat = "0"
			forval q = $firstquarter(1)10 {
				local lag1 = `q'
				local lag2 = `q' - 2

				if `q' < 3 {
					forval r = 2(2)`rad' {
						local r2 = `r' - 2
						local intstat = "`intstat'"  + " + (pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87)"
						local irfstat = "(pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87)"

					}
				}

				else {
					forval r = 2(2)`rad' {
						local r2 = `r' - 2
						local intstat = "`intstat'"  + " + (pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87) + (pac_`r2'to`r'km_r_el_q`lag2'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag2'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(40/87)"
						local irfstat = "(pac_`r2'to`r'km_r_el_q`lag1'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag1'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(47/87) + (pac_`r2'to`r'km_r_el_q`lag2'*${eligcontrol_amt_`r2'to`r'km}*$eligcontrolweight + pac_`r2'to`r'km_r_in_q`lag2'*${inelig_amt_`r2'to`r'km}*$ineligweight)*(40/87)"
					}
				}

			lincom "`irfstat'"
			scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + ($untreatweight * `r(estimate)')

			}

			** Total consumption integral **
			disp "Untreated households, `v': `intstat'"
			lincom "`intstat'"
			scalar `v'_mult = `v'_mult + ($untreatweight * `r(estimate)')
			scalar multiplier_`type' = multiplier_`type' + ($untreatweight * `r(estimate)')

		}
	}

	**********************************
	** b. Household stock variables **
	**********************************
	if "${hhstockvar_`type'}" != "" {
		foreach v of var ${hhstockvar_`type'} {

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
			ivreg2 p_`v' (pac_ownvill_r pac_ov_0to2km_r-pac_ov_`rad2'to`rad'km_r = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`rad2'to`rad'km) `blvars' [aweight=hhweight_EL] if eligible == 1

			** Get mean total effect on treated eligibles **
			local ATEstring_tot = "$eligtreat_amt_ownvill" + "*pac_ownvill_r"

			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local ATEstring_tot = "`ATEstring_tot'" + "+" + "${eligtreat_amt_ov_`r2'to`r'km}" + "*" + "pac_ov_`r2'to`r'km_r"
			}

			disp "Treated households, `v': `ATEstring_tot'"
			lincom "`ATEstring_tot'"
			scalar `v'_mult = `v'_mult + `r(estimate)'
			scalar multiplier_`type' = multiplier_`type' + `r(estimate)'

			forvalues q = $firstquarter(1)10{
				scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + (`r(estimate)'/(11-$firstquarter))
			}


			** ii. untreated households **
			******************************
			local rad = `v'_utoptr // this is the optimal radius as determined above
			local rad2 = `rad' - 2

			local endregs = ""
			local exregs = ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2

				local endregs = "`endregs'" + " pac_`r2'to`r'km_r_eligible" + " pac_`r2'to`r'km_r_ineligible"
				local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`r'km_el"  + " share_ge_elig_treat_`r2'to`r'km_in"
			}

			cap drop p_`v'
			gen p_`v' = hu_`v' + eu_`v'*rand if su_`v'
			ivreg2 `v' (`endregs' = `exregs') eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0)


			** Get mean total spillover effect on eligibles in control villages and ineligibles **
			local ATEstring_spillover = "0"
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "$eligcontrolweight" + "*${eligcontrol_amt_`r2'to`r'km}" + "*pac_`r2'to`r'km_r_eligible"
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "$ineligweight" + "*${inelig_amt_`r2'to`r'km}" + "*pac_`r2'to`r'km_r_ineligible"
			}

			disp "Untreated households, `v': `ATEstring_spillover'"
			lincom "`ATEstring_spillover'"
			scalar `v'_mult = `v'_mult + ($untreatweight * `r(estimate)')
			scalar multiplier_`type' = multiplier_`type' + ($untreatweight * `r(estimate)')


			forvalues q = $firstquarter(1)10{
				scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + ($untreatweight * `r(estimate)'/(11-$firstquarter))
			}

		}
	}


	**********************************
	** c. Enterprise flow variables **
	**********************************
	if "${entflowvar_`type'}" != "" {
		foreach v of var ${entflowvar_`type'} {

			local rad = `v'_optr // this is the optimal radius as determined above
			local rad2 = `rad' - 2

			if $includeBL == 1 {
				** add baseline variables **
				cap desc `v'_vBL M`v'_vBL
				if _rc == 0 {
					local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
				}
				else {
					local vblvars ""
				}
			}
			else {
				local vblvars ""
			}

			** add all buffer variables **
			local endregs = ""
			local exregs ""
			forval q = 1(1)10 {
				local endregs = "`endregs'" + " c.pac_ownvill_r_q`q'#ent_type"
				local exregs = "`exregs'" + " c.t_share_actamt_ownvill_r_q`q'#ent_type"

				forval r = 2(2)`rad' {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pac_ov_`r2'to`r'km_r_q`q'#ent_type"
					local exregs = "`exregs'" + " c.t_share_actamt_ov_`r2'to`r'km_r_q`q'#ent_type"
				}
			}

			cap drop p_`v'
			gen p_`v' = h_`v' + e_`v'*rand if s_`v'
			ivreg2 p_`v' (`endregs' = `exregs') ibn.quarter#i.ent_type `vblvars' [aweight=entweight_EL]

			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
			** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

			local intstat_total = "0"
			local intstat_spillover = "0"

			forval q = $firstquarter(1)10 {
				local lag1 = `q'
				local lag2 = `q' - 2

				local irfstat_total = ""
				local irfstat_spillover = ""

				if `q' < 3 {
					*local intstat_total = "`intstat_total'"  + " + $treatent2_amt_ownvill" + "*2.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall * (47/87)"
					*local intstat_total = "`intstat_total'" + " + $treatent1_amt_ownvill" + "*1.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall * (47/87)"

					local irfstat_total = "$treatent2_amt_ownvill" + "*2.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall * (47/87)"
					local irfstat_total = "`irfstat_total'" + " + $treatent1_amt_ownvill" + "*1.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall * (47/87)"


					sum `v' if ent_type == 3
					if r(N) != 0 {  // we don't have this information for agricultural businesses
						*local intstat_total = "`intstat_total'" + " + $treatent3_amt_ownvill" + "*3.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall * (47/87)"
						local irfstat_total = "`irfstat_total'" + " + $treatent3_amt_ownvill" + "*3.ent_type#c.pac_ownvill_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall * (47/87)"
					}

					forval r = 2(2)`rad' {
						local r2 = `r' - 2

						*local intstat_total = "`intstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall *(47/87)"
						*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_control / $n_hh_controlall * (47/87)"

						*local intstat_total = "`intstat_total'" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall *(47/87)"
						*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_control / $n_hh_controlall * (47/87)"

						local irfstat_total = "`irfstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_treatall / $n_hh_treatall *(47/87)" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_treatall / $n_hh_treatall *(47/87)"
						local irfstat_spillover = "${controlent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_from_hh_control / $n_hh_controlall * (47/87)"  + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_outside_hh_control / $n_hh_controlall * (47/87)"

						sum `v' if ent_type == 3
						if r(N) != 0 {  // we don't have this information for agricultural businesses
							*local intstat_total = "`intstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall *(47/87)"
							*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_control / $n_hh_controlall * (47/87)"

							local irfstat_total = "`irfstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_treatall / $n_hh_treatall *(47/87)"
							local irfstat_spillover = "`irfstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * $n_ent_ownfarm_control / $n_hh_controlall * (47/87)"
						}
					}
				}

				else {
					*local intstat_total = "`intstat_total'"  + " + $treatent2_amt_ownvill" + "*(2.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
					*local intstat_total = "`intstat_total'" + " + $treatent1_amt_ownvill" + "*(1.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"

					local irfstat_total = "$treatent2_amt_ownvill" + "*(2.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
					local irfstat_total = "`irfstat_total'" + " + $treatent1_amt_ownvill" + "*(1.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ownvill_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"

					sum `v' if ent_type == 3
					if r(N) != 0 {  // we don't have this information for agricultural businesses
						*local intstat_total = "`intstat_total'" + " + $treatent3_amt_ownvill" + "*(3.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 3.ent_type#c.pac_ownvill_r_q`lag2' * (40/87))* $n_ent_ownfarm_treatall / $n_hh_treatall"
						local irfstat_total = "`irfstat_total'" + " + $treatent3_amt_ownvill" + "*(3.ent_type#c.pac_ownvill_r_q`lag1' * (47/87) + 3.ent_type#c.pac_ownvill_r_q`lag2' * (40/87))* $n_ent_ownfarm_treatall / $n_hh_treatall"
					}

					forval r = 2(2)`rad' {
						local r2 = `r' - 2

						*local intstat_total = "`intstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
						*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_control / $n_hh_controlall"

						*local intstat_total = "`intstat_total'" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"
						*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_control / $n_hh_controlall"

						local irfstat_total = "`irfstat_total'" + "+ ${treatent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_treatall / $n_hh_treatall"
						local irfstat_spillover = "${controlent2_amt_ov_`r2'to`r'km}" + "*(2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 2.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_from_hh_control / $n_hh_controlall"

						local irfstat_total = "`irfstat_total'" + "+ ${treatent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) +  1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_treatall / $n_hh_treatall"
						local irfstat_spillover = "`irfstat_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*(1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 1.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_outside_hh_control / $n_hh_controlall"


						sum `v' if ent_type == 3
						if r(N) != 0 {  // we don't have this information for agricultural businesses
							*local intstat_total = "`intstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' *(47/87) +  3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_treatall / $n_hh_treatall"
							*local intstat_spillover = "`intstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' *(47/87) + 3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_control / $n_hh_controlall"

							local irfstat_total = "`irfstat_total'" + "+ ${treatent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' *(47/87) +  3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_treatall / $n_hh_treatall"
							local irfstat_spillover = "`irfstat_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*(3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag1' * (47/87) + 3.ent_type#c.pac_ov_`r2'to`r'km_r_q`lag2' * (40/87)) * $n_ent_ownfarm_control / $n_hh_controlall"
					}
				}
			}

			di "`irfstat_total'"
			lincom "`irfstat_total'"
			scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + ($n_hh_treatall / $n_hh_treat * `r(estimate)')

			local intstat_total = "`intstat_total'" + "+ `r(estimate)'"

			di "`irfstat_spillover'"
			lincom "`irfstat_spillover'"
			scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + ($n_hh_controlall / $n_hh_treat * `r(estimate)')

			local intstat_spillover = "`intstat_spillover '" + "+ `r(estimate)'"

			}

			** Total integral **
			disp "Treated villages, `v': `ATEstring_total'"
			lincom "`intstat_total'" // this is per household in treated villages, in fractions of the transfer
			scalar `v'_mult = `v'_mult + ($n_hh_treatall / $n_hh_treat * `r(estimate)')
			scalar multiplier_`type' = multiplier_`type' + ($n_hh_treatall / $n_hh_treat * `r(estimate)')

			disp "Control villages, `v': `ATEstring_spillover'"
			lincom "`intstat_spillover'" // this is per household in control villages, in fractions of the transfer
			scalar `v'_mult = `v'_mult + ($n_hh_treatall / $n_hh_treat * `r(estimate)')
			scalar multiplier_`type' = multiplier_`type' + ($n_hh_controlall / $n_hh_treat * `r(estimate)')
		}
	}


	***********************************
	** d. Enterprise stock variables **
	***********************************
	if "${entstockvar_`type'}" != "" {
		foreach v of var ${entstockvar_`type'} {

			local rad = `v'_optr // this is the optimal radius as determined above
			local rad2 = `rad' - 2

			if $includeBL == 1 {
				** add baseline variables **
				cap desc `v'_vBL M`v'_vBL
				if _rc == 0 {
					local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
				}
				else {
					local vblvars ""
				}
			}
			else {
				local vblvars ""
			}

			local endregs = "c.pac_ownvill_r#ent_type"
			local exregs = "treat#ent_type"
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pac_ov_`r2'to`r'km_r#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
			}

			cap drop p_`v'
			gen p_`v' = h_`v' + e_`v'*rand if s_`v'
			ivreg2 p_`v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]

			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
			** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

			local ATEstring_total = "$treatent2_amt_ownvill" + "*2.ent_type#c.pac_ownvill_r * $n_ent_from_hh_treatall / $n_hh_treatall"
			local ATEstring_total = "`ATEstring_total'" + "+" + "$treatent1_amt_ownvill" + "*1.ent_type#c.pac_ownvill_r * $n_ent_outside_hh_treatall / $n_hh_treatall"


			sum `v' if ent_type == 3
			if r(N) != 0 {  // we don't have this information for agricultural businesses
				local ATEstring_total = "`ATEstring_total'" + "+" + "$treatent3_amt_ownvill" + "*3.ent_type#c.pac_ownvill_r * $n_ent_ownfarm_treatall / $n_hh_treatall"
			}

			local ATEstring_spillover = "0"
			forval r = 2(2)`rad' {
				local r2 = `r' - 2

				local ATEstring_total = "`ATEstring_total'" + "+" + "${treatent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_from_hh_treatall / $n_hh_treatall"
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "${controlent2_amt_ov_`r2'to`r'km}" + "*2.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_from_hh_control / $n_hh_controlall"

				local ATEstring_total = "`ATEstring_total'" + "+" + "${treatent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_outside_hh_treatall / $n_hh_treatall"
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "${controlent1_amt_ov_`r2'to`r'km}" + "*1.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_outside_hh_control / $n_hh_controlall"


				sum `v' if ent_type == 3
				if r(N) != 0 {  // we don't have this information for agricultural businesses
					local ATEstring_total = "`ATEstring_total'" + "+" + "${treatent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_ownfarm_treatall / $n_hh_treatall"
					local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "${controlent3_amt_ov_`r2'to`r'km}" + "*3.ent_type#c.pac_ov_`r2'to`r'km_r * $n_ent_ownfarm_control / $n_hh_controlall"
				}

			}

			disp "Treated villages, investment: `ATEstring_total'"
			lincom "`ATEstring_total'" // this is per household in treated villages, in fractions of the transfer
			scalar `v'_mult = `v'_mult + ($n_hh_treatall / $n_hh_treat * `r(estimate)')
			scalar multiplier_`type' = multiplier_`type' + ($n_hh_treatall / $n_hh_treat * `r(estimate)')

			forvalues q = $firstquarter(1)10{
				scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + ($n_hh_treatall / $n_hh_treat * `r(estimate)')/(11-$firstquarter)
			}

			disp "Control villages, investment: `ATEstring_spillover'"
			lincom "`ATEstring_spillover'" // this is per household in control villages, in fractions of the transfer
			scalar `v'_mult = `v'_mult + ($n_hh_treatall / $n_hh_treat * `r(estimate)')
			scalar multiplier_`type' = multiplier_`type' + ($n_hh_controlall / $n_hh_treat * `r(estimate)')

			forvalues q = $firstquarter(1)10{
				scalar multiplier_`type'_q`q' = multiplier_`type'_q`q' + ($n_hh_controlall / $n_hh_treat * `r(estimate)')/(11-$firstquarter)
			}

		}
	}

	foreach var in ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
		return scalar `var'_mult = `var'_mult
	}

	return scalar multiplier_`type' = multiplier_`type'

	forvalues q = $firstquarter(1)10{
		return scalar multiplier_`type'_q`q' = multiplier_`type'_q`q'
	}
}
end


** Prepare the bootstrap simulation **
*******************************************

foreach type in "exp" "inc"{

loc simulationstring = "`simulationstring' multiplier_`type' = r(multiplier_`type')"

foreach var in ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
		loc simulationstring = "`simulationstring' `var'_mult = r(`var'_mult)"
}

forvalues q = $firstquarter(1)10{
		loc simulationstring = "`simulationstring' multiplier_`type'_q`q' = r(multiplier_`type'_q`q')"
}

}

loc secs = `runtime' * `reps'
loc mins = round(`secs' / 60, 0.001)
loc hrs =  round(`mins' / 60, 0.1)


** Actually run the bootstrap simulation **
*******************************************

di "It is now $S_TIME, the current iteration is projected to be finished in `mins' minutes, or `hrs' hours."

simulate `simulationstring', reps(`reps') seed(12345): wildboot


** Output the bootstrap result **
*********************************
loc quartername ""
if $firstquarter != 1 loc quartername "_q${firstquarter}to10"

save "$dt/IRF_values/bootstrap_rawoutput_r`quartername'_withRarieda.dta", replace
project, creates("$dt/IRF_values/bootstrap_rawoutput_r`quartername'_withRarieda.dta") preserve
