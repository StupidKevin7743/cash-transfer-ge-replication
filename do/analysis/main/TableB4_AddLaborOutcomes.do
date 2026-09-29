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

/*** Additional labor supply outcomes table for appendix ***/
* This uses both household and individual-level data

* dataset dependencies
project, original("$da/GE_HHLevel_ECMA.dta")
project, original("$da/GE_HHIndividualWageProfits_ECMA.dta")

** program dependencies
project, original("$do/programs/ge_main_table.do")
include "$do/programs/ge_main_table.do"




* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables
	cap la var hh_hrs_ag "Household hours worked on own farm"
	cap la var selfemp_hrs "Individual hours worked in self-employment"
	cap la var emp_hrs "Individual hours employed last week"
	cap la var emp_hrs_agri "Individual hours employed last week in agriculture"
	cap la var emp_hrs_nag "Individual hours employed last week not in agriculture"
	cap la var p11_1_frmigrated "FR migrated (for at least 4 months)"
	cap la var p11_4_migration_nethhchange "Net change in household members"
	cap la var p10_4_propworkingadults "Proportion of working adults"
	cap la var numadults "Number of adults in the household"
	cap la var numprimeage "Number of prime-age (18-55) adults in the household"
	cap la var emp_cshsal_perh_winP "Hourly wage earned by employees"
	cap la var emp_cshsal_perh_agri_winP "Hourly wage earned by employees in agriculture"
	cap la var emp_cshsal_perh_nag_winP "Hourly wage earned by employees not in agriculture"
end

table_main using "$dtab/TableB4_AddLaborOutcomes.tex", outcomes(hh_hrs_ag selfemp_hrs emp_hrs emp_hrs_agri emp_hrs_nag emp_cshsal_perh_winP emp_cshsal_perh_agri_winP emp_cshsal_perh_nag_winP) fdr(0)  firststage(0)
