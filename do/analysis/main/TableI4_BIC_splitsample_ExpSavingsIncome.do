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
project, original("$da/GE_HHLevel_ECMA.dta") preserve

*** Load programs ***
/* Need to make sure that different programs are not being called later on -- should only have one version of each of these. It may also be better to have programs named the same as the do file. If a little more work, will still be clearer */

project, original("$do/programs/bic_splitsample.do")
project, original("$do/analysis/prep/BIC_setreps.do")
include "$do/programs/bic_splitsample.do"

cap log close
log using "$dl/bic_splitsample_log.log", replace text

*** Set reps ***
include "$do/analysis/prep/BIC_setreps.do"
loc reps = $bic_reps

di "Reps: `reps'"

*** Table 1 Outcomes ***
* defining variable list
local outcomelist "p2_consumption_wins_PPP nondurables_exp_wins_PPP h2_1_foodcons_12mth_wins_PPP h2_3_temptgoods_12_wins_PPP durables_exp_wins_PPP p1_assets_wins_PPP h1_10_housevalue_wins_PPP h1_11_landvalue_wins_PPP p3_totincome_wins_PPP p11_6_nettransfers_wins2_PPP tottaxpaid_all_wins_PPP totprofit_wins_PPP p3_3_wageearnings_wins_PPP"

** defining base name
glo sumtitle "Split BIC sample for expenditure, savings and income outcomes, (`reps' permutations)"


* Defining variable labels *
cap program drop ge_label_variables
program define ge_label_variables
	cap la var p2_consumption_wins_PPP "\emph{Panel A: Expenditure}&&&&&&&& \\ Household expenditure, annualized"
	cap la var nondurables_exp_wins_PPP "Non-durable expenditure, annualized"
	cap la var h2_1_foodcons_12mth_wins_PPP "\hspace{1em}Food expenditure, annualized"
	cap la var h2_3_temptgoods_12_wins_PPP "\hspace{1em}Temptation goods expenditure, annualized"
	cap la var durables_exp_wins_PPP "Durable expenditure, annualized"
	cap	la var p1_assets_wins_PPP "\emph{Panel B: Assets}&&&&&&&&\\ Assets (non-land, non-house), net borrowing"
	cap la var h1_10_housevalue_wins_PPP "Housing value"
	cap la var h1_11_landvalue_wins_PPP "Land value"
	cap la var p3_totincome_wins_PPP "\emph{Panel C: Household balance sheet}&&&&&&&& \\ Household income, annualized"
	cap la var p3_3_wageearnings_wins_PPP "Wage earnings, annualized"
	cap la var tottaxpaid_all_wins_PPP "Tax paid, annualized"
	cap la var p11_6_nettransfers_wins2_PPP "Net value of household transfers received, annualized"
	cap la var totprofit_wins_PPP "Profits (ag \& non-ag), annualized"
	cap la var emp_cshsal_perh_winP "\emph{Panel D: Input Prices} & & & & & & & &  \\ Hourly wage earned by employees"
	cap la var hh_hrs_total "Household total hours worked, last 7 days"
	cap la var landprice_wins_PPP "Land price per acre"
	cap la var own_land_acres "Acres of land owned"
	cap la var lw_intrate_wins "Loan-weighted interest rate, monthly"
	cap la var tot_loanamt_wins_PPP "Total loan amount"
end


bic_splitsample using "$dtab/TableI4_BIC_SplitSample_ExpSavingIncome.tex", outcomes(`outcomelist') reps(`reps') enterprise(0) postfile("$dt/BIC_SplitSample_Table1_`reps'reps.dta")
project, creates("$dtab/TableI4_BIC_SplitSample_ExpSavingIncome.tex")
