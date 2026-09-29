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

project, original("$do/programs/ge_main_table.do")
project, original("$do/programs/ge_tables_ext.do")
project, original("$do/programs/ge_tables_coefs.do")
project, original("$do/global_runGPS.do")

include "$do/programs/ge_main_table.do"
include "$do/programs/ge_tables_ext.do"
include "$do/programs/ge_tables_coefs.do"
include "$do/global_runGPS.do"


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


table_main using "$dtab/Table2_InputPricesQuantities.tex", outcomes(`outcomelist') fdr(0) firststage(0)
project, creates("$dtab/Table2_InputPricesQuantities.tex")


/* For interested users

** Command below generates extended version of main table (analogous to Table B8)
** includes total effects on control eligibles (col 4) and on ineligibles (col 5)
table_main_ext using "$dtab/SupportingTable_InputPricesQuantities_Extended.tex", outcomes(`outcomelist') fdr(0) firststage(0)
project, creates("$dtab/SupportingTable_InputPricesQuantities_Extended.tex")


** Coefficient version of the table (analogous to Table F3) **
table_main_coef using "$dtab/SupportingTable_InputPricesQuantities_Coefs.tex", outcomes(`outcomelist') fdr(0) firststage(0)
project, creates("$dtab/SupportingTable_InputPricesQuantities_Coefs.tex")
*/
