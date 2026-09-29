**** Spatial Randomization Inference for Price Outcomes ****


* Preliminaries
capture project, doinfo
if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
else {  // running directly
	if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
	do "${ge_dir}/do/set_environment.do"
}

set varabbrev on

** defining globals **
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"

cap mkdir $dt/markets_ri_draws/

** Include program for re-drawing of spatial datasets **
project, original("$dir/do/programs/draw_alternative_allocation_markets.do")
include "$dir/do/programs/draw_alternative_allocation_markets.do"

** defining globals **
project, original("$dir/do/GE_global_setup.do")
project, original("$do/analysis/prep/RI_setreps.do")
include "$dir/do/GE_global_setup.do"

*** generating log file ***
capture project, doinfo
if (_rc==0 & !mi(r(pname))) {
}
else {
	cap log close
	log using "$dl/OutputPrices_RunMidlinePAPAlgorithm_RI_`c(current_date)'.txt", replace text
}

** Set number of repetitions **
*******************************
include "$do/analysis/prep/RI_setreps.do"

global RIreps = $RI_reps
global drawnew = $RI_draw
global Breps = 5

global RI = 1
global bootstrap = 0

** Deal with Information criterion choice **
********************************************
global BIC = 1
global AIC = 0

if $BIC == 1 {
	global ic = 6
	global icname = "bic"
}

if $AIC == 1 {
	global ic = 5
	global icname = "aic"
}

*******************************************
** Save prices and treatments separately **
*******************************************

project, original("$da/GE_MarketData_Panel_ECMA.dta")
use "$da/GE_MarketData_Panel_ECMA.dta", clear

