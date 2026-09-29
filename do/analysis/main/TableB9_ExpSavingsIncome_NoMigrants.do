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

project, original("$do/programs/ge_main_table_migration.do")
include "$do/programs/ge_main_table_migration.do"


** dataset dependencies (since called in program, need to list here) **
project, original("$da/GE_HHLevel_ECMA.dta") preserve


* defining variable list
local outcomelist "p2_consumption_wins_PPP nondurables_exp_wins_PPP h2_1_foodcons_12mth_wins_PPP h2_3_temptgoods_12_wins_PPP durables_exp_wins_PPP p1_assets_wins_PPP h1_10_housevalue_wins_PPP h1_11_landvalue_wins_PPP p3_totincome_wins_PPP p11_6_nettransfers_wins2_PPP tottaxpaid_all_wins_PPP totprofit_wins_PPP p3_3_wageearnings_wins_PPP"
** defining base name
local filebase "ExpSavingIncome"

* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables

	cap ren hh_n hhsize1
	cap la var p11_1_frmigrated  "\emph{Panel 1: Full Sample} & & & &  \\Respondent migrated "
	cap la var p11_4_migration_nethhchange "Net change in household members since baseline"
	cap la var hhsize1 "Household size"

	cap la var p2_consumption_wins_PPP "\emph{Panel 2: Non-Migrant Sample}&&&&\\ \emph{Panel 2.A: Expenditure}&&&&\\ Household expenditure, annualized"
	cap la var nondurables_exp_wins_PPP "Non-durable expenditure, annualized"
	cap la var h2_1_foodcons_12mth_wins_PPP "\hspace{1em}Food expenditure, annualized"
	cap la var h2_3_temptgoods_12_wins_PPP "\hspace{1em}Temptation goods expenditure, annualized"
	cap la var durables_exp_wins_PPP "Durable expenditure, annualized"
	cap	la var p1_assets_wins_PPP "\emph{Panel 2.B: Assets} & & & & \\ Assets (non-land, non-house), net borrowing"
	cap la var h1_10_housevalue_wins_PPP "Housing value"
	cap la var h1_11_landvalue_wins_PPP "Land value"
	cap la var p3_totincome_wins_PPP "\emph{Panel 2.C: Household balance sheet} & & & &\\ Household income, annualized"
	cap la var p3_3_wageearnings_wins_PPP "Wage earnings, annualized"
	cap la var tottaxpaid_all_wins_PPP "Tax paid, annualized"
	cap la var p11_6_nettransfers_wins2_PPP "Net value of household transfers received, annualized"
	cap la var totprofit_wins_PPP "Profits (ag \& non-ag), annualized"

end

** Dropping FRs that have migrated **
table_main_migration using "$dtab/TableB9_`filebase'_NoMigrants.tex", outcomes(p11_1_frmigrated p11_4_migration_nethhchange hhsize1 `outcomelist' ) fdr(0) firststage(0)
