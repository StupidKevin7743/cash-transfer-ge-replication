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
project, original("$dir/do/global_runGPS.do")
include "$dir/do/GE_global_setup.do"
include "$do/global_runGPS.do"


set varabbrev off

** Information criterion choice **
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

project, original("$da/Ent_ML_SpatialData_long_FINAL.dta")
use "$da/Ent_ML_SpatialData_long_FINAL.dta", clear

** Set fixed effect level **
sort village_code
bys village_code: gen vill_id = 1 if _n == 1
replace vill_id = sum(vill_id)
local FE "vill_id"

*********************************************************************
** i) Determine optimal spatial decay structure using Schwartz BIC **
*********************************************************************

** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
** spatial-autocorrelation consistent method to determine the optimal decay structure **

mata: optr = .,.
foreach inst in pp_actamt {
	foreach p in tailor grind1kg {
    mata: optr_`inst' = .
		mata: bic_`p'_`inst' = .,.,.,.,.,.,.,.,.,.

    local radii_list ""

		forval r = 2(2)20 {
			local r2 = `r' - 2
			local radii_list "`radii_list' tcum_l2_`inst'_`r2'to`r'km"
			reg ln_p_`p' `radii_list' i.month i.`FE' [aweight=entweight_ML]
			estat ic
			mata: bic_`p'_`inst'[`r'/2] = st_matrix("r(S)")[$ic]
		}
	mata: optr_`inst' = optr_`inst',select((1::10)', (bic_`p'_`inst' :== min(bic_`p'_`inst')))
    mata: optr = optr\optr_`inst'
  }
}
mata: optr = optr[2::3,2::2]'
mata: optr

**************************************************************************************************
** ii) For the optimal spatial specification, determine optimal lag structure using Schwartz BIC **
**************************************************************************************************



** Calculate Optimal number of lags **
**************************************

** Note, the BIC does not depend on the variance/covariance matrix used. Hence, we do not need to use the
** spatial-autocorrelation consistent method to determine the optimal decay structure **
tsset call_rank_ML month
sort call_rank_ML month
mata: optlag = .,.,.
mata: j = 0

