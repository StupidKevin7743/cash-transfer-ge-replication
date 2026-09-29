
** This .do file outputs statistics mentioned in the paper text **
******************************************************************

/* Preliminaries */
/* do file header */
return clear
capture project, doinfo
if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
else {  // running directly
		if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
		do "${ge_dir}/do/set_environment.do"
}

* Import config - running globals
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"


** Set output log **
log using "$dtab/../SummaryStats_InText", replace


** GDP **
*********
project, original("$dt/pp_GDP_calculated_nominal.dta")
use "$dt/pp_GDP_calculated_nominal.dta", clear
gen pp_GDP_PPP = pp_GDP * $ppprate
disp pp_GDP_PPP
global pp_GDP = pp_GDP[1]

gen phh_GDP_PPP = phh_GDP * $ppprate
disp phh_GDP_PPP 


** Tracking statistics **
*************************
project, original("$da/GE_HH-Survey_Tracking_Attrition.dta")
use "$da/GE_HH-Survey_Tracking_Attrition.dta", clear

** Baseline **
tab hh_baselined init_sample, m // baseline surveys, of which some are initially targeted

** Endline **
tab surveyed_rd2 init_sample, m // endline surveys, of which some are initially targeted
tab surveyed_rd2 hh_baselined if init_sample == 1, m // endline surveys, of which some are inititally targeted but not surveyed at baseline


** Household Summary Statistics **
**********************************
project, original("$da/GE_HH-Analysis_AllHHs.dta")
use "$da/GE_HH-Analysis_AllHHs", clear
sum hhweight_EL // fix weight
drop hhweight_EL
project, original("$da/GE_HHLevel_ECMA.dta") preserve
merge 1:1 hhid_key using "$da/GE_HHLevel_ECMA.dta", keepusing(hhweight_EL)

** average number of child household members
sum hhsize1 [weight=hhweight_EL]
sum s4_4_q3a_numchildren [weight=hhweight_EL]

** average respondent age
sum age [weight=hhweight_EL]

** average respondent years of schooling
sum yearsedu [weight=hhweight_EL]

** Share of households engaged in agricuture
sum s7_q2_crops [weight=hhweight_EL]

** Share engaged in wage work
sum emp [weight=hhweight_EL]

** Share engaged in self-employment
sum selfemp [weight=hhweight_EL]


** Average commuting time to preferred market
project, original("$dr/GE_HH-Survey-BL_PUBLIC.dta")
use "$dr/GE_HH-Survey-BL_PUBLIC.dta", clear
sum s6_q9a_marketcentermin
tab s6_q9a_marketcentermode

** Share ever report shopping outside the study area **
gen shop_outsidestudyarea = !inrange(s6_q9_marketcentercode,100,400) if s6_q9_marketcentercode != .
sum shop_outsidestudyarea


** Share that has a bank account **
project, original("$dr/GE_HH-Survey-EL1_PUBLIC.dta")
use "$dr/GE_HH-Survey-EL1_PUBLIC.dta", clear
ren s1_hhid_key hhid_key
keep hhid_key s10_q1_bankaccount
merge 1:1 hhid_key using "$da/GE_HH-Analysis_AllHHs.dta", keepusing(hhweight_EL)
gen hasbankacct = 2-s10_q1_bankaccount
sum hasbankacct [weight=hhweight_EL]


** Survey timing **
** 5th-95th percentile of endline survey since start date
** endline survey median time since start date
project, original("$da/GE_Survey_and_Transfer_Dates.dta")
use "$da/GE_Survey_and_Transfer_Dates.dta", clear
sum exptoend, d // endline survey, time since experimental start date





** Enterprise Summary Statistics **
***********************************

** Match rates **
project, original("$da/GE_ENT_BL_EL_AllCombined.dta")
use "$da/GE_ENT_BL_EL_AllCombined.dta", clear
gen ent_type = 3 if hhid_key != ""
replace ent_type = 2 if ENT_CEN_EL_operate_from == 1
replace ent_type = 1 if ENT_CEN_EL_operate_from != 1 & ENT_CEN_EL_operate_from != .
tab ent_type, m

sum ownerm_match if inlist(ent_type,1,2) // share matched among non-farm
sum ownerm_match if inlist(ent_type,1,2,3) // share matched among all

