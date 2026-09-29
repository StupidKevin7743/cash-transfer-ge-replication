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

*** generating log file ***
capture project, doinfo
if (_rc==0 & !mi(r(pname))) {
}
else {
	cap log close
	log using "$dl/Appendix_AdditionalPriceAnalyses_`c(current_date)'.txt", replace text
}

cap mkdir "$dt/PriceAnalysis_ProductLevel"

eststo clear
project, original("$da/GE_MarketData_Panel_ECMA.dta")
use "$da/GE_MarketData_Panel_ECMA.dta", clear

local maxrad = 4
local maxlag = 18
local maxlead = 6

******************************************************
** I. Figures showing raw price series by treatment **
******************************************************
preserve
xtile bin_cum_share_ge_elig_4km = cum_share_ge_elig_4km, n(4)

replace cum_pp_actamt_4km = cum_pp_actamt_4km*12 // this turns it from relative to yearly to monthly GDP.
bys month: egen avg_cum_pp_actamt_4km = wtmean(cum_pp_actamt_4km), weight(cum_p_total_4km)
keep if inrange(month,tm(2014m8),tm(2017m1))

collapse (first) avg_cum_pp_actamt_4km (mean) pidx*, by(month bin_cum_share_ge_elig_4km)

tw (bar avg_cum_pp_actamt_4km month, yaxis(2) color(%5)) (line pidx_wKLPS_med month if bin_cum_share_ge_elig_4km == 1, yaxis(1)) (line pidx_wKLPS_med month if bin_cum_share_ge_elig_4km == 1, yaxis(1)) (line pidx_wKLPS_med month if bin_cum_share_ge_elig_4km == 3, yaxis(1)) (line pidx_wKLPS_med month if bin_cum_share_ge_elig_4km == 4, yaxis(1)) ///
, title("Price index by share of eligibles treated within 4km") subtitle("all goods") ytitle("log price index", axis(1)) ytitle("Share of monthly GDP tranfered to 4km buffer", axis(2)) xtitle("") legend(rows(1) order(2 "very low" 3 "low" 4 "high" 5 "very high")) scheme(tufte)
graph export "$dfig/FigureH1_PriceSeries_byShareElig.pdf", as(pdf) replace

/* The optional code below creates the analogous figure (H1) for different price sub-indices 
cap mkdir $dfig/FigH1_PriceSeries_ByShareElig
foreach cat in food nondur live dur tempt durall ndall {
	if ("`cat'" == "food") local name = "food items"
	if ("`cat'" == "nondur") local name = "nondurable goods"
	if ("`cat'" == "live") local name = "livestock"
	if ("`cat'" == "dur") local name = "durable goods"
	if ("`cat'" == "tempt") local name = "temptation goods"
	if ("`cat'" == "durall") local name = "all durable goods"
	if ("`cat'" == "ndall") local name = "all nondurable goods"

	tw (bar avg_cum_pp_actamt_4km month, yaxis(2) color(%5)) (line pidx_wKLPS_`cat'_med month if bin_cum_share_ge_elig_4km == 1) (line pidx_wKLPS_`cat'_med month if bin_cum_share_ge_elig_4km == 1) (line pidx_wKLPS_`cat'_med month if bin_cum_share_ge_elig_4km == 3) (line pidx_wKLPS_`cat'_med month if bin_cum_share_ge_elig_4km == 4) ///
	, title("Price index by share treated eligibles within 4km") subtitle("`name'") ytitle("log price index", axis(1)) ytitle("Share of monthly GDP tranfered to 4km buffer", axis(2)) xtitle("") legend(rows(1) order(2 "very low" 3 "low" 4 "high" 5 "very high")) scheme(tufte)
	graph export "$dfig/FigH1_PriceSeries_ByShareElig/FigureH1_PriceSeries_`cat'_byShareElig.pdf", as(pdf) replace
}
*/
restore


************************************************
** II. Figure with IRF, fixing radius and lag **
************************************************

** ii. Cumulative effects of a one-time shock -- lags only **
*************************************************************

local name = "all goods"
local regressors = ""
forval r = 2(2)`maxrad'	{
	local r2 = `r' - 2
	local regressors = "`regressors'" + " L(0/`maxlag').pp_actamt_`r2'to`r'km"
}