foreach inst in pp_actamt {
	mata: j++
	mata: optlag_`inst' = .
	mata: k = 0

	foreach p in tailor grind1kg  {
		mata: bic_`p'_`inst' = .

		** get the maximum amount of lags **
		sum month if `inst'_0to2km != .
		local maxlag = 18

		** get the optimal number of radii bands **
		mata: k++
		mata: stata("local optr = " + strofreal(optr[j,k]*2))

		forval lag = 0(1)`maxlag' {

		** get list of regressors **
		di "Optimal radii: `optr'"
		local regressors ""
		forval r = 2(2)`optr' {
			local r2 = `r' - 2
			local regressors `regressors' l(0/`lag').`inst'_`r2'to`r'km
		}
		reg ln_p_`p' `regressors' i.month i.`FE' [aweight=entweight_ML]
		estat ic
		disp _rc
		if _rc != 321 {
			mata: bic_`p'_`inst' = bic_`p'_`inst',st_matrix("r(S)")[$ic]
		}
		}

		mata: optlag_`inst' = (optlag_`inst', select((1::length(bic_`p'_`inst')-1)', (bic_`p'_`inst'[2..length(bic_`p'_`inst')] :== min(bic_`p'_`inst')))-1)
	}
	mata: optlag = optlag\optlag_`inst'
}
mata: optlag
mata: optlag = optlag[2::2,2::3]


****************************************************************************************************
** iii) For each specification, run the version with the optimal lag and spatial decay structures **
****************************************************************************************************
label var ln_p_tailor "Tailor, patch small hole"
label var ln_p_grind1kg "Posho mill: grind 1kg maize"

eststo clear
foreach inst in pp_actamt {
	mata: p=1 // this corresponds to pp_actamt

	* setting up blank table *
	drop _all
	local ncols = 4
	local nrows = 4

	*** CREATE EMPTY TABLE ***
	eststo clear
  quietly {
	est drop _all
	set obs `nrows'
	gen x = 1
	gen y = 1

	forvalues x = 1/`ncols' {
		eststo col`x': reg x y
	}
  }

	local varcount = 1
	local count = 1
	local countse = `count'+1
	local countspace = `count' + 2

	local varlabels ""
	local statnames ""
	local collabels ""

	scalar numoutcomes = 0

	use "$da/Ent_ML_SpatialData_long_FINAL.dta", clear

  ** bring in GPS if using **
  if $runGPS == 1 {
    project, original("$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta") preserve
    merge n:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keepusing(latitude longitude) nogen keep(1 3) // drop non-ML obs
  }

	foreach price in tailor grind1kg {
		di "Loop for `price'"

		** adding variable label to the table **
		local add : var label ln_p_`price'
		local collabels `"`collabels' "`add'""'

		** get optimal lags and optimal radii bands **
		mata: stata("local optr = " + strofreal(optr[p,j]*2))
		mata: stata("local optlag = " + strofreal(optlag[p,j]))

    di "Optimal radii: `optr'"
    di "Optimal lag: `optlag'"

		** 1. First and second column: Main average effects **
		******************************************************
    sort call_rank_ML month

		** get list of regressors **
		local regressors
		forval r = 2(2)`optr' {
			local r2 = `r' - 2
			local regressors `regressors' l(0/`optlag').`inst'_`r2'to`r'km
		}

    if $runGPS == 1 {
      ols_spatial_HAC ln_p_`price' `regressors' m_* v_* [aweight=entweight_ML], lat(latitude) lon(longitude) timevar(month) panelvar(call_rank_ML) dist(10) lag(3) dropvar
    }
		if $runGPS == 0 {
      reg ln_p_`price' `regressors' m_* v_* [aweight=entweight_ML], cluster(sublocation_code)
    }

		** Get mean and maxmean treatment **
		local ATEstring = "0"
		local maxstring = "0"

		** select month with the maximum transfers in the largest selected buffer **
		gsort call_rank_ML -cum_`inst'_`optr'km
		bys call_rank_ML: gen maxmonth = (_n == 1)
    tab maxmonth
		sort call_rank_ML month

		foreach v of var `regressors' {
			sum `v' [aweight=entweight_ML] if inrange(month,tm(2014m09),tm(2017m03)), d
			local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"

			** get mean of the maximum predicted effect **
			sum `v' [aweight=entweight_ML] if maxmonth == 1
			local maxstring = "`maxstring'"	+ "+" + "`r(mean)'" + "*" + "`v'"
		}
		drop maxmonth

		disp "`ATEstring'"
		lincom "`ATEstring'"
		if r(se) == . {
			stop
		}

		** formatting for tex - column 1 **
		pstar, b(`r(estimate)') se(`r(se)') precision(4) //p(`r(p)')
		estadd local thisstat`count' = "`r(bstar)'": col1
		estadd local thisstat`countse' = "`r(sestar)'": col1

		disp "`maxstring'"
		lincom "`maxstring'"
		if r(se) == . {
			stop
		}

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

    if $runGPS == 1 {
      ols_spatial_HAC ln_p_`price' `regressors' m_* v_* [aweight=entweight_ML] if q2_market_access == `nq', lat(latitude) lon(longitude) timevar(month) panelvar(call_rank_ML) dist(10) lag(3) dropvar
    }
    if $runGPS == 0 {
      reg ln_p_`price' `regressors' m_* v_* [aweight=entweight_ML] if q2_market_access == `nq', cluster(sublocation_code)
    }


		** Get mean treatment **
		local ATEstring = "0"

		foreach v of var `regressors' {
			sum `v' [aweight=entweight_ML] if inrange(month,tm(2014m09),tm(2017m03)) & q2_market_access == `nq' , d
			local ATEstring = "`ATEstring'" + "+" + "`r(mean)'" + "*" + "`v'"
		}

		disp "`ATEstring'"
		lincom "`ATEstring'"
		if r(se) == . {
			stop
		}

		** formatting for tex - column 3/4 **
		pstar, b(`r(estimate)') se(`r(se)') precision(4) //p(`r(p)')
		estadd local thisstat`count' = "`r(bstar)'": col`clmn'
		estadd local thisstat`countse' = "`r(sestar)'": col`clmn'
		}

		** looping variables for tex table **
		if "`price'" == "tailor" {
			local thisvarlabel = "Tailor, patch small hole"
		}
		if "`price'" == "grind1kg" {
			local thisvarlabel = "Posho mill, grind 1kg of maize"
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


	*** exporting tex table ***

	loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{9}{S}}\toprule"
	loc postfoot "\bottomrule\end{tabular}}"

	di "Exporting tex file"
	local name = "$dtab/TableH5_EntPrices.tex"
	esttab col1 col2 col3 col4 using "`name'", cells(none) booktabs extracols(3) nonotes compress replace ///
	mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Overall Effects}}} & & \multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{ATE by market access}}} \\   \cline{2-3}\cline{5-6}\\ \vspace{.2cm} & \multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ ATE }}"  "\multicolumn{1}{c}{\shortstack{Average maximum \\ effect (AME)}}" "\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ below median}}" "\multicolumn{1}{c}{\shortstack{ \vspace{0.2cm} \\ above median}}") stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')
	project, creates("`name'") preserve

}