sum ownerm_treat if inlist(ent_type,1,2) & ownerm_eligible == 1 // share treated among eligible matched owners
sum ownerm_treat if inlist(ent_type,1,2) & ownerm_eligible == 0 // share treated among ineligible matched owners
sum ownerm_eligible if inlist(ent_type,1,2) // share of owners that are eligible

** Profits and Revenues by owner eligiblity **
project, original("$da/GE_ENT-Analysis_AllENTs.dta")
use "$da/GE_ENT-Analysis_AllENTs.dta", clear
bys ownerm_eligible: sum ent_revenue2_wins_PPP [weight=entweight_EL] if inlist(ent_type,1,2) & inlist(ownerm_eligible,0,1) // enterprise profits by eligibility status
bys ownerm_eligible: sum ent_profit2_wins_PPP [weight=entweight_EL] if inlist(ent_type,1,2) & inlist(ownerm_eligible,0,1) // enterprise profits by eligibility status

** Now stats from the survey **
*******************************

** Enterprises by type **
tab ent_type

** Share of non-farm customers coming from same village or sublocation **
gen cust_withinvilsubloc = cust_svillage + cust_ssublocation
sum cust_withinvilsubloc [weight=entweight_EL]

** Share of non-farm customers coming from outside the study area
gen cust_outsidesubloc = cust_stown + cust_sother
sum cust_outsidesubloc [weight=entweight_EL]

** Number of customers per hour **
sum ent_cust_perhour [weight=entweight_EL]

** Share of non-farm enterprises with 1 employee **
tab emp_n_tot if inlist(ent_type,1,2)
gen nemp_one = inlist(emp_n_tot,0,1) if emp_n_tot != .
sum nemp_one [weight=entweight_EL] if inlist(ent_type,1,2)

** Share of non-farm employment that is family labor **
gen emp_shr_family = emp_n_family/emp_n_tot
gen weight = emp_n_tot * entweight_EL
sum emp_shr_family [weight=weight] if inlist(ent_type,1,2)


** Treatment Summary Statistics **
**********************************
project, original("$da/village_actualtreat_wide_FINAL.dta")
use "$da/village_actualtreat_wide_FINAL.dta", clear
keep village_code month p_total_ownvill amount_total_KES_ownvill ///
amount_total_KES_00to02km ///
amount_total_KES_04to06km

** Get maximum transfer period **
gen amt = amount_total_KES_ownvill*p_total_ownvill
bys month: egen totamt = sum(amt)
xtset village_code month
gen cumtotamt = totamt
forval l = 1/11 {
	replace cumtotamt = cumtotamt + l`l'.totamt
}
sum cumtotamt
gen maxmonth = cumtotamt == r(max)
sum month if maxmonth
replace maxmonth = 1 if inrange(month,r(mean)-11,r(mean))
gen cum12_amount_total_KES_ownvill = amount_total_KES_ownvill if maxmonth == 1

collapse (sum) amount_total_KES_* cum12_amount_total_KES_ownvill, by(village_code)
merge 1:1 village_code using "$dr/GE_Treat_Status_Master", keepusing(treat)
drop if _merge != 3

** Now calculate annual GDP **
foreach type in ownvill 00to02km 04to06km {
	gen shr_GDP_`type' = amount_total_KES_`type' / $pp_GDP
}
gen shr_GDP_ownvill_max12 = cum12_amount_total_KES_ownvill / $pp_GDP


** Total transfers as a share of village GDP **
sum shr_GDP_ownvill if treat == 1

** Transfers as a share of GDP in peak 12 months **
sum shr_GDP_ownvill_max12 if treat == 1

** Transfers share of GDP -- 2km buffer
** 90-10 percentile range of transfers to GDP -- 2km buffer
sum shr_GDP_00to02km, d

** 90-10 percentile range of transfers to GDP -- 6km buffer
sum shr_GDP_04to06km, d


** Now for markets **
*********************
project, original("$da/market_actualtreat_wide_FINAL.dta")
use "$da/market_actualtreat_wide_FINAL.dta", clear
keep market_code month amount_total_KES_00to02km amount_total_KES_02to04km ///
p_total_00to02km p_total_02to04km