** Dropping observations to get a balanced panel **
*******************************************************
foreach v of varlist pidx_* pidx2_* {
	replace `v' = . if month > tm(2017m1)
}



keep district subcounty location* sublocation* market_id mkt_* latitude longitude market_size distroad q2_distroad q4_distroad q2_market_access q4_market_access OnMainRoad distroad_* market_access market_code subloc_in_sample hi_sat post hi_sat_post month m_* pidx_* pidx2_*
save "$dt/MarketSurveyData_sanstreat.dta", replace

******************************************
** 	SET UP THE RANDOMIZATION INFERENCE ***
******************************************

if $RI == 1 {

capture program drop priceRI
program define priceRI, rclass

	global current_rep = $current_rep + 1

	** Draw new treatment assigment **
	use "$dt/MarketSurveyData_sanstreat.dta", clear

	capture confirm file "$dt/markets_ri_draws/ri_markets_draw$current_rep.dta"

	draw_alloc_markets, outdir("$dt/markets_ri_draws/ri_markets_draw$current_rep.dta")

	merge 1:1 market_code month using "$dt/markets_ri_draws/ri_markets_draw$current_rep.dta", nogen
	xtset market_code month

	*********************************************************************
	** i) Determine optimal spatial decay structure using Schwartz BIC **
	*********************************************************************
	eststo clear

	** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
	** spatial-autocorrelation consistent method to determine the optimal decay structure **
	mata: optr = .,.,.,.,.,.,.,.,.,.

	local regvars ""
	forval r = 2(2)20 {
		local r2 = `r' - 2
		local regvars "`regvars' ri_tcum_l2_pp_amt_`r2'to`r'km"
		qui reg pidx_wKLPS_med `regvars' i.month i.market_id
		qui estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[$ic]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)

	**************************************************************************************************
	** ii) For the optimal spatial specification, determine optimal lag structure using Schwartz BIC **
	**************************************************************************************************

	** Calculate Optimal number of lags **
	**************************************

	** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
	** spatial-autocorrelation consistent method to determine the optimal decay structure **
	mata: j = 1
	mata: optlag = .

	** get the maximum amount of lags **
	sum month if ri_pp_amt_0to2km != .
	local maxlag = min(`r(max)'-`r(min)'- 1,24)

	** get the optimal number of radii bands **
	local optr = optr

	forval lag = 0(1)`maxlag' {

		** get list of regressors **
		local regressors
		forval r = 2(2)`optr' {
			local r2 = `r' - 2
			local regressors `regressors' l(0/`lag').ri_pp_amt_`r2'to`r'km
		}

		capture: reg pidx_wKLPS_med `regressors' i.month i.market_id
		capture: estat ic
		if _rc != 321 {
			mata: optlag = optlag,st_matrix("r(S)")[$ic]
		}
	}


	mata: st_numscalar("optlag", select((1::length(optlag)-1)', (optlag[2..length(optlag)] :== min(optlag)))-1)
	local optlag = optlag

	****************************************************************************************************
	** iii) For each specification, run the version with the optimal lag and spatial decay structures **
	****************************************************************************************************

	mata: j=0
	foreach price in med trade_med nontrade_med food_med nondur_med dur_med live_med tempt_med /* durall_med ndall_med */ {
		mata: j++
		di "Loop for `price'"

		** get optimal lags and optimal radii bands **
		di "local optr = " optr
		di "local optlag = " optlag


		** 1. First and second column: Main average effects **
		******************************************************

		** get list of regressors **
		local regressors
		forval r = 2(2)`optr' {
			local r2 = `r' - 2
			local regressors `regressors' l(0/`optlag').ri_pp_amt_`r2'to`r'km
		}

		*ols_spatial_HAC pidx_wKLPS_`price' `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar
		*can use spatial_HAC if we want to use Conley-based t-stat in every iteration
		reg pidx_wKLPS_`price' `regressors' m_* mkt_*

		** Get mean and maxmean treatment **
		local ATEstring = "0"
		local maxstring = "0"

		** select month with the maximum transfers in the largest selected buffer **
		gsort market_id -ri_cum_pp_amt_`optr'km
		bys market_id: gen maxmonth = (_n == 1)
		sort market_id month

		foreach v of var `regressors' {
			sum `v' if inrange(month,tm(2014m09),tm(2017m03)), d
			local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"

			** get mean of the maximum predicted effect **
			sum `v' if maxmonth == 1
			local maxstring = "`maxstring'"	+ "+" + "`r(mean)'" + "*" + "`v'"
		}

		drop maxmonth

		disp "`ATEstring'"
		lincom "`ATEstring'"

		** Generate Output **
		return scalar ATE_`price' = r(estimate)
		return scalar t_ATE_`price' = r(t)

		disp "`maxstring'"
		lincom "`maxstring'"

		** formatting for tex - column 2 **
		return scalar AME_`price' = r(estimate)
		return scalar t_AME_`price' = r(t)

		** 3. 5th / 6th column: ATE above / below median of market access **
		*****************************************************************
		forval nq = 1(1)2 {

			** get list of regressors **
			local regressors
			forval r = 2(2)`optr' {
				local r2 = `r' - 2
				local regressors `regressors' l(0/`optlag').ri_pp_amt_`r2'to`r'km
			}

			*ols_spatial_HAC pidx_wKLPS_`price' `regressors' m_* mkt_* if q2_market_access == `nq', lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar
			*can use spatial_HAC if we want to use Conley-based t-stat in every iteration
			reg pidx_wKLPS_`price' `regressors' m_* mkt_* if q2_market_access == `nq'

			** Get mean treatment **
			local ATEstring = "0"

			foreach v of var `regressors' {
				sum `v' if inrange(month,tm(2014m09),tm(2017m03)) & q2_market_access == `nq' , d
				local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"
			}

			disp "`ATEstring'"
			lincom "`ATEstring'"

			** formatting for tex - column 5/6 **
			return scalar ATE_`price'_ma`nq' = r(estimate)
			return scalar t_ATE_`price'_ma`nq' = r(t)
		}
	}
	end

	** Run the Randomization Inference simulation **
	************************************************
	foreach price in med trade_med nontrade_med food_med nondur_med dur_med live_med tempt_med /* durall_med ndall_med */ {
		local simulationstring = "`simulationstring' ATE_`price' = r(ATE_`price') t_ATE_`price' = r(t_ATE_`price') AME_`price' = r(AME_`price') t_AME_`price' = r(t_AME_`price') ATE_`price'_ma1 = r(ATE_`price'_ma1) t_ATE_`price'_ma1 = r(t_ATE_`price'_ma1) ATE_`price'_ma2 = r(ATE_`price'_ma2) t_ATE_`price'_ma2 = r(t_ATE_`price'_ma2)"
	}

	set seed 20201021
	set sortseed 20201022

	use "$dt/MarketSurveyData_sanstreat.dta", clear
	global current_rep = ""
	simulate `simulationstring', reps($RIreps) seed(12345): priceRI


	** Output the Randomization Inference results **
	************************************************
	save "$dt/RI_rawoutput_OutputPrices_${RIreps}reps.dta", replace
	project, creates("$dt/RI_rawoutput_OutputPrices_${RIreps}reps.dta") preserve
}


*******************************************************************
*** NOW RUN MAIN TABLE -- WITH ADDED RI P-VALUES / BOOTSTRAP SE ***
*******************************************************************
use "$da/GE_MarketData_Panel_ECMA.dta", clear


** Drop observations to get a balanced panel **
*******************************************************

foreach v of varlist pidx_* pidx2_* {
	replace `v' = . if month > tm(2017m1)
}

