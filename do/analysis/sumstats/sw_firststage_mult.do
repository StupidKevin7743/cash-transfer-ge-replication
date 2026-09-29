/*
 * Filename: multiplier_wildboot.do
 * Description: This do file computes the full deflated multiplier and applies the wild bootstrap to obtain standard errors
 * Author: Tilman Graff
 * Date created: 3 June 2020
 *
 */

/* Preliminaries */
/* do file header */
clear all
return clear
project, doinfo
disp _rc
if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
else {  // running directly
		if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
		do "${ge_dir}/do/set_environment.do"
}

* Import config - running globals
/* Note: it's unclear if this will actually do anything here, or if it will need to
	 be a part of each file */
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"


// end preliminaries
set varabbrev on
clear matrix
set maxvar 32000
set matsize 10000

cap log close
log using "$dl/SW_Multiplier_FirstStage_Clustered.txt", replace text


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
//global hhflowvar_inc p3_3_wageearnings_wins_r
global hhstockvar_inc
global entflowvar_inc ent_profit2_wins_r ent_rentcost_wins_r ent_totaltaxes_wins_r
global entstockvar_inc

//local outcomelist nondurables_exp_wins_r totval_hhassets_h_wins_r
cap postclose sw_results
postfile sw_results str32(outcome endog) str128(endog_list exog_list) str20(spec) double(swf ivest) str6(table) using "$dtab/SW_1stStage_Results_Mult.dta", replace

** Set type of standard errors for ivreg2 (clustered or not)
loc se "cluster(sublocation_code)"
//loc se ""

** d. Determine the optimal radii for all outcomes **
*****************************************************
use "$da/HH_ENT_Multiplier_Dataset_ECMA.dta", clear

** Generating some indicators **
cap tab quarter, gen(quarterI)
forval i=1/5 {
	gen quarterI`i'_el = quarterI`i' * eligible
}

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


************************************************
** 2. Multiplier calculations for first stage **
************************************************

*********************************
** a. Household flow variables **
*********************************

