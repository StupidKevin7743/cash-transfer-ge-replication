/*
 * Filename: multiplier_tables.do
 * Description: This .do file takes raw outputs from bootstraps and creates final table
 * Author: Dennis Egger
 * Date created: 10 July 2019
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

// end preliminaries
project, original("$do/analysis/multiplier/multiplier_setreps.do")
include "$do/analysis/multiplier/multiplier_setreps.do"


** Set import shares **
include "$dir/do/analysis/multiplier/ImportShares_globals_TablesD1_D2.do"
// this .do file calculates import shares for non-durable expenditure and assets
// it sets four globals:
// share_import_durables - share of durable purchases imported
// share_import_nondurables - share of non-durable purchases imported
// share_int_import_durables - share of intermediates in durables imported
// share_int_import_nondurables - share of intermediates in non-durables imported

local bootreps = $bootstrap_reps


** set up columns **
********************
preserve
clear
qui set obs 10
gen x = 1
gen y = 1

forvalues x1 = 1/3 {
	qui eststo col`x1': reg x y
	qui eststo col_adj_`x1': reg x y
	qui eststo col_adj_rar_`x1': reg x y
}
forvalues x1 = 1/6 {
	qui eststo col_rob`x1': reg x y
}
local varcount = 1
restore


** Load multiplier estimates **
*******************************
project, uses("$dt/multiplier_estimates.dta")
use "$dt/multiplier_estimates.dta", clear
keep if type == "joint"
gen mean_mult = (multiplier_inc + multiplier_exp) / 2
order deflated withRarieda quarter mean_mult
drop *_l *_h type rar_*

/*
expand 2 if quarter == 99, gen(dupl)
replace quarter = 98 if dupl == 1
drop dupl
foreach v of var mean_mult multiplier_exp multiplier_inc ent_inventory_wins ent_inv_wins ent_profit2_wins ent_rentcost_wins ent_totaltaxes_wins p2_exp_mult_wins p3_3_wageearnings_wins totval_hhassets_wins {
	gen a = `v' if inrange(quarter,4,10)
	bys deflated withRarieda: egen b = sum(a)
	replace `v' = b if quarter == 98
	drop a b
}
*/

sort deflated withRarieda quarter
keep if (quarter == 99 & deflated == 1 & withRarieda == 0) /// real version
| (quarter == 99 & deflated == 0 & withRarieda == 0) /// nominal version
| (quarter == 98 & deflated == 1 & withRarieda == 0) /// real version, q4 - q10
| (quarter == 99 & deflated == 1 & withRarieda == 1) /// real version, first quarters from Rarieda
| (deflated == 1 & withRarieda == 0) // all quarters without Rarieda

foreach v of var mean_mult multiplier_exp multiplier_inc ent_inventory_wins ent_inv_wins ent_profit2_wins ent_rentcost_wins ent_totaltaxes_wins nondurables_exp_wins p3_3_wageearnings_wins totval_hhassets_h_wins {
	gen `v'_r_q4to10 = `v' if deflated == 1 & withRarieda == 0 & quarter == 98
	gen `v'_r = `v' if deflated == 1 & withRarieda == 0 & quarter == 99
	gen `v'_r_wrar = `v' if deflated == 1 & withRarieda == 1 & quarter == 99

	forval i = 1/10 {
		gen `v'_q`i' = `v' if deflated == 1 & withRarieda == 0 & quarter == `i'
		gen `v'_r_q`i' = `v' if deflated == 1 & withRarieda == 0 & quarter == `i'
		replace `v' = . if deflated == 1 & withRarieda == 0 & quarter == `i'
	}
	replace `v' = . if deflated == 1 & inlist(quarter,98,99)
}

drop deflated withRarieda quarter


collapse _all

foreach v of var _all {
	scalar `v' = `v'[1]
}


** Set multiplier components **
*******************************

** Expenditure multiplier **
*global hhflowvar_exp p2_exp_mult_wins
global hhflowvar_exp nondurables_exp_wins
*global hhstockvar_exp totval_hhassets_wins
global hhstockvar_exp totval_hhassets_h_wins
global entflowvar_exp ent_inv_wins
global entstockvar_exp ent_inventory_wins

** Income multiplier **
global hhflowvar_inc p3_3_wageearnings_wins
global hhstockvar_inc
global entflowvar_inc ent_profit2_wins ent_rentcost_wins ent_totaltaxes_wins
global entstockvar_inc