*********************************************************************
** i) Determine optimal spatial decay structure using Schwartz BIC **
*********************************************************************

** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
** spatial-autocorrelation consistent method to determine the optimal decay structure **
mata: bic_wKLPS_med_pp_actamt = .,.,.,.,.,.,.,.,.,.

forval r = 2(2)20 {
	local r2 = `r' - 2
	qui reg pidx_wKLPS_med tcum_l2_pp_actamt_0to2km-tcum_l2_pp_actamt_`r2'to`r'km i.month i.market_id
	qui estat ic
	mata: bic_wKLPS_med_pp_actamt[`r'/2] = st_matrix("r(S)")[$ic]
}

mata: optr_pidx_wKLPS_med_pp_actamt = select((1::10)', (bic_wKLPS_med_pp_actamt :== min(bic_wKLPS_med_pp_actamt)))

foreach cat in trade nontrade food dur nondur live tempt {
	mata: bic_wKLPS_`cat'_med_pp_actamt = .,.,.,.,.,.,.,.,.,.
	forval r = 2(2)20 {
		local r2 = `r' - 2
		qui reg pidx_wKLPS_`cat'_med tcum_l2_pp_actamt_0to2km-tcum_l2_pp_actamt_`r2'to`r'km i.month i.market_id
		qui estat ic
		mata: bic_wKLPS_`cat'_med_pp_actamt[`r'/2] = st_matrix("r(S)")[$ic]
	}

	mata: optr_pidx_wKLPS_med_pp_actamt = optr_pidx_wKLPS_med_pp_actamt,select((1::10)', (bic_wKLPS_`cat'_med_pp_actamt :== min(bic_wKLPS_`cat'_med_pp_actamt)))
}

**************************************************************************************************
** ii) For the optimal spatial specification, determine optimal lag structure using Schwartz BIC **
**************************************************************************************************

** Calculate Optimal number of lags **
**************************************

** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
** spatial-autocorrelation consistent method to determine the optimal decay structure **

mata: j = 1
mata: bic_wKLPS_med_pp_actamt = .

** get the maximum amount of lags **
sum month if pp_actamt_0to2km != .
local maxlag = min(`r(max)'-`r(min)'- 1,24)

** get the optimal number of radii bands **
mata: stata("local optr = " + strofreal(optr_pidx_wKLPS_med_pp_actamt[1,j]*2))

forval lag = 0(1)`maxlag' {

	** get list of regressors **
	local regressors
	forval r = 2(2)`optr' {
		local r2 = `r' - 2
		local regressors `regressors' l(0/`lag').pp_actamt_`r2'to`r'km
	}

	capture: reg pidx_wKLPS_med `regressors' i.month i.market_id
	capture: estat ic
	if _rc != 321 {
		mata: bic_wKLPS_med_pp_actamt = bic_wKLPS_med_pp_actamt,st_matrix("r(S)")[$ic]
	}
}

mata: optlag_pidx_wKLPS_med_pp_actamt = select((1::length(bic_wKLPS_med_pp_actamt)-1)', (bic_wKLPS_med_pp_actamt[2..length(bic_wKLPS_med_pp_actamt)] :== min(bic_wKLPS_med_pp_actamt)))-1

foreach cat in trade nontrade food dur nondur live tempt {

	** get the optimal number of radii bands **
	mata: j++
	mata: stata("local optr = " + strofreal(optr_pidx_wKLPS_med_pp_actamt[1,j]*2))

	mata: bic_wKLPS_`cat'_med_pp_actamt = .

	forval lag = 0(1)`maxlag' {

		** get list of regressors **
		local regressors
		forval r = 2(2)`optr' {
			local r2 = `r' - 2
			local regressors `regressors' l(0/`lag').pp_actamt_`r2'to`r'km
		}

		capture: reg pidx_wKLPS_med `regressors' i.month i.market_id
		capture: estat ic
		if _rc != 321 {
			mata: bic_wKLPS_`cat'_med_pp_actamt = bic_wKLPS_`cat'_med_pp_actamt,st_matrix("r(S)")[$ic]
		}
	}
	mata: optlag_pidx_wKLPS_med_pp_actamt = optlag_pidx_wKLPS_med_pp_actamt,select((1::length(bic_wKLPS_`cat'_med_pp_actamt)-1)', (bic_wKLPS_`cat'_med_pp_actamt[2..length(bic_wKLPS_`cat'_med_pp_actamt)] :== min(bic_wKLPS_`cat'_med_pp_actamt)))-1
}

****************************************************************************************************
** iii) For each specification, run the version with the optimal lag and spatial decay structures **
****************************************************************************************************
eststo clear

* setting up blank table *
drop _all
local ncols = 4
local nrows = 4

*** CREATE EMPTY TABLE ***
eststo clear
est drop _all
set obs `nrows'
gen x = 1
gen y = 1

forvalues x = 1/`ncols' {
	eststo col`x': reg x y
}

local varcount = 1
local count = 1
local countse = `count' + 1
local countbse = `count' + 1 + $bootstrap
local countp = `count' + 1 + $bootstrap + $RI
local countspace = `count' + 2 + $bootstrap + $RI

local varlabels ""
local statnames ""
local collabels ""

mata: output_table = .,.,.,.,.
scalar numoutcomes = 0

use "$da/GE_MarketData_Panel_ECMA.dta", clear

** Here, I drop observations to get a balanced panel **
*******************************************************

foreach v of varlist pidx_* pidx2_* {
	replace `v' = . if month > tm(2017m1)
}

mata: j=0
foreach price in med trade_med nontrade_med food_med nondur_med dur_med live_med tempt_med /* durall_med ndall_med */ {
	mata: j++
	di "Loop for `price'"

	scalar numoutcomes = numoutcomes + 1

	** adding variable label to the table **
	local add : var label pidx_wKLPS_`price'
	local collabels `"`collabels' "`add'""'

	** get optimal lags and optimal radii bands **
	mata: stata("local optr = " + strofreal(optr_pidx_wKLPS_med_pp_actamt[1,1]*2))
	mata: stata("local optlag = " + strofreal(optlag_pidx_wKLPS_med_pp_actamt[1,1]))


	** 1. First and second column: Main average effects **
	******************************************************

	** get list of regressors **
	local regressors
	forval r = 2(2)`optr' {
		local r2 = `r' - 2
		local regressors `regressors' l(0/`optlag').pp_actamt_`r2'to`r'km
	}

	ols_spatial_HAC pidx_wKLPS_`price' `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

	** Get mean and maxmean treatment **
	local ATEstring = "0"
	local maxstring = "0"

	** select month with the maximum transfers in the largest selected buffer **
	gsort market_id -cum_pp_actamt_`optr'km
	bys market_id: gen maxmonth = (_n == 1)
	sort market_id month

	foreach v of var `regressors' {
		sum `v' if inrange(month,tm(2014m09),tm(2017m03)), d
		local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"

		** get mean of the maximum predicted effect **
		sum `v' if maxmonth == 1
		local maxstring = "`maxstring'"	+ "+" + "`r(mean)'" + "*" + "`v'"
	}

	drop maxmonth

	disp "`ATEstring'"
	lincom "`ATEstring'"
	scalar main_ATE_`price' = r(estimate)

	** formatting for tex - column 1 **
	pstar, b(`r(estimate)') se(`r(se)') precision(4) //p(`r(p)')
	estadd local thisstat`count' = "`r(bstar)'": col1
	estadd local thisstat`countse' = "& `r(sestar)'": col1

	** Add RI p-values **
	if $RI == 1 {
		preserve
		use "$dt/RI_rawoutput_OutputPrices_${RIreps}reps.dta", clear
		count if abs(ATE_`price') > abs(main_ATE_`price')
		scalar num = `r(N)'
		count if ATE_`price' != .
		estadd local thisstat`countp' = "& [" + string(num/`r(N)', "%9.3f") + "]": col1
		restore
	}

	disp "`maxstring'"
	lincom "`maxstring'"
	scalar main_AME_`price' = r(estimate)

	** formatting for tex - column 2 **
	pstar, b(`r(estimate)') se(`r(se)') precision(4) //p(`r(p)')
	estadd local thisstat`count' = "`r(bstar)'": col2
	estadd local thisstat`countse' = "`r(sestar)'": col2

	** Add RI p-values **
	if $RI == 1 {
		preserve
		use "$dt/RI_rawoutput_OutputPrices_${RIreps}reps.dta", clear
		count if abs(AME_`price') > abs(main_AME_`price')
		scalar num = `r(N)'
		count if AME_`price' != .
		estadd local thisstat`countp' = "[" + string(num/`r(N)', "%9.3f") + "]": col2
		restore
	}

	** Add bootstrap standard errors **
	if $bootstrap == 1 {
		preserve
		xtset, clear
		bootstrap, cluster(market_code) idcluster(mkt_cluster) seed(12345) rep($Breps): reg pidx_wKLPS_med `regressors' i.month i.mkt_cluster

		lincom "`ATEstring'"
		pstar, b(`r(estimate)') se(`r(se)') precision(4) sebrackets //p(`r(p)')
		estadd local thisstat`countbse' = "& `r(sestar)'": col1

		lincom "`maxstring'"
		pstar, b(`r(estimate)') se(`r(se)') precision(4) sebrackets //p(`r(p)')
		estadd local thisstat`countbse' = "`r(sestar)'": col2
		restore
	}

	** 3. 5th / 6th column: ATE above / below median of market access **
	*****************************************************************
	forval nq = 1(1)2 {
		local clmn = `nq' + 2

		** get list of regressors **
		local regressors
		forval r = 2(2)`optr' {
			local r2 = `r' - 2
			local regressors `regressors' l(0/`optlag').pp_actamt_`r2'to`r'km
		}

		ols_spatial_HAC pidx_wKLPS_`price' `regressors' m_* mkt_* if q2_market_access == `nq', lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

		** Get mean treatment **
		local ATEstring = "0"

		foreach v of var `regressors' {
			sum `v' if inrange(month,tm(2014m09),tm(2017m03)) & q2_market_access == `nq' , d
			local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"
		}

		disp "`ATEstring'"
		lincom "`ATEstring'"
		scalar main_ATE_`price'_ma`nq' = r(estimate)

		** formatting for tex - column 5/6 **
		pstar, b(`r(estimate)') se(`r(se)') precision(4) //p(`r(p)')
		estadd local thisstat`count' = "`r(bstar)'": col`clmn'
		estadd local thisstat`countse' = "`r(sestar)'": col`clmn'

		** Add RI p-values **
		if $RI == 1 {
			preserve
			use "$dt/RI_rawoutput_OutputPrices_${RIreps}reps.dta", clear
			count if abs(ATE_`price'_ma`nq') > abs(main_ATE_`price'_ma`nq')
			scalar num = `r(N)'
			count if ATE_`price'_ma`nq' != .
			estadd local thisstat`countp' = "[" + string(num/`r(N)', "%9.3f") + "]": col`clmn'
			restore
		}

		** Add bootstrap standard errors **
		if $bootstrap == 1 {
			preserve
			keep if q2_market_access == `nq'
			xtset, clear
			bootstrap, cluster(market_code) idcluster(mkt_cluster) seed(12345) rep($Breps): reg pidx_wKLPS_med `regressors' i.month i.mkt_cluster

			lincom "`ATEstring'"
			pstar, b(`r(estimate)') se(`r(se)') precision(4) sebrackets //p(`r(p)')
			estadd local thisstat`countbse' = "`r(sestar)'": col`clmn'
			restore
		}
	}

	** looping variables for tex table **
	if "pidx_wKLPS_`price'" == "pidx_wKLPS_med" {
		local thisvarlabel = "\textbf{All goods} &"
	}
	if "pidx_wKLPS_`price'" == "pidx_wKLPS_trade_med" {
		local thisvarlabel = "\textbf{By tradability} & More tradable"
	}

	if "pidx_wKLPS_`price'" == "pidx_wKLPS_nontrade_med" {
		local thisvarlabel = "& Less tradable"
	}

	if "pidx_wKLPS_`price'" == "pidx_wKLPS_food_med" {
		local thisvarlabel = "\textbf{By sector} & Food items"
	}

	if "pidx_wKLPS_`price'" == "pidx_wKLPS_nondur_med" {
		local thisvarlabel = "& Non-durables"
	}

	if "pidx_wKLPS_`price'" == "pidx_wKLPS_dur_med" {
		local thisvarlabel = "& Durables"
	}

	if "pidx_wKLPS_`price'" == "pidx_wKLPS_live_med" {
		local thisvarlabel = "& Livestock"
	}

	if "pidx_wKLPS_`price'" == "pidx_wKLPS_tempt_med" {
		local thisvarlabel = "& Temptation goods"
	}

	if numoutcomes == 1 {
		local varlabels `" " "`varlabels' "`thisvarlabel'" " " " " " " "'
		local statnames "thisstat`countspace' `statnames' thisstat`count' thisstat`countse' thisstat`countp' thisstat`countspace'"
	}
	else {
		local varlabels `"`varlabels' "`thisvarlabel'" " " " " " " "'
		local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countp' thisstat`countspace'"
	}

	local count = `count' + 3 + $bootstrap + $RI
	local countse = `count' + 1
	local countbse = `count' + 1 + $bootstrap
	local countp = `count' + 1 + $bootstrap + $RI
	local countspace = `count' + 2 + $bootstrap + $RI

	local ++varcount
}

di "End outcome loop"

*** exporting tex table ***
** dropping column 2 **
loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{ll*{5}{c}}\toprule &"
loc postfoot "\bottomrule\end{tabular}}"

di "Exporting tex file"
local name = "TableI13_RI_OutputPrices"
*if $RI == 1 local name = "`name'_withRI"
*if $bootstrap == 1 local name = "`name'_withBootstrap"
*local name = "`name'_${RIreps}reps.tex"

esttab col1 col2 col3 col4 using "$dtab/`name'.tex", cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("& \multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Overall Effects}}} & & \multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{ATE by market access)}}} \\   \cline{3-4}\cline{6-7}\\ \vspace{.2cm} & & \multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ ATE }}"  "\multicolumn{1}{c}{\shortstack{Average maximum \\ effect (AME)}}" "\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ below median}}" "\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ above median}}" /*"\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ 3rd quartile}}" "\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ 4th quartile}}"*/ ) stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')
project, creates("$dtab/`name'.tex") preserve
