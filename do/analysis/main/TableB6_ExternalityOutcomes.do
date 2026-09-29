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


project, original("$do/programs/ge_main_table.do")
project, original("$do/programs/ge_tables_ext.do")

include "$do/programs/ge_main_table.do"
include "$do/programs/ge_tables_ext.do"

* dataset dependencies *
project, original("$da/GE_HHLevel_ECMA.dta") preserve


** Table A.6: Non-market outcomes and externalities **
*******************************************************************

* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables
	cap la var p5_psych_index "Psychological well-being index"
	cap la var p6_healthstatus "Health index"
	cap la var p7_eduindex_all "Education index"
	cap la var p8_femaleempower_index_s18 "Female empowerment index"
	cap la var p9_foodindex "Food security index"
	cap la var child_foodsec "\hspace{0.5cm} Children food security"
	cap la var security_index "Security index"
end

table_main using "$dtab/TableB6_ExternalityOutcomes.tex", outcomes(p5_psych_index p6_healthstatus p9_foodindex child_foodsec p7_eduindex_all  p8_femaleempower_index_s18 security_index) fdr(0) firststage(0)
project, creates("$dtab/TableB6_ExternalityOutcomes.tex")

/*
** Command below generates extended version of main table,
** includes total effects on control eligibles (col 4) and on ineligibles (col 5)
table_main_ext using "$dtab/AppendixTable_ExternalityOutcomes_Extended.tex", outcomes(p5_psych_index p6_healthstatus p9_foodindex child_foodsec p7_eduindex_all  p8_femaleempower_index_s18 security_index) fdr(0) firststage(0)
project, creates("$dtab/AppendixTable_ExternalityOutcomes_Extended.tex")
*/