** Labels **
mata {
	lab_clean = ( ///
	/* "p2_exp_mult_wins", */ ///
	"nondurables_exp_wins", ///
	/* "totval_hhassets_wins", */ ///
	"totval_hhassets_h_wins", ///
	"ent_inv_wins", ///
	"ent_inventory_wins", ///
	"p3_3_wageearnings_wins", ///
	"ent_profit2_wins", ///
	"ent_rentcost_wins", ///
	"ent_totaltaxes_wins")

	lab_clean = lab_clean\( ///
	"Household non-durable expenditure", ///
	"Household durable expenditure", ///
	"Enterprise investment", ///
	"Enterprise inventory", ///
	"Household wage bill", ///
	"Enterprise profits", ///
	"Enterprise capital income", ///
	"Enterprise taxes paid")
}

*******************************************
** I. Main Table - Deflated with details **
*******************************************

** Input the bootstrap results -- main results (deflated) **
************************************************************
project, uses("$dt/IRF_values/bootstrap_rawoutput_r.dta")
use "$dt/IRF_values/bootstrap_rawoutput_r.dta", clear
local reps = _N
drop *_q? *_q??
gen mean_mult_r = (multiplier_exp + multiplier_inc)/2
order mean_mult_r

loc bstatstring = "mean_mult_r"
loc full_estimates = "mean_mult_r"

foreach type in "exp" "inc"{

	foreach var in multiplier_`type' ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
		if "`var'" == "multiplier_`type'"   loc bstatstring = "`bstatstring' multiplier_`type'"
		else 								loc bstatstring = "`bstatstring' `var'_r_mult"

		loc full_estimates = "`full_estimates', `var'_r"
}
}

disp "`bstatstring'"
disp "`full_estimates'"

matrix full_estimates = `full_estimates'
bstat `bstatstring', stat(full_estimates)