ols_spatial_HAC pidx_wKLPS_med `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

local length = `maxlag' + 1
matrix coefs = J(`length',3,.)
matrix scale_coefs = J(`length',3,.)

local elasstring = "0"

local coef = 0
local xlab = ""
forval l = 0(1)`maxlag'{
	local coef = `coef' + 1
	local xlab = `"`xlab' `coef' "`l'" "'

	forval r = 2(2)`maxrad' {
		local r2 = `r' - 2

		local elasstring = "`elasstring'" + "+" + "L`l'" + "." + "pp_actamt_`r2'to`r'km" + "/12"
	}

	lincom "`elasstring'"
	matrix coefs[`l'+1,1] = `r(estimate)', `r(estimate)' - invttail(`r(df)',0.023)*`r(se)', `r(estimate)' + invttail(`r(df)',0.023)*`r(se)'
}

coefplot matrix(coefs[,1]), ci((coefs[,2] coefs[,3])) ciopts(recast(rcap)) vertical yline(0) ytitle("elasticity of prices wrt tranfers as a share of GDP") xtitle("months since shock") xlabel(`xlab') /*title("IRF (cumulative) of treatment on prices (`name')") subtitle("amount transfered per GDP up to the 2 to 4km buffer")*/ scheme(tufte)
graph export "$dfig/FigureH2_IRF_CumulativePriceElasticity.pdf", as(pdf) replace
	
/* The following optional code creates analogous figures for each of the other price sub-indices
cap mkdir $dfig/FigH2_PriceIRF/
foreach idx in pidx_wKLPS_food_med pidx_wKLPS_nondur_med pidx_wKLPS_live_med pidx_wKLPS_dur_med pidx_wKLPS_tempt_med pidx_wKLPS_durall_med pidx_wKLPS_ndall_med {
	if ("`idx'" == "pidx_wKLPS_med") local name = "all goods"
	if ("`idx'" == "pidx_wKLPS_food_med") local name = "food items"
	if ("`idx'" == "pidx_wKLPS_nondur_med") local name = "nondurable goods"
	if ("`idx'" == "pidx_wKLPS_live_med") local name = "livestock"
	if ("`idx'" == "pidx_wKLPS_dur_med") local name = "durable goods"
	if ("`idx'" == "pidx_wKLPS_tempt_med") local name = "temptation goods"
	if ("`idx'" == "pidx_wKLPS_durall_med") local name = "all durable goods"
	if ("`idx'" == "pidx_wKLPS_ndall_med") local name = "all nondurable goods"

	local regressors = ""
	forval r = 2(2)`maxrad'	{
		local r2 = `r' - 2
		local regressors = "`regressors'" + " L(0/`maxlag').pp_actamt_`r2'to`r'km"
	}

	ols_spatial_HAC `idx' `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

	local length = `maxlag' + 1
	matrix coefs = J(`length',3,.)
	matrix scale_coefs = J(`length',3,.)

	local elasstring = "0"

	local coef = 0
	local xlab = ""
	forval l = 0(1)`maxlag'{
		local coef = `coef' + 1
		local xlab = `"`xlab' `coef' "`l'" "'

		forval r = 2(2)`maxrad' {
			local r2 = `r' - 2

			local elasstring = "`elasstring'" + "+" + "L`l'" + "." + "pp_actamt_`r2'to`r'km" + "/12"
		}

		lincom "`elasstring'"
		matrix coefs[`l'+1,1] = `r(estimate)', `r(estimate)' - invttail(`r(df)',0.023)*`r(se)', `r(estimate)' + invttail(`r(df)',0.023)*`r(se)'
	}
	
	local fname = concat(proper("`name'"))

	coefplot matrix(coefs[,1]), ci((coefs[,2] coefs[,3])) ciopts(recast(rcap)) vertical yline(0) ytitle("elasticity of prices wrt tranfers as a share of GDP") xtitle("months since shock") xlabel(`xlab') /*title("IRF (cumulative) of treatment on prices (`name')") subtitle("amount transfered per GDP up to the 2 to 4km buffer")*/ scheme(tufte)
	graph export "$dfig/FigH2_PriceIRF/FigureH2_IRF_CumulativePriceElasticity_`fname'.pdf", as(pdf) replace
}
*/


** ii. Cumulative effects of a one-time shock -- leads and lags **
******************************************************************

/* The following optional code creates the analogous figure (H2) -- but adds leads to test pre-trends:

foreach idx in pidx_wKLPS_med pidx_wKLPS_food_med pidx_wKLPS_nondur_med pidx_wKLPS_live_med pidx_wKLPS_dur_med pidx_wKLPS_tempt_med pidx_wKLPS_durall_med pidx_wKLPS_ndall_med {
	if ("`idx'" == "pidx_wKLPS_med") local name = "all goods"
	if ("`idx'" == "pidx_wKLPS_food_med") local name = "food items"
	if ("`idx'" == "pidx_wKLPS_nondur_med") local name = "nondurable goods"
	if ("`idx'" == "pidx_wKLPS_live_med") local name = "livestock"
	if ("`idx'" == "pidx_wKLPS_dur_med") local name = "durable goods"
	if ("`idx'" == "pidx_wKLPS_tempt_med") local name = "temptation goods"
	if ("`idx'" == "pidx_wKLPS_durall_med") local name = "all durable goods"
	if ("`idx'" == "pidx_wKLPS_ndall_med") local name = "all nondurable goods"

	local regressors = ""
	forval r = 2(2)`maxrad'	{
		local r2 = `r' - 2

		forval lead = `maxlead'(-1)1 {
			local regressors = "`regressors'" + " F`lead'.pp_actamt_`r2'to`r'km"
		}
		local regressors = "`regressors'" + " L(0/`maxlag').pp_actamt_`r2'to`r'km"
	}

	ols_spatial_HAC `idx' `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

	local length = `maxlead' + `maxlag' + 1
	matrix coefs = J(`length',3,.)
	matrix scale_coefs = J(`length',3,.)

	local elasstring = "0"

	local coef = 0
	local xlab = ""
	forval lead = `maxlead'(-1)1{
		local coef = `coef' + 1
		local xlab = `"`xlab' `coef' "-`lead'" "'

		forval r = 2(2)`maxrad' {
			local r2 = `r' - 2

			local elasstring = "`elasstring'" + "+" + "F`lead'" + "." + "pp_actamt_`r2'to`r'km" + "/12"
		}

		lincom "`elasstring'"
		matrix coefs[`coef',1] = `r(estimate)', `r(estimate)' - invttail(`r(df)',0.023)*`r(se)', `r(estimate)' + invttail(`r(df)',0.023)*`r(se)'
	}

	forval l = 0(1)`maxlag'{
		local coef = `coef' + 1
		local xlab = `"`xlab' `coef' "`l'" "'

		forval r = 2(2)`maxrad' {
			local r2 = `r' - 2

			local elasstring = "`elasstring'" + "+" + "L`l'" + "." + "pp_actamt_`r2'to`r'km" + "/12"
		}

		lincom "`elasstring'"
		matrix coefs[`coef',1] = `r(estimate)', `r(estimate)' - invttail(`r(df)',0.023)*`r(se)', `r(estimate)' + invttail(`r(df)',0.023)*`r(se)'
	}

	local fname = concat(proper("`name'"))
	local addline = `maxlead' + 0.5
	coefplot matrix(coefs[,1]), ci((coefs[,2] coefs[,3])) ciopts(recast(rcap)) vertical xline(`addline', lcolor(maroon)) yline(0) ytitle("elasticity of prices wrt tranfers as a share of GDP") xtitle("months since shock") xlabel(`xlab') /*title("IRF (cumulative) of treatment on prices (`name')") subtitle("amount transfered per GDP up to the 2 to 4km buffer")*/ scheme(tufte)
	graph export "$dfig/FigH2_PriceIRF/FigureH2_IRF_CumulativePriceElasticity_withLeads_`filename'.pdf", as(pdf) replace
}
*/



******************************************
** III. Product-Level Price Regressions **
******************************************

cap mkdir "$dt/PriceAnalysis_ProductLevel/"
project, original("$da/GE_MarketData_Panel_ProductLevel_ECMA.dta")
use "$da/GE_MarketData_Panel_ProductLevel_ECMA.dta", clear

** drop observations to get a balanced panel **
*******************************************************
foreach v of varlist med_p_* min_p_* {
	replace `v' = . if month < tm(2014m12)
	replace `v' = . if month > tm(2017m1)
}

eststo clear

** I. Run the 0to2km and 2to4km contemporaneous buffer **
***************************************************
local product_list "avocado banana battery beans beef biscuit bleach bread bull cabbage cake calf cassava cement charcoal chicken cigarettes cowpea egg fat firewood fish goat  greengrams groundnuts ironsheet jackfruit jerrycan kale kerosene leso maize maizeflour mango mattress milk milkferment millet nails onions orange padlock paint panadol papaya passion pineapple plantains pork potatoes rice roofnails saka sheep slippers soap soda sorghum sufuria sugar sweetpotato tealeaves thermos timber tomatoes toothpaste vaseline washingpowder watermelon wheatflour"

di wordcount("`product_list'")

foreach prod of local product_list  {
	mata: p=1
	mata: j=1

		** get list of regressors **
		local regressors pp_actamt_0to2km pp_actamt_2to4km

		** Fix R2 **
		sort market_id month
		reg med_p_`prod' `regressors' m_* mkt_*
		scalar a = `=e(r2)'

		eststo: ols_spatial_HAC med_p_`prod' `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

		** Get mean and 90-10 percentile range for each treatment **
		local ATEstring = "0"
		local p9010string = "0"
		local maxstring = "0"

		local mean_scalars
		local maxmean_scalars

		** select month with the maximum predicted effect **
		gen maxmonth = 0
		foreach v of var `regressors' {
			replace maxmonth = maxmonth + _b[`v']*`v'
		}
		replace maxmonth = abs(maxmonth) // this selects the effect with the largest absolute effect (positive or negative)
		bysort market_id: egen a = max(maxmonth)
		replace maxmonth = (maxmonth == a)
		bysort market_id maxmonth: replace maxmonth = 0 if _n > 1
		drop a
		sort market_id month

		foreach v of var `regressors' {
			sum `v' if inrange(month,tm(2014m09),tm(2017m03)), d
			local name = subinstr("`v'",".","_",.)
			estadd scalar mean_`name' = r(mean), replace
			local mean_scalars `mean_scalars' mean_`name'

			local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"
			local p9010string = "`p9010string'" + "+" + "`r(p90)'" + "*" + "`v'" + "-" + "`r(p10)'" + "*" + "`v'"

			** get mean of the maximum predicted effect **
			sum `v' if maxmonth == 1
			local name = subinstr("`v'",".","_",.)
			estadd scalar maxmean_`name' = r(mean), replace
			local maxmean_scalars `maxmean_scalars' maxmean_`name'

			local maxstring = "`maxstring'"	+ "+" + "`r(mean)'" + "*" + "`v'"
		}
		drop maxmonth

		lincom "`ATEstring'"
		estadd scalar ATE = `r(estimate)'
		estadd scalar ATE_se = `r(se)'
		lincom "`p9010string'"
		estadd scalar p9010 = `r(estimate)'
		estadd scalar p9010_se = `r(se)'
		lincom "`maxstring'"
		estadd scalar max = `r(estimate)'
		estadd scalar max_se = `r(se)'

		estadd scalar r2 = a, replace
}