foreach type in "exp" "inc"{

if "${hhflowvar_`type'}" != "" {
	foreach v of var ${hhflowvar_`type'} {

		** i. eligible households **
		***************************
		estimates clear
		local rad = `v'_toptr // this is the optimal radius as determined above


		local timvar = "survey_mth"
	  local panvar = "hhid"

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
		local endog_list ""
		local exog_list ""
		forval i=1/10 {
			local endog_list = "`endog_list' pac_ownvill_r_q`i'"
			local exog_list = "`exog_list' t_share_actamt_ownvill_r_q`i'"
		}
		forval r = 2(2)`rad' {
			local r2 = `r' - 2
			forval i=1/10 {
				local endog_list = "`endog_list'" + " pac_ov_`r2'to`r'km_r_q`i'"
				local exog_list = "`exog_list'" + " t_share_actamt_ov_`r2'to`r'km_r_q`i'"
			}
		}

		ivreg2 `v' (`endog_list' = `exog_list') ibn.quarter `blvars' [aweight=hhweight_EL] if eligible == 1, nocons first `se'

		matrix A = e(first)
		matrix list A
		cap gen cons = 1

		** Posting results from this, given that we use clustered SEs for our main specification. **
		* postfile reference list: outcome endog str128(endog_list exog_list) spec swf ivest1 ivest2
		local table = 5 // multiplier table
		local j = 1
		** first, loop through own village terms
		forval i=1/10 {
			post sw_results ("`v'") ("pac_ownvill_r_q`i'") ("`endog_list'") ("`exog_list'") ("elig_flow") (A[8,`j']) (_b[pac_ownvill_r_q`i']) ("`table'")
			local ++j
		}
		** then, loop through other village terms **
		forval i=1/10 {
			post sw_results ("`v'") ("pac_ov_0to2km_r_q`i'") ("`endog_list'") ("`exog_list'") ("elig_flow") (A[8,`j']) (_b[pac_ov_0to2km_r_q`i']) ("`table'")
			local ++j
		}


		** ii. untreated households **
		******************************
		di "Start of untreated part"
		local rad = `v'_utoptr // this is the optimal radius as determined above

		estimates clear

		** add all buffer variables **
		local endregs = ""
		local exregs = ""
		forval r = 2(2)`rad' {
			local r2 = `r' - 2
			forval q=1/10 {
				local endregs = "`endregs'" + " pac_`r2'to`r'km_r_el_q`q' pac_`r2'to`r'km_r_in_q`q'"
				local exregs = "`exregs'" + " t_shr_actamt_`r2'to`r'km_r_el_q`q' t_shr_actamt_`r2'to`r'km_r_in_q`q'"
			}
		}


		ivreg2 `v' (`endregs' = `exregs') ibn.quarter#i.eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0), nocons first `se'

		matrix A = e(first)
		matrix list A
		loc num_endog = colsof(A)

		matrix beta = e(b)
		matrix list beta

		local j = 1
		foreach endvar of local endregs {
			if `j' <= `num_endog' {
			loc endog_cond = subinstr("`endregs'", "`endvar'", "", 1)
			cap drop res1
			cap drop res2

			ivreg2 `endvar' (`endog_cond'  = `exregs') ibn.quarter#i.eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0) & ~mi(`v')
			predict res1, r

			loc df_adjust_start = e(exexog_ct)

			reg res1 `exregs'  ibn.quarter#i.eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0) & ~mi(`v'), `se'
			test `exregs'
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
			scalar Fsw_cluster = `df_adjust'*r(F)
			di "S-W cluster F-stat:" Fsw_cluster
			di "IVReg cluster, full: " A[8,`j']

			** posting result **
			post sw_results ("`v'") ("`endvar'") ("`endog_cond'") ("`exregs'") ("nonrec_flow") (Fsw_cluster) (beta[1,`j']) ("`table'")

		}
			loc ++j
		}

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
		estimates clear

		local rad = `v'_toptr // this is the optimal radius as determined above

		loc endog_list = "pac_ownvill_r"
		loc exog_list = "treat"
		forval r=2(2)`rad'{
			loc r2 = `r'-2
			loc endog_list "`endog_list' pac_ov_`r2'to`r'km_r"
			loc exog_list "`exog_list' share_ge_elig_treat_ov_`r2'to`r'km"
		}


		ivreg2 `v' (`endog_list' = `exog_list') `blvars' [aweight=hhweight_EL] if eligible == 1,  first `se'

		matrix A = e(first)
		matrix list A

		local table = 5 // multiplier table
		** first, own village terms
		post sw_results ("`v'") ("pac_ownvill_r") ("`endog_list'") ("`exog_list'") ("elig_stock") (A[8,1]) (_b[pac_ownvill_r]) ("`table'")

		** then, for other village terms **
		post sw_results ("`v'") ("pac_ov_0to2km_r") ("`endog_list'") ("`exog_list'") ("elig_stock") (A[8,2]) (_b[pac_ov_0to2km_r]) ("`table'")


		** ii. untreated households **
		******************************
		estimates clear
		local rad = `v'_utoptr // this is the optimal radius as determined above
		local rad2 = `rad' - 2

		local endregs_el = ""
		local exregs_el = ""
		local endregs_in = ""
		local exregs_in = ""

		forval r = 2(2)`rad' {
			local r2 = `r' - 2
			cap ren pac_`r2'to`r'km_r_eligible pac_`r2'to`r'km_r_el
			cap ren pac_`r2'to`r'km_r_ineligible pac_`r2'to`r'km_r_in

			local endregs_el = "`endregs_el'" + " pac_`r2'to`r'km_r_el"
			local exregs_el = "`exregs_el'" + " share_ge_elig_treat_`r2'to`r'km_el"
			local endregs_in = "`endregs_in'" + " pac_`r2'to`r'km_r_in"
			local exregs_in = "`exregs_in'" + " share_ge_elig_treat_`r2'to`r'km_in"
		}

		loc endregs "`endregs_el' `endregs_in'"
		loc exregs "`exregs_el' `exregs_in'"

		ivreg2 `v' (`endregs' = `exregs') eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0), `se' first

		matrix A = e(first)
		matrix list A
		loc num_endog = colsof(A)

		matrix beta = e(b)
		matrix list beta

		local j = 1
		foreach endvar of local endregs {
			if `j' <= `num_endog' {
			loc endog_cond = subinstr("`endregs'", "`endvar'", "", 1)
			cap drop res1
			cap drop res2

			ivreg2 `endvar' (`endog_cond'  = `exregs') eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0) & ~mi(`v')
			predict res1, r

			loc df_adjust_start = e(exexog_ct)

			reg res1 `exregs'  eligible `blvars_untreat' [aweight=hhweight_EL] if (eligible == 0 | treat == 0) & ~mi(`v'), `se'
			test `exregs'
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
			scalar Fsw_cluster = `df_adjust'*r(F)
			di "S-W cluster F-stat:" Fsw_cluster
			di "IVReg cluster, full: " A[8,`j']

			** posting result **
			post sw_results ("`v'") ("`endvar'") ("`endog_cond'") ("`exregs'") ("nonrec_stock") (Fsw_cluster) (beta[1,`j']) ("`table'")

		}
			loc ++j
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

		** Generate enterprise indicators **
		estimates clear

		cap drop ent_type?
		forval i = 1/3 {
		  gen ent_type`i' = (ent_type == `i') if ~mi(ent_type)
		}

		** add all buffer variables **
		if inlist("`v'", "ent_inventory_wins_r", "ent_inv_wins_r", "ent_totaltaxes_wins_r") {
		  local max_enttype = 2
		}
		else {
		  loc max_enttype = 3
		}

		local endregs ""
		local exregs ""

		* Own village / enterprise type interactions
			forval q = 1(1)10 {
				forval i = 1 / `max_enttype' {
					cap gen pac_ownvill_r_q`q'_ent`i' = pac_ownvill_r_q`q' * ent_type`i'
					local endregs = "`endregs'" + " pac_ownvill_r_q`q'_ent`i'"

					cap gen t_s_actamt_ownvill_r_q`q'_ent`i' = t_share_actamt_ownvill_r_q`q' * ent_type`i'
					local exregs = "`exregs'" + " t_s_actamt_ownvill_r_q`q'_ent`i'"
				}

			* Other village / enterprise type interactions
			forval r = 2(2)`rad' {
					local r2 = `r' - 2
					forval i = 1 / `max_enttype' {
						cap gen pac_ov_`r2'to`r'km_r_q`q'_ent`i' = pac_ov_`r2'to`r'km_r_q`q' * ent_type`i'
						cap gen t_s_actamt_ov_`r2'to`r'km_r_q`q'_ent`i' = t_share_actamt_ov_`r2'to`r'km_r_q`q' * ent_type`i'
						local endregs = "`endregs'" + " pac_ov_`r2'to`r'km_r_q`q'_ent`i'"
						local exregs = "`exregs'" + " t_s_actamt_ov_`r2'to`r'km_r_q`q'_ent`i'"
					}
					}
			}

		di "Endogenous regressors:"
		di "`endregs'"
		di "Exogenous regressors:"
		di "`exregs'"

		di "*********Ent flow regression -- all enterprise types *******"

			ivreg2 `v' (`endregs' = `exregs') ibn.quarter#i.ent_type `vblvars' [aweight=entweight_EL], `se' first

		matrix A = e(first)
		matrix list A
		loc num_endog = colsof(A)

		matrix beta = e(b)
		matrix list beta

		local j = 1
		foreach endvar of local endregs {
			if `j' <= `num_endog' {
			loc endog_cond = subinstr("`endregs'", "`endvar'", "", 1)
			cap drop res1
			cap drop res2
			di "Endvar: `endvar'"
			di "Endog cond: `endog_cond'"
			di "Exregs: `exregs'"

		  ivreg2 `endvar' (`endog_cond'  = `exregs') ibn.quarter#i.ent_type `vblvars' [aweight=entweight_EL] if ~mi(`v')
		  predict res1, r

			loc df_adjust_start = e(exexog_ct)
			di "DF adjust start: `df_adjust_start'"

			di "Regressing residuals"
		  reg res1 `exregs'  ibn.quarter#i.ent_type `vblvars' [aweight=entweight_EL] if ~mi(`v'), `se'
		  test `exregs'
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
		  scalar Fsw_cluster = `df_adjust'*r(F)
		  di "S-W cluster F-stat:" Fsw_cluster
		  di "IVReg cluster, full: " A[8,`j']

			** posting result **
			post sw_results ("`v'") ("`endvar'") ("`endog_cond'") ("`exregs'") ("ent_flow") (Fsw_cluster) (beta[1,`j']) ("`table'")

		}
			loc ++j
		}


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

		** Generate enterprise indicators **
		cap drop ent_type?

		** add all buffer variables **
		if inlist("`v'", "ent_inventory_wins_r", "ent_inv_wins_r", "ent_totaltaxes_wins_r") {
		  local max_enttype = 2
		}
		else {
		  loc max_enttype = 3
		}

		local endregs ""
		local exregs ""


		forval i = 1/`max_enttype' {
			gen ent_type`i' = (ent_type == `i') if ~mi(ent_type)
			cap gen pac_ownvill_r_ent`i' = pac_ownvill_r * ent_type`i'
			cap gen treat_ent`i' = treat * ent_type`i'

			local endregs_ent`i' = "pac_ownvill_r_ent`i'"
			local exregs_ent`i' = "treat_ent`i'"

		forval r = 2(2)`rad' {
			local r2 = `r' - 2
				cap gen pac_ov_`r2'to`r'km_r_ent`i' = pac_ov_`r2'to`r'km_r * ent_type`i'
				cap gen s_ge_elig_treat_ov_`r2'to`r'km_ent`i' = share_ge_elig_treat_ov_`r2'to`r'km * ent_type`i'

				local endregs_ent`i' = "`endregs_ent`i''" + " pac_ov_`r2'to`r'km_r_ent`i'"
				local exregs_ent`i' = "`exregs_ent`i''" + " s_ge_elig_treat_ov_`r2'to`r'km_ent`i'"
			}
		}

		local endregs "`endregs_ent1' `endregs_ent2' `endregs_ent3'"
		local exregs "`exregs_ent1' `exregs_ent2' `exregs_ent3'"

		di "** Full regression **"
		ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL], `se' first

		matrix A = e(first)
		matrix list A
		local num_endog = colsof(A)

		matrix beta = e(b)
		matrix list beta

		local j = 1
		foreach endvar of local endregs {
			if `j' <= `num_endog' {
			loc endog_cond = subinstr("`endregs'", "`endvar'", "", 1)
			cap drop res1
			cap drop res2

		  ivreg2 `endvar' (`endog_cond'  = `exregs') ibn.quarter#i.ent_type `vblvars' [aweight=entweight_EL] if ~mi(`v')
		  predict res1, r

		  loc df_adjust_start = e(exexog_ct)

		  reg res1 `exregs'  ibn.quarter#i.ent_type `vblvars' [aweight=entweight_EL] if ~mi(`v'), `se'
		  test `exregs'
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
		  scalar Fsw_cluster = `df_adjust'*r(F)
		  di "S-W cluster F-stat:" Fsw_cluster
		  di "IVReg cluster, full: " A[8,`j']

			** posting result **
			post sw_results ("`v'") ("`endvar'") ("`endog_cond'") ("`exregs'") ("ent_stock") (Fsw_cluster) (beta[1, `j']) ("`table'")

		}
			loc ++j
		}

	}
}

}


postclose sw_results

** Checking and developing stats **
use "$dtab/SW_1stStage_Results_Mult.dta", clear

summarize // min of 88.5
bys spec: summ swf

log close
