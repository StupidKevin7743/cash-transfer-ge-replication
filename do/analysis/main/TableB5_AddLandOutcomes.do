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

** Table B.5: Input prices and quantities: Additional land market outcomes **
****************************************************************************

* dataset dependencies
project, original("$da/GE_HHLevel_ECMA.dta") preserve

** program dependencies
project, original("$do/programs/ge_main_table.do")

include "$do/programs/ge_main_table.do"



* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables

	cap la var own_land_acres "Acres of land owned"
	cap la var rentout_land_acres "Acres of land rented out"
	cap la var rent_land_acres "Acres of land rented in"
	cap la var aglanduse "Acres of land used for crops"
	cap la var landprice_wins_PPP "Land price per acre"
	cap la var rent_land_mth_acre_wins_PPP "Monthly land rental price per acre"
	cap la var aglandcost_wins_PPP "Total ag land rental costs"
end

table_main using "$dtab/TableB5_AddLandOutcomes.tex", outcomes(own_land_acres rentout_land_acres rent_land_acres aglanduse landprice_wins_PPP rent_land_mth_acre_wins_PPP aglandcost_wins_PPP) fdr(0) firststage(0)
project, creates("$dtab/TableB5_AddLandOutcomes.tex")
