** This do-file creates the appendix table analyzing the effect on outcomes prespecified in the PAP **

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


project, original("$do/programs/ge_tables_fdr.do")
include "$do/programs/ge_tables_fdr.do"

** data dependencies **
project, original("$da/GE_HHLevel_ECMA.dta")


/*** FOR APPENDIX: ALL PRIMARY OUTCOMES ***/

cap program drop ge_label_variables
program define ge_label_variables
	cap	la var p1_assets_wins_PPP "Assets (non-land, non-house), net borrowing"
	cap la var p2_consumption_wins_PPP "Household expenditure, annualized"
	cap la var p3_totincome_wins_PPP "Household income, annualized"
	cap la var p4_totrevenue_wins_PPP "Household revenue, annualized"
	cap la var p5_psych_index "Psychological well-being index"
	cap la var p6_healthstatus "Health index"
	cap la var p7_eduindex_all "Education index"
	cap la var p8_femaleempower_index_s18 "Female empowerment index"
	cap la var p9_foodindex "Food security index"
	cap la var p10_hrsworked "Hours worked last week (respondent)"
end

table_fdr using "$dtab/TableJ1_PAP_PrimaryOutcomes.tex", outcomes(p1_assets_wins_PPP p2_consumption_wins_PPP p3_totincome_wins_PPP p4_totrevenue_wins_PPP p5_psych_index p6_healthstatus p7_eduindex_all p8_femaleempower_index_s18 p9_foodindex p10_hrsworked) fdr(1) firststage(0)
project, creates("$dtab/TableJ1_PAP_PrimaryOutcomes.tex")
