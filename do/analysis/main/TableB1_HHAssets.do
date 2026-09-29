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

include "$do/programs/ge_main_table.do"

** dataset dependencies **
project, original("$da/GE_HHLevel_ECMA.dta") preserve

cap log close
log using "$dl/assets_check2.txt", replace text

/*** Spatial regression results for household assets by productivity status ***/
/* This serves as an appendix table */

cap program drop ge_label_variables
program define ge_label_variables
	cap la var totval_hhassets_wins_PPP "Assets (non-land, non-house)" // note this is not net of borrowing
	cap	la var p1_assets_wins_PPP "Assets (non-land, non-house), net borrowing"
	cap la var assets_agtools_wins_PPP    "Productive Agricultural Assets"
	cap la var assets_pot_prod_wins_PPP "Potentially Productive Assets"
	cap la var assets_livestock_wins_PPP    "\hspace{0.5cm} Livestock Assets"
  cap la var assets_prod_nonag_wins_PPP    "\hspace{0.5cm} Non-Ag Assets"
  cap la var assets_nonprod_wins_PPP    "Non-Productive Assets"
end

table_main using "$dtab/TableB1_HHAssets.tex", outcomes(totval_hhassets_wins_PPP assets_agtools_wins_PPP assets_pot_prod_wins_PPP assets_livestock_wins_PPP  assets_prod_nonag_wins_PPP assets_nonprod_wins_PPP ) fdr(0) firststage(0)
project, creates("$dtab/TableB1_HHAssets.tex")
