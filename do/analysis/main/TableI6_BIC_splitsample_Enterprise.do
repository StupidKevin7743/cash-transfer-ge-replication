* Preliminaries
return clear
capture project, doinfo
if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
else {  // running directly
	if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
	do "${ge_dir}/do/set_environment.do"
}

adopath ++ "$dir/ado"


** defining globals **
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"

project, original("$dir/do/global_runGPS.do")
include "$dir/do/global_runGPS.do"


set varabbrev off

** dataset dependencies **
project, original("$da/GE_Enterprise_ECMA.dta") preserve
project, original("$da/GE_VillageLevel_ECMA.dta")


*** Load programs ***
project, original("$do/programs/bic_splitsample.do")
project, original("$do/analysis/prep/BIC_setreps.do")
include "$do/programs/bic_splitsample.do"

*** Set reps ***
include "$do/analysis/prep/BIC_setreps.do"
loc reps = $bic_reps

di "Reps: `reps'"


*** Table 3: Enterprise Outcomes
local outcomelist "ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP n_allents"


** defining base name
glo sumtitle "Split BIC sample for enterprise outcomes, (`reps' permutations)"

*Defining variable labels
cap program drop ge_label_variables
program define ge_label_variables
	cap la var n_allents "\emph{Panel C: Village-level} & & & & \\ Number of enterprises"
	cap la var n_operates_from_hh "Number of enterprises, operated from hh"
	cap la var n_operates_outside_hh "Number of enterprises, operated outside hh"
	cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
	cap la var ent_profit2_wins_PPP "\emph{Panel A: All enterprises} & & & & \\ Enterprise profits, annualized"
	cap la var ent_profitmargin2_wins "Enterprise profit margin"
	cap la var ent_revenue2_wins_PPP "Enterprise revenue, annualized"
	cap la var ent_totcost_wins_PPP "Enterprise costs, annualized"
	cap la var ent_wagebill_wins_PPP "\hspace{1em}Enterprise wagebill, annualized"
	cap la var ent_inventory_wins_PPP "\emph{Panel B: Non-agricultural enterprises} & & & & \\ Enterprise inventory"
	cap la var ent_inv_wins_PPP "Enterprise investment, annualized"
end



bic_splitsample using "$dtab/TableI6_BIC_SplitSample_EntOutcomes.tex", outcomes("`outcomelist'") reps(`reps') enterprise(1) postfile("$dt/BIC_SplitSample_Table3_`reps'reps.dta")
project, creates("$dtab/TableI6_BIC_SplitSample_EntOutcomes.tex")