esttab using "$dt/PriceAnalysis_ProductLevel/ProductLevel_pp_actamt_0to4km_noLag.csv", drop(m_* mkt_*) se noconstant r2 star(* 0.10 ** 0.05 *** 0.01) se(8) b(8) scalars(`mean_scalars' ATE ATE_se `maxmean_scalars' max max_se) replace
project, creates("$dt/PriceAnalysis_ProductLevel/ProductLevel_pp_actamt_0to4km_noLag.csv")
eststo clear



/*
* The following is optional code that runs price impact analyses at the product level
* by re-estimating the 'optimal' radii and lags for each product

** II. Run the optimal radius and lag **
****************************************
loc tp "med"
loc inst "pp_actamt"
global ic = 6

foreach prod of local product_list {
	mata: p=1
	mata: j=1

		** get list of regressors **
		****************************

		**** Space ****
		mata: bic_w_`tp'_`inst' = .,.,.,.,.,.,.,.,.,.

		forval r = 2(2)20 {
			local r2 = `r' - 2
			qui reg med_p_`prod' tcum_l2_`inst'_0to2km-tcum_l2_`inst'_`r2'to`r'km i.month i.market_id
			estat ic
			mata: bic_w_`tp'_`inst'[`r'/2] = st_matrix("r(S)")[$ic]
		}

		mata: bic_w_`tp'_`inst'

		mata: optr_m = select((1::10)', (bic_w_`tp'_`inst' :== min(bic_w_`tp'_`inst')))
		mata: stata("local optr = " + strofreal(optr_m*2))

		**** Time ****
		mata: j = 1
		mata: bic_w_`tp'_`inst' =  .,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.

		** get the maximum amount of lags **
		sum month if `inst'_0to2km != .
		local maxlag = min(`r(max)'-`r(min)'- 1,24)

		** get the optimal number of radii bands **
		forval lag = 0(1)`maxlag' {

			** get list of regressors **
			local regressors
			forval r = 2(2)`optr' {
				local r2 = `r' - 2
				local regressors `regressors' l(0/`lag').`inst'_`r2'to`r'km
			}

			capture: reg med_p_`prod' `regressors' i.month i.market_id
			capture: estat ic
			loc cmonstata = `lag'+1
			if _rc != 321 {
				mata: bic_w_`tp'_`inst'[`cmonstata'] = st_matrix("r(S)")[$ic]
			}
		}
		mata: bic_w_`tp'_`inst'

		mata: optlag_m = select((1::length(bic_w`weights'_`tp'_`inst'))', (bic_w`weights'_`tp'_`inst'[1..length(bic_w`weights'_`tp'_`inst')] :== min(bic_w`weights'_`tp'_`inst')))
		mata: stata("local optlag = " + strofreal(optlag_m))

		* Obtain regressors *
		local regressors
		forval r = 2(2)`optr' {
			local r2 = `r' - 2
			local regressors `regressors' l(0/`optlag').`inst'_`r2'to`r'km
		}

		** Fix R2 **
		sort market_id month
		reg med_p_`prod' `regressors' m_* mkt_*
		scalar a = `=e(r2)'

		eststo: ols_spatial_HAC med_p_`prod' `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

		** Get mean and 90-10 percentile range for each treatment **
		local ATEstring = "0"
		local p9010string = "0"
		local maxstring = "0"

		local mean_scalars
		local maxmean_scalars

		** select month with the maximum predicted effect **
		gen maxmonth = 0
		foreach v of var `regressors' {
			replace maxmonth = maxmonth + _b[`v']*`v'
		}
		replace maxmonth = abs(maxmonth) // this selects the effect with the largest absolute effect (positive or negative)
		bysort market_id: egen a = max(maxmonth)
		replace maxmonth = (maxmonth == a)
		bysort market_id maxmonth: replace maxmonth = 0 if _n > 1
		drop a
		sort market_id month

		foreach v of var `regressors' {
			sum `v' if inrange(month,tm(2014m09),tm(2017m03)), d
			local name = subinstr("`v'",".","_",.)
			estadd scalar mean_`name' = r(mean), replace
			local mean_scalars `mean_scalars' mean_`name'

			local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"
			local p9010string = "`p9010string'" + "+" + "`r(p90)'" + "*" + "`v'" + "-" + "`r(p10)'" + "*" + "`v'"

			** get mean of the maximum predicted effect **
			sum `v' if maxmonth == 1
			local name = subinstr("`v'",".","_",.)
			estadd scalar maxmean_`name' = r(mean), replace
			local maxmean_scalars `maxmean_scalars' maxmean_`name'

			local maxstring = "`maxstring'"	+ "+" + "`r(mean)'" + "*" + "`v'"
		}
		drop maxmonth

		lincom "`ATEstring'"
		estadd scalar ATE = `r(estimate)'
		estadd scalar ATE_se = `r(se)'
		lincom "`p9010string'"
		estadd scalar p9010 = `r(estimate)'
		estadd scalar p9010_se = `r(se)'
		lincom "`maxstring'"
		estadd scalar max = `r(estimate)'
		estadd scalar max_se = `r(se)'

		estadd scalar optr = `optr'
		estadd scalar optlag = `optlag'

		estadd scalar r2 = a, replace
}

esttab using "$dt/PriceAnalysis_ProductLevel/ProductLevel_pp_actamt_optimal.csv", drop(m_* mkt_*) se noconstant r2 star(* 0.10 ** 0.05 *** 0.01) se(8) b(8) scalars(`mean_scalars' ATE ATE_se `maxmean_scalars' max max_se optr optlag) replace
eststo clear
*/
