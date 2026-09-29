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

project, original("$do/programs/radius_chosen_table.do")
include "$do/programs/radius_chosen_table.do"


** dataset dependencies **
project, original("$da/GE_HHLevel_ECMA.dta") preserve
project, original("$da/GE_HHIndividualWageProfits_ECMA.dta")

** Input Prices and Quantities **
************************************
local outcomelist emp_cshsal_perh_winP hh_hrs_total landprice_wins_PPP own_land_acres lw_intrate_wins tot_loanamt_wins_PPP
local filebase "InputPricesQuantities"

* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables
	cap la var emp_cshsal_perh_winP "\emph{Panel A: Labor} & & & & \\ Hourly wage earned by employees"
	cap la var hh_hrs_total "Household total hours worked, last 7 days"
	cap la var landprice_wins_PPP "\emph{Panel B: Land} & & & & \\ Land price per acre"
	cap la var own_land_acres "Acres of land owned"
	cap la var lw_intrate_wins "\emph{Panel C: Capital} & & & & \\ Loan-weighted interest rate, monthly"
	cap la var tot_loanamt_wins_PPP "Total loan amount"
end


** command below generates appendix table for maximum radius chosen
radius_chosen_table using "$dtab/TableI8_`filebase'_MaxRadius.tex", outcomes(`outcomelist')
project, creates("$dtab/TableI8_`filebase'_MaxRadius.tex")
