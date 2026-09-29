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

project, original("$do/programs/ge_tables_ent.do")
include "$do/programs/ge_tables_ent.do"


**********************************************************
**** 2. RUN ENDLINE TABLE -- WITHOUT BASELINE CONTROLS ***
**********************************************************
global entoutcomes_main "ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP  n_allents"

local outcomes "$entoutcomes_main"
ge_table_ent using "$dtab/TableG2_EntOutcomes_NoBLControls.tex", nobl outcomes("`outcomes'")  coeftable("$dtab/coeftables/EntOutcomes_Main_NoBLControls_RawCoefs.xls")
project, creates("$dtab/TableG2_EntOutcomes_NoBLControls.tex")
