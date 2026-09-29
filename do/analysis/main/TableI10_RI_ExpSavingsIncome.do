******************************************
/* Run Spatial Randomisation Inference on our main tables
This script first creates and stores a series of alternative spatial draws and then uses them to compute counterfactual
test statistics and Fisher p-values
Author: Tilman Graff
Created: 2019-11-01 */
******************************************

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

project, original("$dir/do/global_runGPS.do")
include "$dir/do/global_runGPS.do"


project, original("$da/pp_GDP_calculated.dta")
use "$da/pp_GDP_calculated.dta", clear
global pp_GDP = pp_GDP[1]
global pp_GDP_r = pp_GDP_r[1]
clear

set varabbrev off



project, original("$do/programs/draw_alternative_allocation.do")
project, original("$do/programs/spatial-ri_program.do")

do "$do/programs/draw_alternative_allocation.do"
do "$do/programs/spatial-ri_program.do"

** dataset dependencies (since called in program, need to list here) **
project, original("$da/GE_HHLevel_ECMA.dta") preserve

cap mkdir $dt/spatial_ri_draws/


project, original("$do/analysis/prep/RI_setreps.do") preserve
do "$do/analysis/prep/RI_setreps.do"

loc reps = $RI_reps
loc newdraw = $RI_draw


************************
* Generate some new draws
************************

cap drop justanyvariable
gen justanyvariable = 1 // this creates a pseudo dataset, needed for the spatial RI program


if `newdraw' == 1{

	_dots 0, title(Drawing new allocations) reps(`reps')
	forvalues rep = 1/`reps'{
		draw_alloc, outdir("$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta") rep(`rep')
		_dots `rep' 0
	}

}



*******************************
** 1. Generating Main Tables **
*******************************

** a. Expenditures and savings **
**************************

local outcomelist "p2_consumption_wins_PPP nondurables_exp_wins_PPP h2_1_foodcons_12mth_wins_PPP h2_3_temptgoods_12_wins_PPP durables_exp_wins_PPP p1_assets_wins_PPP h1_10_housevalue_wins_PPP h1_11_landvalue_wins_PPP p3_totincome_wins_PPP p11_6_nettransfers_wins2_PPP tottaxpaid_all_wins_PPP totprofit_wins_PPP p3_3_wageearnings_wins_PPP"

* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables
	cap la var p2_consumption_wins_PPP "\emph{Panel A: Expenditure} & & & & & \\ Household expenditure, annualized"
	cap la var nondurables_exp_wins_PPP "Non-durable expenditure, annualized"
	cap la var h2_1_foodcons_12mth_wins_PPP "\hspace{1em}Food expenditure, annualized"
	cap la var h2_3_temptgoods_12_wins_PPP "\hspace{1em}Temptation goods expenditure, annualized"
	cap la var durables_exp_wins_PPP "Durable expenditure, annualized"
	cap	la var p1_assets_wins_PPP "\emph{Panel B: Assets} & & & & \\ Assets (non-land, non-house), net borrowing"
	cap la var h1_10_housevalue_wins_PPP "Housing value"
	cap la var h1_11_landvalue_wins_PPP "Land value"
	cap la var p3_totincome_wins_PPP "\emph{Panel C: Household balance sheet} & & & & \\ Household income, annualized"
	cap la var p3_3_wageearnings_wins_PPP "Wage earnings, annualized"
	cap la var tottaxpaid_all_wins_PPP "Tax paid, annualized"
	cap la var p11_6_nettransfers_wins2_PPP "Net value of household transfers received, annualized"
	cap la var totprofit_wins_PPP "Profits (ag \& non-ag), annualized"
end

spatial_ri_table using "$dtab/TableI10_RI_ExpSavingIncome.tex", outcomes(`outcomelist')  reps(`reps') postfile("$dt/SpatialRI_Table1.dta")
project, creates("$dtab/TableI10_RI_ExpSavingIncome.tex") preserve
