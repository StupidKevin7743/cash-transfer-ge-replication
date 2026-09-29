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
project, original("$do/programs/spatial-ri-ent_program.do")

do "$do/programs/draw_alternative_allocation.do"
do "$do/programs/spatial-ri-ent_program.do"

** dataset dependencies (since called in program, need to list here) **
project, original("$da/GE_Enterprise_ECMA.dta") preserve
project, original("$da/GE_VillageLevel_ECMA.dta") preserve

cap mkdir $dt/spatial_ri_draws/

************************
* Generate some new draws
************************

cap drop justanyvariable
gen justanyvariable = 1 // this creates a pseudo dataset, needed for the spatial RI program to run

project, original("$do/analysis/prep/RI_setreps.do") preserve
do "$do/analysis/prep/RI_setreps.do"

loc reps = $RI_reps

loc newdraw = 0 // drawing new allocations for first table

if `newdraw' == 1{

	_dots 0, title(Drawing new allocations) reps(`reps')
	forvalues rep = 1/`reps'{
		draw_alloc, outdir("$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta") rep(`rep')
		_dots `rep' 0
	}

}

/*** Enterprise results (Table 3) ***/
local outcomelist	 ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP  n_allents


spatial_ri_table_ent using "$dtab/TableI12_RI_Enterprise.tex", outcomes(`outcomelist') reps(`reps') postfile("$dt/SpatialRI_Enterprise.dta")
project, creates("$dtab/TableI12_RI_Enterprise.tex") preserve




cap log close