** Output tex table **
**********************
loc rowcount = 1
loc rowcount1 = `rowcount'+1
loc statnames = ""

foreach type in "exp" "inc"{

	** sort coefficients in descending order **
	*******************************************
	mata: coefs = .
	mata: labs = ""
	foreach var in ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
		local coef = _b[`var'_r_mult]
		mata: coefs = coefs,`coef'
		mata: labs = labs,"`var'"
	}
	mata {
		coefs = coefs[1,2..length(coefs)]\(1..length(coefs)-1)
		coefs = sort(coefs',-1)'
		labs = labs[1,2..length(labs)]
		st_numscalar("numcomp",length(labs))
	}
	local components_`type' = ""
	local num = numcomp
	forval i = 1/`num' {
		mata: st_local("comp",labs[1,coefs[2,`i']])
		local components_`type' = "`components_`type''" + "`comp' "
	}

	disp "`components_`type''"

	** Now fill tex table **
	************************
	loc varlabels_`type' ""
	loc varlabels2_`type' ""

	foreach var in multiplier_`type' `components_`type'' {
		disp "Going through component: `var'"
		if "`var'" == "multiplier_`type'"   loc varname = "multiplier_`type'"
		else 								loc varname = "`var'_r_mult"

		pstar `varname', pstar
		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(bstar)'": col1
		else								estadd local thisstat`rowcount' = "`r(bstar)'": col1

		estadd local thisstat`rowcount1' = "`r(sestar)'": col1

		qui count if `varname' < 0
		loc pval = `r(N)' / `reps'

		pstar, p(`pval') prec(2) pstar pnopar
		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(pstar)'": col2
		else								estadd local thisstat`rowcount' = "`r(pstar)'": col2

		qui count if `varname' < 1
		loc pval = `r(N)' / `reps'

		pstar, p(`pval') prec(2) pstar pnopar
		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(pstar)'": col3
		else								estadd local thisstat`rowcount' = "": col3

		loc statnames = "`statnames' thisstat`rowcount' thisstat`rowcount1'"

		loc rowcount = `rowcount' + 2
		loc rowcount1 = `rowcount'+1

		if "`var'" != "multiplier_`type'" {
			mata: st_local("lclean",select(lab_clean[2,.], (lab_clean[1,.] :== "`var'")))
			loc varlabels_`type' "`varlabels_`type'' `"\addlinespace \hspace{1em}`lclean'"' " ""
			loc varlabels_2_`type' "`varlabels_2_`type'' `"\addlinespace \hspace{1em}`lclean'"'"
		}
	}
}

** add average multiplier **
pstar mean_mult_r, pstar
estadd local thisstat`rowcount' = "`r(bstar)'": col1
estadd local thisstat`rowcount1' = "`r(sestar)'": col1

qui count if mean_mult_r < 0
loc avgnull = (`r(N)'/`reps')
pstar, p(`avgnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col2

qui count if mean_mult_r < 1
loc avgnull = (`r(N)'/`reps')
pstar, p(`avgnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col3

loc statnames = "`statnames' thisstat`rowcount' thisstat`rowcount1'"

** add joint test **
loc rowcount = `rowcount' + 2

qui count if multiplier_exp < 0 & multiplier_inc < 0
loc jointnull = (`r(N)'/`reps')

pstar, p(`jointnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col2

qui count if multiplier_exp < 1 & multiplier_inc < 1
loc jointnull = (`r(N)'/`reps')

pstar, p(`jointnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col3

loc statnames = "`statnames' thisstat`rowcount'"

loc varlabels "`"\addlinespace \textit{Panel A: Expenditure multiplier}"' " " `varlabels_exp' `"\addlinespace \textit{Panel B: Income multiplier}"' " " `varlabels_inc' `" \addlinespace \textit{Panel C: Expenditure and income multipliers} & & & \\ \addlinespace Average of both multipliers"' " " `"\addlinespace Joint test of both multipliers"' "
*loc varlabels "`"\addlinespace \textit{Panel A: Expenditure multiplier}"' " " `"\addlinespace \hspace{1em}Household consumption"' " "  `"\addlinespace \hspace{1em}Household assets"' " " `"\addlinespace \hspace{1em}Enterprise investment"' " "  `"\addlinespace \hspace{1em}Enterprise inventory"' " " `"\addlinespace \hline \addlinespace \textit{Panel B: Income multiplier}"' " " `"\addlinespace \hspace{1em}Household wage bill"' " "  `"\addlinespace \hspace{1em}Enterprise profits"' " " `"\addlinespace \hspace{1em}Enterprise capital income"' " "  `"\addlinespace \hspace{1em}Enterprise taxes paid"' " " `"\addlinespace \hline \addlinespace \textit{Average of both multipliers}"' " " `"\addlinespace Joint test of both multipliers"' "

loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{3}{S[detect-weight, mode=text]}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

qui esttab col? ///
	using "$dtab/Table5_Multiplier.tex", ///
	cells(none) alignment(SSSS) replace compress stats(`statnames', ///
	labels(`varlabels')) label ///
	mtitle("\shortstack{$\mathbb{M}$\\Estimate}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 0\\ \textit{p}-value}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 1\\ \textit{p}-value}") prehead(`prehead') postfoot(`postfoot')

disp "`components_exp'"

***************************************************************
** II. Robustness Table - Adjusting for imports and exports **
***************************************************************

***************************
** II.a. Without Rarieda **
***************************
loc rowcount = 1
loc statnames = ""

** Calculate overall share of effect imported **
local nondurables_impshare_disp : di %3.2f $share_import_nondurables
local durables_impshare_disp : di %3.2f $share_import_durables

** Calculate overall share of intermediates that are imported
** weighted average of durables and non-durables -- weights being effect sizes **
cap local eff_nondurable = _b[p2_exp_mult_wins_r_mult]
cap local eff_nondurable = _b[nondurables_exp_wins_r_mult]
cap	local eff_durable = _b[totval_hhassets_wins_r_mult]
cap local eff_durable = _b[totval_hhassets_h_wins_r_mult]

global share_int_import = (`eff_durable'*$share_int_import_durables + `eff_nondurable'*$share_int_import_nondurables)/(`eff_durable' + `eff_nondurable')
local int_impshare_disp : di %3.2f $share_int_import

** Calculate overall share of multiplier effect that is imported
** Weights being effect sizes **
local eff_inv = _b[ent_inv_wins_r_mult]
local eff_inventory = _b[ent_inventory_wins_r_mult]

global share_import = (`eff_nondurable' * $share_import_nondurables + `eff_durable' * $share_import_durables + `eff_inv' * $share_import_durables + `eff_inventory' * $share_int_import) / (`eff_nondurable' + `eff_durable' + `eff_inv' + `eff_inventory')
local overall_impshare_disp : di %3.2f $share_import

local exp_impshare_disp : di

foreach type in "exp" {
	foreach var in multiplier_`type' `components_`type'' {
		if "`var'" == "multiplier_`type'"   loc varname = "multiplier_`type'"
		else 								loc varname = "`var'_r_mult"

		loc varname_loc = string(round(_b[`varname'], 0.01), "%13.2f")

		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`varname_loc'": col_adj_1
		else								estadd local thisstat`rowcount' = "`varname_loc'": col_adj_1


		*** Shares
		if "`varname'" == "multiplier_`type'"    		estadd local thisstat`rowcount' = "`overall_impshare_disp'": col_adj_2

		if inlist("`varname'", "p2_exp_mult_wins_r_mult", "nondurables_exp_wins_r_mult")  		estadd local thisstat`rowcount' = "`nondurables_impshare_disp'": col_adj_2
		if inlist("`varname'", "totval_hhassets_wins_r_mult", "totval_hhassets_h_wins_r_mult")	estadd local thisstat`rowcount' = "`durables_impshare_disp'": col_adj_2
		if "`varname'" == "ent_inv_wins_r_mult"  												estadd local thisstat`rowcount' = "`durables_impshare_disp'": col_adj_2
		if "`varname'" == "ent_inventory_wins_r_mult"   										estadd local thisstat`rowcount' = "`int_impshare_disp'": col_adj_2


		*** Adjusted
		if "`varname'" == "multiplier_`type'"    		loc adjusted = (1-$share_import)*_b[`varname']

		if inlist("`varname'", "p2_exp_mult_wins_r_mult", "nondurables_exp_wins_r_mult")  	    	loc adjusted = (1-$share_import_nondurables)*_b[`varname']
		if inlist("`varname'", "totval_hhassets_wins_r_mult", "totval_hhassets_h_wins_r_mult")		loc adjusted = (1-$share_import_durables)*_b[`varname']
		if "`varname'" == "ent_inv_wins_r_mult"  													loc adjusted = (1-$share_import_durables)*_b[`varname']
		if "`varname'" == "ent_inventory_wins_r_mult"   											loc adjusted = (1-$share_int_import)*_b[`varname']

		loc adjusted : di %3.2f `adjusted'

		if "`varname'" == "multiplier_`type'" 			estadd local thisstat`rowcount' = "`adjusted'": col_adj_3
		else											estadd local thisstat`rowcount' = "`adjusted'": col_adj_3

		loc statnames = "`statnames' thisstat`rowcount'"

		loc rowcount = `rowcount' + 1
	}
}

loc varlabels2 "`"\addlinespace \textit{Panel A: Expenditure multiplier}"' `varlabels_2_exp' "

loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{3}{S[detect-weight, mode=text]}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

qui esttab col_adj_? ///
	using "$dtab/TableD3_MultiplierAdjusted.tex", ///
	cells(none) alignment(SSSS) replace compress stats(`statnames', ///
	labels(`varlabels2')) label ///
	mtitle("\shortstack{$\mathbb{M}$\\Estimate}" "\shortstack{Share\\ imported}" "\shortstack{Import \\ adjusted}") prehead(`prehead') postfoot(`postfoot')

	
***************************************
** Test for equality across quarters **
***************************************
project, uses("$dt/IRF_values/bootstrap_rawoutput_r.dta")
use "$dt/IRF_values/bootstrap_rawoutput_r.dta", clear
local reps = _N

loc bstatstring = ""
loc full_estimates = ""

foreach type in "exp" "inc"{
		loc teststat_`type' = ""

		loc bstatstring = "`bstatstring' multiplier_`type'"
		if "`full_estimates'" == "" loc full_estimates = "multiplier_`type'_r"
		else loc full_estimates = "`full_estimates', multiplier_`type'_r"

		forval i = 1/10 {
			if `i' == 1 loc teststat_`type' = "multiplier_`type'_q`i'"
			else loc teststat_`type' = "`teststat_`type'' = multiplier_`type'_q`i'"
			loc bstatstring = "`bstatstring' multiplier_`type'_q`i'"
			loc full_estimates = "`full_estimates', multiplier_`type'_r_q`i'"
		}
}

disp "`bstatstring'"
disp "`full_estimates'"

log using "$dtab/../multiplier_tests", replace
matrix full_estimates = `full_estimates'
bstat `bstatstring', stat(full_estimates)

disp "`teststat_exp'"
test `teststat_exp'
test `teststat_inc'
test multiplier_exp = multiplier_inc
log close


*************************************************************
** III. Robustness Table - Dropping first quarters + Rarieda **
**************************************************************
local numchecks = 0
foreach robcheck in "dropinitial" "withRarieda" /*"nominal"*/ {

	** Input the bootstrap results **
	*********************************
	if "`robcheck'" == "dropinitial" {
		project, uses("$dt/IRF_values/bootstrap_rawoutput_r_q4to10.dta")
		use "$dt/IRF_values/bootstrap_rawoutput_r_q4to10.dta", clear
	}

	if "`robcheck'" == "withRarieda" {
		project, uses("$dt/IRF_values/bootstrap_rawoutput_r_withRarieda.dta")
		use "$dt/IRF_values/bootstrap_rawoutput_r_withRarieda.dta", clear
	}

	if "`robcheck'" == "nominal" {
		project, uses("$dt/IRF_values/bootstrap_rawoutput.dta")
		use "$dt/IRF_values/bootstrap_rawoutput.dta", clear
	}

	local reps = _N
	drop *_q? *_q??
	gen mean_mult = (multiplier_exp + multiplier_inc)/2
	order mean_mult

	loc bstatstring = "mean_mult"

	if "`robcheck'" == "dropinitial" 	loc full_estimates = "mean_mult_r_q4to10"
	if "`robcheck'" == "withRarieda" 	loc full_estimates = "mean_mult_r_wrar"
	if "`robcheck'" == "nominal" 		loc full_estimates = "mean_mult"

	foreach type in "exp" "inc"{

		foreach var in multiplier_`type' ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
			if "`var'" == "multiplier_`type'"   loc bstatstring = "`bstatstring' multiplier_`type'"
			if ("`robcheck'" == "dropinitial" & "`var'" != "multiplier_`type'") loc bstatstring = "`bstatstring' `var'_r_mult"
			if ("`robcheck'" == "withRarieda" & "`var'" != "multiplier_`type'") loc bstatstring = "`bstatstring' `var'_r_mult"
			if ("`robcheck'" == "nominal" & "`var'" != "multiplier_`type'") loc bstatstring = "`bstatstring' `var'_mult"

			if "`robcheck'" == "dropinitial" 	loc full_estimates = "`full_estimates', `var'_r_q4to10"
			if "`robcheck'" == "withRarieda" 	loc full_estimates = "`full_estimates', `var'_r_wrar"
			if "`robcheck'" == "nominal" 	loc full_estimates = "`full_estimates', `var'"
	}
	}

	disp "`bstatstring'"
	disp "`full_estimates'"
	foreach v in `full_estimates' {
		disp `v'
	}

	matrix full_estimates = `full_estimates'
	bstat `bstatstring', stat(full_estimates)


	** Output tex table **
	**********************
	loc rowcount = 1
	loc rowcount1 = `rowcount'+1

	local colnum1 = `numchecks'*3+1
	local colnum2 = `numchecks'*3+2
	local colnum3 = `numchecks'*3+3

	loc statnames = ""

	foreach type in "exp" "inc"{
		foreach var in multiplier_`type' `components_`type'' { // use same order as for the main estimates

			disp "Going through component: `var'"
			if "`var'" == "multiplier_`type'"   loc varname = "multiplier_`type'"

			if ("`robcheck'" == "dropinitial" & "`var'" != "multiplier_`type'") loc varname = "`var'_r_mult"
			if ("`robcheck'" == "withRarieda" & "`var'" != "multiplier_`type'") loc varname = "`var'_r_mult"
			if ("`robcheck'" == "nominal" & "`var'" != "multiplier_`type'") loc varname = "`var'_mult"

			pstar `varname', pstar
			if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(bstar)'": col_rob`colnum1'
			else								estadd local thisstat`rowcount' = "`r(bstar)'": col_rob`colnum1'

			estadd local thisstat`rowcount1' = "`r(sestar)'": col_rob`colnum1'

			qui count if `varname' < 0
			loc pval = `r(N)' / `reps'

			pstar, p(`pval') prec(2) pstar pnopar
			if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(pstar)'": col_rob`colnum2'
			else								estadd local thisstat`rowcount' = "`r(pstar)'": col_rob`colnum2'

			qui count if `varname' < 1
			loc pval = `r(N)' / `reps'

			pstar, p(`pval') prec(2) pstar pnopar
			if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(pstar)'": col_rob`colnum3'
			else								estadd local thisstat`rowcount' = "": col_rob`colnum3'

			loc statnames = "`statnames' thisstat`rowcount' thisstat`rowcount1'"

			loc rowcount = `rowcount' + 2
			loc rowcount1 = `rowcount'+1
		}
	}

	** add average multiplier **
	pstar mean_mult, pstar
	estadd local thisstat`rowcount' = "`r(bstar)'": col_rob`colnum1'
	estadd local thisstat`rowcount1' = "`r(sestar)'": col_rob`colnum1'

	qui count if mean_mult < 0
	loc avgnull = (`r(N)'/`reps')
	pstar, p(`avgnull') prec(2) pstar pnopar
	estadd local thisstat`rowcount' = "`r(pstar)'": col_rob`colnum2'

	qui count if mean_mult < 1
	loc avgnull = (`r(N)'/`reps')
	pstar, p(`avgnull') prec(2) pstar pnopar
	estadd local thisstat`rowcount' = "`r(pstar)'": col_rob`colnum3'

	loc statnames = "`statnames' thisstat`rowcount' thisstat`rowcount1'"

	** add joint test **
	loc rowcount = `rowcount' + 2

	qui count if multiplier_exp < 0 & multiplier_inc < 0
	loc jointnull = (`r(N)'/`reps')

	pstar, p(`jointnull') prec(2) pstar pnopar
	estadd local thisstat`rowcount' = "`r(pstar)'": col_rob`colnum2'

	qui count if multiplier_exp < 1 & multiplier_inc < 1
	loc jointnull = (`r(N)'/`reps')

	pstar, p(`jointnull') prec(2) pstar pnopar
	estadd local thisstat`rowcount' = "`r(pstar)'": col_rob`colnum3'

	loc statnames = "`statnames' thisstat`rowcount'"

	local numchecks = `numchecks' + 1
}

loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{lS[detect-weight, mode=text]*{4}{S[detect-weight, mode=text]}*{4}{S[detect-weight, mode=text]}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

disp "`statnames'"
qui esttab col1 col_rob? ///
	using "$dtab/TableD4_MultiplierRobustness.tex", ///
	cells(none) alignment(SSSSSSSS) replace compress stats(`statnames', ///
	labels(`varlabels')) label extracols(2 5) ///
	mtitle("\shortstack{\\ \textbf{Main} \\ \textbf{estimate}}} & & \multicolumn{3}{c}{\shortstack{\\ \textbf{Alternative Specification I:} \\ \textbf{Setting initial 3 quarters $ = 0$}}} & &  \multicolumn{3}{c}{\shortstack{\\ \textbf{Alternative Specification II} \\ \textbf{Initial 3 quarters from} \\ \textbf{Haushofer \& Shapiro (2016)}}} \\ \cline{2-2}\cline{4-6}\cline{8-10} \\ & \multicolumn{1}{c}{" ///
	"\shortstack{$\mathbb{M}$\\Estimate}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 0\\ \textit{p}-value}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 1\\ \textit{p}-value}" "\shortstack{$\mathbb{M}$\\Estimate}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 0\\ \textit{p}-value}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 1\\ \textit{p}-value}") prehead(`prehead') postfoot(`postfoot')


*****************************************************
** II.b. Import share adjustments + adding Rarieda **
*****************************************************
loc rowcount = 1
loc statnames = ""

** Calculate overall share of effect imported **
local nondurables_impshare_disp : di %3.2f $share_import_nondurables
local durables_impshare_disp : di %3.2f $share_import_durables

** Calculate overall share of intermediates that are imported
** weighted average of durables and non-durables -- weights being effect sizes **
cap local eff_nondurable = _b[p2_exp_mult_wins_r_mult]
cap local eff_nondurable = _b[nondurables_exp_wins_r_mult]
cap	local eff_durable = _b[totval_hhassets_wins_r_mult]
cap local eff_durable = _b[totval_hhassets_h_wins_r_mult]

global share_int_import = (`eff_durable'*$share_int_import_durables + `eff_nondurable'*$share_int_import_nondurables)/(`eff_durable' + `eff_nondurable')
local int_impshare_disp : di %3.2f $share_int_import

** Calculate overall share of multiplier effect that is imported
** Weights being effect sizes **
local eff_inv = _b[ent_inv_wins_r_mult]
local eff_inventory = _b[ent_inventory_wins_r_mult]

global share_import = (`eff_nondurable' * $share_import_nondurables + `eff_durable' * $share_import_durables + `eff_inv' * $share_import_durables + `eff_inventory' * $share_int_import) / (`eff_nondurable' + `eff_durable' + `eff_inv' + `eff_inventory')
local overall_impshare_disp : di %3.2f $share_import

local exp_impshare_disp : di

foreach type in "exp" {
	foreach var in multiplier_`type' `components_`type'' {
		if "`var'" == "multiplier_`type'"   loc varname = "multiplier_`type'"
		else 								loc varname = "`var'_r_mult"

		loc varname_loc = string(round(_b[`varname'], 0.01), "%13.2f")

		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`varname_loc'": col_adj_rar_1
		else								estadd local thisstat`rowcount' = "`varname_loc'": col_adj_rar_1


		*** Shares
		if "`varname'" == "multiplier_`type'"    		estadd local thisstat`rowcount' = "`overall_impshare_disp'": col_adj_rar_2

		if inlist("`varname'", "p2_exp_mult_wins_r_mult", "nondurables_exp_wins_r_mult")  		estadd local thisstat`rowcount' = "`nondurables_impshare_disp'": col_adj_rar_2
		if inlist("`varname'", "totval_hhassets_wins_r_mult", "totval_hhassets_h_wins_r_mult")	estadd local thisstat`rowcount' = "`durables_impshare_disp'": col_adj_rar_2
		if "`varname'" == "ent_inv_wins_r_mult"  												estadd local thisstat`rowcount' = "`durables_impshare_disp'": col_adj_rar_2
		if "`varname'" == "ent_inventory_wins_r_mult"   										estadd local thisstat`rowcount' = "`int_impshare_disp'": col_adj_rar_2


		*** Adjusted
		if "`varname'" == "multiplier_`type'"    		loc adjusted = (1-$share_import)*_b[`varname']

		if inlist("`varname'", "p2_exp_mult_wins_r_mult", "nondurables_exp_wins_r_mult")  	    	loc adjusted = (1-$share_import_nondurables)*_b[`varname']
		if inlist("`varname'", "totval_hhassets_wins_r_mult", "totval_hhassets_h_wins_r_mult")		loc adjusted = (1-$share_import_durables)*_b[`varname']
		if "`varname'" == "ent_inv_wins_r_mult"  													loc adjusted = (1-$share_import_durables)*_b[`varname']
		if "`varname'" == "ent_inventory_wins_r_mult"   											loc adjusted = (1-$share_int_import)*_b[`varname']

		loc adjusted : di %3.2f `adjusted'

		if "`varname'" == "multiplier_`type'" 			estadd local thisstat`rowcount' = "`adjusted'": col_adj_rar_3
		else											estadd local thisstat`rowcount' = "`adjusted'": col_adj_rar_3

		loc statnames = "`statnames' thisstat`rowcount'"

		loc rowcount = `rowcount' + 1
	}
}

loc varlabels2 "`"\addlinespace \textit{Panel A: Expenditure multiplier}"' `varlabels_2_exp' "

loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{3}{S[detect-weight, mode=text]}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

qui esttab col_adj_rar_? ///
	using "$dtab/TableD5_MultiplierAdjusted_withRarieda.tex", ///
	cells(none) alignment(SSSS) replace compress stats(`statnames', ///
	labels(`varlabels2')) label ///
	mtitle("\shortstack{$\mathbb{M}$\\Estimate}" "\shortstack{Share\\ imported}" "\shortstack{Import \\ adjusted}") prehead(`prehead') postfoot(`postfoot')



************************************************
** IV. Appendix Table - Nominal with details **
************************************************
cap log close
log using "nominal_check.log", replace text

** set up columns **
********************
preserve
clear
eststo clear
qui set obs 10
gen x = 1
gen y = 1

forvalues x1 = 1/3 {
	qui eststo col`x1': reg x y
	qui eststo col_adj_`x1': reg x y
	qui eststo col_adj_rar_`x1': reg x y
}
forvalues x1 = 1/6 {
	qui eststo col_rob`x1': reg x y
}
local varcount = 1
restore

** Input the bootstrap results -- main results (nominal) **
***********************************************************
di "`bootreps'"
di "$dt"


project, uses("$dt/IRF_values/bootstrap_rawoutput.dta")
use "$dt/IRF_values/bootstrap_rawoutput.dta", clear
local reps = _N
drop *_q? *_q??
gen mean_mult = (multiplier_exp + multiplier_inc)/2
order mean_mult

loc bstatstring = "mean_mult"
loc full_estimates = "mean_mult"

foreach type in "exp" "inc"{

	foreach var in multiplier_`type' ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
		if "`var'" == "multiplier_`type'"   loc bstatstring = "`bstatstring' multiplier_`type'"
		else 								loc bstatstring = "`bstatstring' `var'_mult"

		loc full_estimates = "`full_estimates', `var'"
}
}

disp "`bstatstring'"
disp "`full_estimates'"

matrix full_estimates = `full_estimates'
bstat `bstatstring', stat(full_estimates)


** Output tex table **
**********************
loc rowcount = 1
loc rowcount1 = `rowcount'+1
loc statnames = ""

foreach type in "exp" "inc"{

	** sort coefficients in descending order **
	*******************************************
	mata: coefs = .
	mata: labs = ""
	foreach var in ${hhflowvar_`type'} ${hhstockvar_`type'} ${entflowvar_`type'} ${entstockvar_`type'}{
		local coef = _b[`var'_mult]
		mata: coefs = coefs,`coef'
		mata: labs = labs,"`var'"
	}
	mata {
		coefs = coefs[1,2..length(coefs)]\(1..length(coefs)-1)
		coefs = sort(coefs',-1)'
		labs = labs[1,2..length(labs)]
		st_numscalar("numcomp",length(labs))
	}
	local components_`type' = ""
	local num = numcomp
	forval i = 1/`num' {
		mata: st_local("comp",labs[1,coefs[2,`i']])
		local components_`type' = "`components_`type''" + "`comp' "
	}

	disp "`components_`type''"

	** Now fill tex table **
	************************
	loc varlabels_`type' ""
	loc varlabels2_`type' ""

	foreach var in multiplier_`type' `components_`type'' {
		disp "Going through component: `var'"
		if "`var'" == "multiplier_`type'"   loc varname = "multiplier_`type'"
		else 								loc varname = "`var'_mult"

		pstar `varname', pstar
		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(bstar)'": col1
		else								estadd local thisstat`rowcount' = "`r(bstar)'": col1

		estadd local thisstat`rowcount1' = "`r(sestar)'": col1

		qui count if `varname' < 0
		loc pval = `r(N)' / `reps'

		pstar, p(`pval') prec(2) pstar pnopar
		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(pstar)'": col2
		else								estadd local thisstat`rowcount' = "`r(pstar)'": col2

		qui count if `varname' < 1
		loc pval = `r(N)' / `reps'

		pstar, p(`pval') prec(2) pstar pnopar
		if "`var'" == "multiplier_`type'"   estadd local thisstat`rowcount' = "`r(pstar)'": col3
		else								estadd local thisstat`rowcount' = "": col3

		loc statnames = "`statnames' thisstat`rowcount' thisstat`rowcount1'"

		loc rowcount = `rowcount' + 2
		loc rowcount1 = `rowcount'+1

		if "`var'" != "multiplier_`type'" {
			mata: st_local("lclean",select(lab_clean[2,.], (lab_clean[1,.] :== "`var'")))
			loc varlabels_`type' "`varlabels_`type'' `"\addlinespace \hspace{1em}`lclean'"' " ""
			loc varlabels_2_`type' "`varlabels_2_`type'' `"\addlinespace \hspace{1em}`lclean'"'"
		}
	}
}

** add average multiplier **
pstar mean_mult, pstar
estadd local thisstat`rowcount' = "`r(bstar)'": col1
estadd local thisstat`rowcount1' = "`r(sestar)'": col1

qui count if mean_mult < 0
loc avgnull = (`r(N)'/`reps')
pstar, p(`avgnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col2

qui count if mean_mult < 1
loc avgnull = (`r(N)'/`reps')
pstar, p(`avgnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col3

loc statnames = "`statnames' thisstat`rowcount' thisstat`rowcount1'"

** add joint test **
loc rowcount = `rowcount' + 2

qui count if multiplier_exp < 0 & multiplier_inc < 0
loc jointnull = (`r(N)'/`reps')

pstar, p(`jointnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col2

qui count if multiplier_exp < 1 & multiplier_inc < 1
loc jointnull = (`r(N)'/`reps')

pstar, p(`jointnull') prec(2) pstar pnopar
estadd local thisstat`rowcount' = "`r(pstar)'": col3

loc statnames = "`statnames' thisstat`rowcount'"

loc varlabels "`"\addlinespace \textit{Panel A: Expenditure multiplier}"' " " `varlabels_exp' `"\addlinespace \textit{Panel B: Income multiplier}"' " " `varlabels_inc' `"\addlinespace \textit{Panel C: Expenditure and income multipliers} & & & \\ \addlinespace Average of both multipliers}"' " " `"\addlinespace Joint test of both multipliers"' "
*loc varlabels "`"\addlinespace \textit{Panel A: Expenditure multiplier}"' " " `"\addlinespace \hspace{1em}Household consumption"' " "  `"\addlinespace \hspace{1em}Household assets"' " " `"\addlinespace \hspace{1em}Enterprise investment"' " "  `"\addlinespace \hspace{1em}Enterprise inventory"' " " `"\addlinespace \hline \addlinespace \textit{Panel B: Income multiplier}"' " " `"\addlinespace \hspace{1em}Household wage bill"' " "  `"\addlinespace \hspace{1em}Enterprise profits"' " " `"\addlinespace \hspace{1em}Enterprise capital income"' " "  `"\addlinespace \hspace{1em}Enterprise taxes paid"' " " `"\addlinespace \hline \addlinespace \textit{Average of both multipliers}"' " " `"\addlinespace Joint test of both multipliers"' "

loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{3}{S[detect-weight, mode=text]}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

qui esttab col? ///
	using "$dtab/TableD6_MultiplierNominal.tex", ///
	cells(none) alignment(SSSS) replace compress stats(`statnames', ///
	labels(`varlabels')) label ///
	mtitle("\shortstack{$\mathbb{M}$\\Estimate}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 0\\ \textit{p}-value}" "\shortstack{H\textsubscript{0}: $\mathbb{M}$ $<$ 1\\ \textit{p}-value}") prehead(`prehead') postfoot(`postfoot')

disp "`components_exp'"

cap log close
