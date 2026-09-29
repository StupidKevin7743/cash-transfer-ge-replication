******************************************
/* Run Spatial Randomisation Inference on our main tables
This script first creates and stores a series of alternative spatial draws and then uses them to compute counterfactual
test statistics and Fisher p-values
Author: Tilman Graff
Date created: 2019-11-01 */
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
project, original("$da/GE_HHIndividualWageProfits_ECMA.dta") preserve

cap mkdir $dt/spatial_ri_draws/

************************
* Generate some new draws
************************

cap drop justanyvariable
gen justanyvariable = 1 // this creates a pseudo dataset, needed for the spatial RI program

project, original("$do/analysis/prep/RI_setreps.do") preserve
do "$do/analysis/prep/RI_setreps.do"

loc reps = $RI_reps
loc newdraw = 0 // running this as part of table 1

// we are drawing new allocations in the first program
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

** Input Prices and Quantities **
************************************

* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables
	cap la var emp_cshsal_perh_winP "\textbf{Labor} & & & & \\ Hourly wage earned by employees"
	cap la var hh_hrs_total "Household total hours worked, last 7 days"
	cap la var landprice_wins_PPP "\textbf{Land} & & & & \\ Land price per acre"
	cap la var own_land_acres "Acres of land owned"
	cap la var lw_intrate_wins "\textbf{Capital} & & & & \\ Loan-weighted interest rate, monthly"
	cap la var tot_loanamt_wins_PPP "Total loan amount"
end

spatial_ri_table using "$dtab/TableI11_RI_InputPricesQuantities.tex", outcomes(emp_cshsal_perh_winP hh_hrs_total  landprice_wins_PPP own_land_acres lw_intrate_wins tot_loanamt_wins_PPP )  reps(`reps') postfile("$dt/SpatialRI_Table2.dta")
project, creates("$dtab/TableI11_RI_InputPricesQuantities.tex") preserve