gen amount_total_KES_00to04km = (p_total_00to02km*amount_total_KES_00to02km + p_total_02to04km*amount_total_KES_02to04km) / (p_total_00to02km + p_total_02to04km)

** Get maximum transfer period **
bys month: egen totamt = mean(amount_total_KES_00to04km)
xtset market_code month
gen cumtotamt = totamt
forval l = 1/11 {
	replace cumtotamt = cumtotamt + l`l'.totamt
}
sum cumtotamt
gen maxmonth = cumtotamt == r(max)
sum month if maxmonth
replace maxmonth = 1 if inrange(month,r(mean)-11,r(mean))
gen cum12_amount_total_00to04km = amount_total_KES_00to04km if maxmonth == 1

collapse (first) p_total* (sum) amount_total_KES_00to04km cum12_amount_total_00to04km, by(market_code)

** Share of annual GDP transferred to 4km buffer around average market in the most intense period **
gen shr_GDP_00to04km =  amount_total_KES_00to04km / $pp_GDP
gen cum12_shr_GDP_00to04km =  cum12_amount_total_00to04km / $pp_GDP
sum shr_GDP_00to04km cum12_shr_GDP_00to04km


** Now for midline phone surveys **
***********************************
project, original("$da/Ent_ML_SpatialData_long_FINAL.dta")
use "$da/Ent_ML_SpatialData_long_FINAL.dta", clear
forval i = 1/7 {
	gen mon`i' = mofd(today_R`i')
	format mon`i' %tm
}
sum mon1
local minmonth = r(min) - 1
sum mon7
local maxmonth = r(max)

project, original("$da/village_actualtreat_wide_FINAL.dta")
use "$da/village_actualtreat_wide_FINAL.dta", clear
keep village_code month p_total_ownvill amount_total_KES_ownvill ///
p_total_00to02km amount_total_KES_00to02km

** Change in share of transfers during midline phone surveys
gen amt = p_total_ownvill*amount_total_KES_ownvill
bys month: egen totamt = sum(amt)
bys village_code: egen alltotamt = sum(totamt)
bys village_code (month): gen cumamt = sum(totamt)
replace cumamt = cumamt / alltotamt

sum cumamt if month == `minmonth'
local start = r(mean)
sum cumamt if month == `maxmonth'
local end = r(mean)

disp "The change in the overall share of transfers that went out over the period is:"
disp "from `=round(`start'*100,1)' percent to `=round(`end'*100,1)' percent"

** Now just keep months where midline surveys went on **
keep if inrange(month,`minmonth'+1,`maxmonth')

gen shr_GDP_00to02km =  amount_total_KES_00to02km / $pp_GDP
bys village_code: egen maxamt = max(shr_GDP_00to02km)
bys village_code: egen minamt = min(shr_GDP_00to02km)
gen diffamt = maxamt - minamt

keep village_code amount_total_KES_00to02km diffamt
collapse (first) diffamt (sum) amount*, by(village_code)
gen shr_GDP_00to02km =  amount_total_KES_00to02km / $pp_GDP

** 90-10 percentile range of transfers for midline phone surveys
sum shr_GDP_00to02km, d

** difference in inflows between most and least intense months (midline surveys)
sum diffamt, d



**** Lastly, share of the multiplier due to recipients vs. non-recipients ****
******************************************************************************
project, uses("$dt/multiplier_estimates.dta")
use "$dt/multiplier_estimates.dta", clear

keep if quarter == 99 // only total multiplier across all quarters
keep if deflated == 1 & withRarieda == 0 // only real without Rarieda
keep type multiplier_exp nondurables_exp_wins totval_hhassets_h_wins p3_3_wageearnings_wins // keep only household expenditure components

gen multiplier_exp_hhcomp = nondurables_exp_wins + totval_hhassets_h_wins
local shr_nonrec = multiplier_exp_hhcomp[3]/multiplier_exp_hhcomp[1]

disp "Share of the expenditure component of the multiplier due to non-recipients:"
disp "`=round(`shr_nonrec',0.01)'"

local shr_nonrec_inc = p3_3_wageearnings_wins[3]/p3_3_wageearnings_wins[1]
disp "Share of the income component of the multiplier due to non-recipients:"
disp "`=round(`shr_nonrec_inc',0.01)'"

log close
