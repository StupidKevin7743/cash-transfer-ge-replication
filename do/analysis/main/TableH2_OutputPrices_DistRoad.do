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
	log using "$dl/OutputPrices_RunMidlinePAPAlgorithm_`c(current_date)'.txt", replace text
}


eststo clear
project, original("$da/GE_MarketData_Panel_ECMA.dta")
use "$da/GE_MarketData_Panel_ECMA.dta", clear

** Deal with Information criterion choice **
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


** convert to logpoints **

**********************
** A. PRICE INDICES **
**********************

** Here, I drop observations to get a balanced panel **
*******************************************************

foreach v of varlist pidx_* pidx2_* {
	replace `v' = . if month > tm(2017m1)
}

*********************************************************************
** i) Determine optimal spatial decay structure using Schwartz BIC **
*********************************************************************

** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
** spatial-autocorrelation consistent method to determine the optimal decay structure **

foreach weights in KLPS { // GE {
	foreach tp in med { // min {
		mata: optr_pidx_w`weights'_`tp' = .,.,.,.,.,.,.,.

		foreach inst in pp_actamt {

			mata: bic_w`weights'_`tp'_`inst' = .,.,.,.,.,.,.,.,.,.

			forval r = 2(2)20 {
				local r2 = `r' - 2
				reg pidx_w`weights'_`tp' tcum_l2_`inst'_0to2km-tcum_l2_`inst'_`r2'to`r'km i.month i.market_id
				estat ic
				mata: bic_w`weights'_`tp'_`inst'[`r'/2] = st_matrix("r(S)")[$ic]
			}

			mata: optr_pidx_w`weights'_`tp'_`inst' = select((1::10)', (bic_w`weights'_`tp'_`inst' :== min(bic_w`weights'_`tp'_`inst')))

			foreach cat in trade nontrade food dur nondur live tempt {

			mata: bic_w`weights'_`cat'_`tp'_`inst' = .,.,.,.,.,.,.,.,.,.
				forval r = 2(2)20 {
					local r2 = `r' - 2
					reg pidx_w`weights'_`cat'_`tp' tcum_l2_`inst'_0to2km-tcum_l2_`inst'_`r2'to`r'km i.month i.market_id
					estat ic
					mata: bic_w`weights'_`cat'_`tp'_`inst'[`r'/2] = st_matrix("r(S)")[$ic]
				}

			mata: optr_pidx_w`weights'_`tp'_`inst' = optr_pidx_w`weights'_`tp'_`inst',select((1::10)', (bic_w`weights'_`cat'_`tp'_`inst' :== min(bic_w`weights'_`cat'_`tp'_`inst')))
			}

		mata: optr_pidx_w`weights'_`tp' = optr_pidx_w`weights'_`tp'\optr_pidx_w`weights'_`tp'_`inst'
		}
		di "check 1"
	mata: optr_pidx_w`weights'_`tp' = optr_pidx_w`weights'_`tp'[2::2,.]
	}
}
di "End select radii loop"


**************************************************************************************************
** ii) For the optimal spatial specification, determine optimal lag structure using Schwartz BIC **
**************************************************************************************************



** Calculate Optimal number of lags **
**************************************

** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
** spatial-autocorrelation consistent method to determine the optimal decay structure **
foreach weights in KLPS { // GE {
	foreach tp in med { // min {

		mata: optlag_pidx_w`weights'_`tp' = .,.,.,.,.,.,.,.
		mata: k = 0

			foreach inst in pp_actamt {
				mata: j = 1
				mata: bic_w`weights'_`tp'_`inst' = .

				** get the maximum amount of lags **
				sum month if `inst'_0to2km != .
				local maxlag = min(`r(max)'-`r(min)'- 1,24)

				** get the optimal number of radii bands **
				mata: k++
				mata: stata("local optr = " + strofreal(optr_pidx_w`weights'_`tp'[k,1]*2))

				di "Beginning lag loop"
				forval lag = 0(1)`maxlag' {

					** get list of regressors **
					local regressors
					forval r = 2(2)`optr' {
						local r2 = `r' - 2
						local regressors `regressors' l(0/`lag').`inst'_`r2'to`r'km
					}

					capture: reg pidx_w`weights'_`tp' `regressors' i.month i.market_id
					capture: estat ic
					if _rc != 321 {
						mata: bic_w`weights'_`tp'_`inst' = bic_w`weights'_`tp'_`inst',st_matrix("r(S)")[$ic]
					}
				}

				mata: optlag_pidx_w`weights'_`tp'_`inst' = select((1::length(bic_w`weights'_`tp'_`inst')-1)', (bic_w`weights'_`tp'_`inst'[2..length(bic_w`weights'_`tp'_`inst')] :== min(bic_w`weights'_`tp'_`inst')))-1

				foreach cat in trade nontrade food dur nondur live tempt {

					** get the optimal number of radii bands **
					mata: j++
					mata: stata("local optr = " + strofreal(optr_pidx_w`weights'_`tp'[k,j]*2))

					mata: bic_w`weights'_`cat'_`tp'_`inst' = .

					forval lag = 0(1)`maxlag' {

						** get list of regressors **
						local regressors
						forval r = 2(2)`optr' {
							local r2 = `r' - 2
							local regressors `regressors' l(0/`lag').`inst'_`r2'to`r'km
						}

						capture: reg pidx_w`weights'_`tp' `regressors' i.month i.market_id
						capture: estat ic
						if _rc != 321 {
							mata: bic_w`weights'_`cat'_`tp'_`inst' = bic_w`weights'_`cat'_`tp'_`inst',st_matrix("r(S)")[$ic]
						}
					}

				mata: optlag_pidx_w`weights'_`tp'_`inst' = optlag_pidx_w`weights'_`tp'_`inst',select((1::length(bic_w`weights'_`cat'_`tp'_`inst')-1)', (bic_w`weights'_`cat'_`tp'_`inst'[2..length(bic_w`weights'_`cat'_`tp'_`inst')] :== min(bic_w`weights'_`cat'_`tp'_`inst')))-1
			}
			mata: optlag_pidx_w`weights'_`tp' = optlag_pidx_w`weights'_`tp'\optlag_pidx_w`weights'_`tp'_`inst'
			}
		*mata: optlag_pidx_w`weights'_`tp' = optlag_pidx_w`weights'_`tp'[2::5,.]
		mata: optlag_pidx_w`weights'_`tp' = optlag_pidx_w`weights'_`tp'[2::2,.]
	}
}



****************************************************************************************************
** iii) For each specification, run the version with the optimal lag and spatial decay structures **
****************************************************************************************************
eststo clear
foreach weights in KLPS { // GE {

		foreach inst in pp_actamt {
			mata: p=1

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
			local countse = `count'+1
			local countspace = `count' + 2

			local varlabels ""
			local statnames ""
			local collabels ""

			mata: output_table = .,.,.,.,.
			scalar numoutcomes = 0

			use "$da/GE_MarketData_Panel_ECMA.dta", clear


			mata: j=0
			foreach price in med trade_med nontrade_med food_med nondur_med dur_med live_med tempt_med /* durall_med ndall_med */ {
				mata: j++
				di "Loop for `price'"

				scalar numoutcomes = numoutcomes + 1

				mata: output_row_b = .
				mata: output_row_se = .

				** adding variable label to the table **
				local add : var label pidx_w`weights'_`price'
				local collabels `"`collabels' "`add'""'

				** get optimal lags and optimal radii bands **
				mata: stata("local optr = " + strofreal(optr_pidx_w`weights'_med[p,1]*2))
				mata: stata("local optlag = " + strofreal(optlag_pidx_w`weights'_med[p,1]))


				** 1. First and second column: Main average effects **
				******************************************************

				** get list of regressors **
				local regressors
				forval r = 2(2)`optr' {
					local r2 = `r' - 2
					local regressors `regressors' l(0/`optlag').`inst'_`r2'to`r'km
				}

				ols_spatial_HAC pidx_w`weights'_`price' `regressors' m_* mkt_*, lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

				** Get mean and maxmean treatment **
				local ATEstring = "0"
				local maxstring = "0"


				** select month with the maximum transfers in the largest selected buffer **
				gsort market_id -cum_`inst'_`optr'km
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
				mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
				mata: output_row_se = output_row_se,st_numscalar("r(se)")

				** formatting for tex - column 1 **
				pstar, b(`r(estimate)') se(`r(se)') precision(4) //p(`r(p)')
				estadd local thisstat`count' = "`r(bstar)'": col1
				estadd local thisstat`countse' = "& `r(sestar)'": col1

				disp "`maxstring'"
				lincom "`maxstring'"
				mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
				mata: output_row_se = output_row_se,st_numscalar("r(se)")

				** formatting for tex - column 2 **
				pstar, b(`r(estimate)') se(`r(se)') precision(4) //p(`r(p)')
				estadd local thisstat`count' = "`r(bstar)'": col2
				estadd local thisstat`countse' = "`r(sestar)'": col2



				** 2. 3rd / 4th column: ATE above / below median of market access **
				*****************************************************************
				forval nq = 1(1)2 {
					local clmn = `nq' + 2

					** get list of regressors **
					local regressors
					forval r = 2(2)`optr' {
						local r2 = `r' - 2
						local regressors `regressors' l(0/`optlag').`inst'_`r2'to`r'km
					}

					ols_spatial_HAC pidx_w`weights'_`price' `regressors' m_* mkt_* if q2_distroad == `nq', lat(latitude) lon(longitude) timevar(month) panelvar(market_id) dist(10) lag(12) dropvar

					** Get mean treatment **
					local ATEstring = "0"

					foreach v of var `regressors' {
						sum `v' if inrange(month,tm(2014m09),tm(2017m03)) & q2_distroad == `nq' , d
						local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"
					}

					disp "`ATEstring'"
					lincom "`ATEstring'"
					mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
					mata: output_row_se = output_row_se,st_numscalar("r(se)")

					** formatting for tex - column 3/4 **
					pstar, b(`r(estimate)') se(`r(se)') precision (4) //p(`r(p)')
					estadd local thisstat`count' = "`r(bstar)'": col`clmn'
					estadd local thisstat`countse' = "`r(sestar)'": col`clmn'
				}

				** Add to output table **
				mata: output_table = output_table\output_row_b\output_row_se\(.,.,.,.,.)

				** looping variables for tex table **
				if "pidx_w`weights'_`price'" == "pidx_w`weights'_med" {
					local thisvarlabel = "\textit{All goods} &"
				}
				if "pidx_w`weights'_`price'" == "pidx_w`weights'_trade_med" {
					local thisvarlabel = "\textit{By tradability} & More tradable"
				}

				if "pidx_w`weights'_`price'" == "pidx_w`weights'_nontrade_med" {
					local thisvarlabel = "& Less tradable"
				}

				if "pidx_w`weights'_`price'" == "pidx_w`weights'_food_med" {
					local thisvarlabel = "\textit{By sector} & Food items"
				}

				if "pidx_w`weights'_`price'" == "pidx_w`weights'_nondur_med" {
					local thisvarlabel = "& Non-durables"
				}

				if "pidx_w`weights'_`price'" == "pidx_w`weights'_dur_med" {
					local thisvarlabel = "& Durables"
				}

				if "pidx_w`weights'_`price'" == "pidx_w`weights'_live_med" {
					local thisvarlabel = "& Livestock"
				}

				if "pidx_w`weights'_`price'" == "pidx_w`weights'_tempt_med" {
					local thisvarlabel = "& Temptation goods"
				}


				if numoutcomes == 1 {
					local varlabels `" " "`varlabels' "`thisvarlabel'" " " " " "'
					local statnames "thisstat`countspace' `statnames' thisstat`count' thisstat`countse' thisstat`countspace'"
				}
				else {
					local varlabels `"`varlabels' "`thisvarlabel'" " " " " "'
					local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countspace'"
				}

				local count = `count' + 3
				local countse = `count' + 1
				local countspace = `count' + 2

				local ++varcount
			}

			di "End outcome loop"

			** format output table **
			mata: st_matrix("output_table",output_table[2..rows(output_table),2..cols(output_table)])
			clear
			svmat output_table, names(col)

			forval i = 1/4 {
				gen col`i' = string(round(c`i',0.001))

				local numrows = (numoutcomes - 1)*3 + 1
				forval j = 1(3)`numrows' {
					replace col`i' = "(" + col`i' + ")" if _n == `j' + 1

					if abs(c`i'[`j'] / c`i'[`j'+1]) > invnormal(0.95) {
						replace col`i' = col`i' + "*" if _n == `j'
					}

					if abs(c`i'[`j'] / c`i'[`j'+1]) > invnormal(0.975) {
						replace col`i' = col`i' + "*" if _n == `j'
					}

					if abs(c`i'[`j'] / c`i'[`j'+1]) > invnormal(0.995) {
						replace col`i' = col`i' + "*" if _n == `j'
					}
				}
			}

			foreach v of var col* {
				replace `v' = "" if `v' == "."
			}

			** column names **
			keep col*
			label var col1 "Implied ATE"
			label var col2 "Implied Average Maximum Effect"
			label var col3 "Implied ATE: below median road access"
			label var col4 "Implied ATE: above median road access"

			gen col0 = ""
			label var col0 " "
			order col0

			*** exporting tex table ***
			** dropping column 2 **
			loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{ll*{5}{S}}\toprule &"
			loc postfoot "\bottomrule\end{tabular}}"

			di "Exporting tex file"
			local name = "$dtab/TableH2_OutputPrices_byDistRoad.tex"
			esttab col1 col2 col3 col4 using "`name'", cells(none) booktabs extracols(3) nonotes compress replace ///
			mlabels("& \multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Overall Effects}}} & & \multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{ATE by road access}}} \\   \cline{3-4}\cline{6-7}\\ \vspace{.2cm} & & \multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ ATE }}"  "\multicolumn{1}{c}{\shortstack{Average maximum \\ effect (AME)}}" "\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ below median}}" "\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ above median}}" ) stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')
			project, creates("`name'") preserve
	}
}
