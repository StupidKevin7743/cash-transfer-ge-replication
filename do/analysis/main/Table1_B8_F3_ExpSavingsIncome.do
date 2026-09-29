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


** dataset dependencies (since called in program, need to list here) **
project, original("$da/GE_HHLevel_ECMA.dta") preserve

/*** Generating main paper and presentation versions of expenditure, savings and income results ***/
/* Note: paper version has 3 panels and combines household income decomposition. */

* defining variable list
local outcomelist "p2_consumption_wins_PPP nondurables_exp_wins_PPP h2_1_foodcons_12mth_wins_PPP h2_3_temptgoods_12_wins_PPP durables_exp_wins_PPP p1_assets_wins_PPP h1_10_housevalue_wins_PPP h1_11_landvalue_wins_PPP p3_totincome_wins_PPP p11_6_nettransfers_wins2_PPP tottaxpaid_all_wins_PPP totprofit_wins_PPP p3_3_wageearnings_wins_PPP"
** defining base name
local filebase "ExpSavingIncome"

/**** PAPER VERSION ****/

* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables
	cap la var p2_consumption_wins_PPP "\emph{Panel A: Expenditure} & & & & & \\ Household expenditure, annualized"
	cap la var nondurables_exp_wins_PPP "Non-durable expenditure, annualized"
	cap la var h2_1_foodcons_12mth_wins_PPP "\hspace{1em}Food expenditure, annualized"
	cap la var h2_3_temptgoods_12_wins_PPP "\hspace{1em}Temptation goods expenditure, annualized"
	cap la var durables_exp_wins_PPP "Durable expenditure, annualized"
	cap	la var p1_assets_wins_PPP "\emph{Panel B: Assets} & & & & \\ Assets (non-land, non-house), net borrowing"
	cap la var h1_10_housevalue_wins_PPP "Housing value"
	cap la var h1_11_landvalue_wins_PPP "Land value"
	cap la var p3_totincome_wins_PPP "\emph{Panel C: Household balance sheet} & & & & \\ Household income, annualized"
	cap la var p3_3_wageearnings_wins_PPP "Wage earnings, annualized"
	cap la var tottaxpaid_all_wins_PPP "Tax paid, annualized"
	cap la var p11_6_nettransfers_wins2_PPP "Net value of household transfers received, annualized"
	cap la var totprofit_wins_PPP "Profits (ag \& non-ag), annualized"
end

table_main using "$dtab/Table1_`filebase'.tex", outcomes(`outcomelist') fdr(0) firststage(0)
project, creates ("$dtab/Table1_`filebase'.tex")

/*** ADDITIONAL TABLES ***/
/* This generates key checks for the same list of outcomes:
	i) extended table (ATEs separating out within vs across) (Table B.8)
	ii) coefficient table (Table F.3)
*/

** Command below generates extended version of main table,
** includes total effects on control eligibles (col 4) and on ineligibles (col 5)
table_main_ext using "$dtab/TableB8_`filebase'_Extended.tex", outcomes(`outcomelist') fdr(0) firststage(0)
project, creates("$dtab/TableB8_`filebase'_Extended.tex")


** Coefficient version of the table **
table_main_coef using "$dtab/TableF3_`filebase'_Coefs.tex", outcomes(`outcomelist') fdr(0) firststage(0)
project, creates("$dtab/TableF3_`filebase'_Coefs.tex")




** Test whether consumptin and income effect is equal for non-recipients **
***************************************************************************
project, original("$da/GE_HHLevel_ECMA.dta")
use "$da/GE_HHLevel_ECMA.dta", clear
if $runGPS == 1 {
	project, original("$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta") preserve
	merge 1:1 hhid_key using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
}

gen netinc_effect = p3_totincome_wins_PPP - p2_consumption_wins_PPP
gen weight = hhweight_EL
gen ineligible = 1-eligible
gen cons = 1

** use specification from consumption **
calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec // no bl vars
local r=r(r_max)

** For non-recipients, we use total amount within 0-2 km, without making village distinction
local endregs = ""
local exregs = ""
local amount_list = ""

forval rad = 2(2)`r' {
	local r2 = `rad' - 2

	gen pp_actamt_`r2'to`rad'km_eligible = pp_actamt_`r2'to`rad'km * eligible
	gen pp_actamt_`r2'to`rad'km_ineligible = pp_actamt_`r2'to`rad'km * ineligible

	gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
	gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible

	local endregs = "`endregs'" + " pp_actamt_`r2'to`rad'km_eligible" + " pp_actamt_`r2'to`rad'km_ineligible"
	local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`rad'km_el"  + " share_ge_elig_treat_`r2'to`rad'km_in"

	local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
}

if $runGPS == 1 {
	iv_spatial_HAC netinc_effect cons eligible [aweight=hhweight_EL] if (eligible == 0 | treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(survey_mth) panelvar(hhid) dist(10) lag(0) dropvar
}
if $runGPS == 0 {
	ivreg2 netinc_effect eligible (`endregs' = `exregs')  [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
}

** Get mean total spillover effect on eligibles in control villages and ineligibles **
sum weight if (eligible == 1 & treat == 0)
local mean1 = r(sum)
sum weight if (eligible == 0)
local mean2 = r(sum)

local eligcontrolweight = `mean1' / (`mean1' + `mean2')
local ineligweight = `mean2' / (`mean1' + `mean2')

local ATEstring_spillover = "0"
foreach vrb of local amount_list {
	sum `vrb' [weight=weight] if (eligible == 1 & treat == 0)
	local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`eligcontrolweight'" + "*`r(mean)'" + "*`vrb'_eligible"

	sum `vrb' [aweight=weight] if eligible == 0
	local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ineligweight'" + "*`r(mean)'" + "*`vrb'_ineligible"
}

log using "$dtab/../nonrecipients_incomevsconsumptiontest", replace

disp "This tests for equality between the effect on total income, and the effect on total expenditure for non-recipients"
lincom "`ATEstring_spillover'"
log close
