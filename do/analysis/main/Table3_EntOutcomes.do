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

project, original("$do/programs/ge_tables_ent.do")
include "$do/programs/ge_tables_ent.do"

project, original("$do/global_runGPS.do")
include "$do/global_runGPS.do"


**************************
**** RUN ENDLINE TABLE ***
**************************
global entoutcomes_main "ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP  n_allents"

local outcomes "$entoutcomes_main"
ge_table_ent using "$dtab/Table3_EntOutcomes.tex", outcomes("`outcomes'") coeftable("$dtab/coeftables/EntOutcomes_Main_RawCoefs.xls")
project, creates("$dtab/Table3_EntOutcomes.tex")
