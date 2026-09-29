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

* dataset dependencies
project, original("$da/GE_VillageLevel_ECMA.dta")
project, original("$da/GE_Enterprise_ECMA.dta")

* Enterprise village-level numbers
project, original("$do/analysis/prep/prep_VillageLevel.do")
include "$do/analysis/prep/prep_VillageLevel.do"

/*** Create endline enterprise results table by eligibility status ***/
/* This uses matched enterprise data, and thus differs from the main table in the paper */

local panvar "run_id"
local timvar "date"

local outcomes ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP //  n_allents

local using `"using "$dtab/TableB3_EntOutcomes_Main_ByElig.tex""'

di `"Using: `using'"'
cap mkdir "${dtab}/coeftables"
local coeftable = subinstr(`"`using'"', `"${dtab}"', `"${dtab}/coeftables"', 1)
local coeftable = subinstr(`"`coeftable'"', ".tex", "_RawCoefs.xls", 1)

local outregopt "replace"
local outregset "excel label(proper)"


* setting up blank table *
drop _all
local ncols = 4
local nrows = wordcount("`outcomes'")

*** CREATE EMPTY TABLE ***
eststo clear
est drop _all
quietly {
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
foreach v in `outcomes' {
	scalar numoutcomes = numoutcomes + 1

	di "Outcome, by eligibility: `v'"

	if inlist("`v'", "n_ent_byelig", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {
	use "$da/GE_VillageLevel_ECMA.dta", clear
	gen run_id = _n
	gen date = run_id // pseudo-panel of depth one.

	if $runGPS == 1 {
		merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", nogen
	}

	cap la var n_allents "\emph{Panel C: Village-level} & & & & \\ Number of enterprises"
	cap la var n_operates_from_hh "Number of enterprises, operated from hh"
	cap la var n_operates_outside_hh "Number of enterprises, operated outside hh"
	cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
	cap la var n_ent_eligibletreat "Number of enterprises, owned by treated households"
	cap la var n_ent_ineligible "Number of enterprises, owned by untreated households"

	merge 1:1 village_code using `temphh'
	if "`v'" == "n_allents" {
		gen phh_`v' = n_ent_elig / n_elig
	}

	else {
		gen phh_`v' = `v' / n_hh
	}


    ** adding variable label to the table **
    local add : var label `v'
    local collabels `"`collabels' "`add'""'

* adding village-level baseline variables - if they are in the dataset **
    cap desc `v'_BL
    if _rc == 0 {
		gen phh_`v'_BL = `v'_BL / n_hh
		local blvars "phh_`v'_BL"
    }
    else {
        local blvars ""
    }


	** A. Dummy regressions **
	**************************
	reg phh_`v' treat hi_sat `blvars' [aweight=n_hh], cluster(village_code)
	outreg2 `coeftable', `outregopt' `outregset'
	local outregopt "append"

	** formatting for tex - column 1, indicator for treatment status **
	pstar treat
	estadd local thisstat`count' = "`r(bstar)'": col1
	estadd local thisstat`countse' = "`r(sestar)'": col1


	** B. Spatial regressions **
	****************************

	** Get mean total effect on number of enterprises owned by treated households **
	mata: optr = .,.,.,.,.,.,.,.,.,.
	forval r = 2(2)20 {
		local r2 = `r' - 2
		ivreg2 phh_`v' `blvars' [aweight=n_hh_treat] (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km)
		estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[6]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
	local r = optr
	local r2 = `r' - 2

	cap gen cons = 1
	if $runGPS == 1 {
		iv_spatial_HAC phh_`v' cons `blvars' [aweight=n_hh_treat], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
	}
	if $runGPS == 0 {
		ivreg2 phh_`v' `blvars' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) [aweight=n_hh_treat], cluster(sublocation_code)
	}
	outreg2 `coeftable', `outregopt' `outregset'

	sum pp_actamt_ownvill [weight=n_hh_treat] if treat == 1
	local ATEstring_tot = "`r(mean)'" + "*pp_actamt_ownvill"

	foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km {
		sum `vrb' [aweight=n_hh_treat] if treat == 1
		local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
	}

	disp "`ATEstring_tot'"
	lincom "`ATEstring_tot'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col2
	estadd local thisstat`countse' = "`r(sestar)'": col2


	** Get mean total effect on number of enterprises owned by untreated households **
	if "`v'" == "n_allents" {
		expand 2, gen(elig)
		cap: drop phh_`v'
		gen phh_`v' = n_ent_elig / n_elig if elig == 1 & treat == 0
		replace phh_`v' = n_ent_inelig / n_inelig if elig == 0

		gen weight = n_elig if elig == 1
		replace weight = n_inelig if elig == 0
	}

	local endregs = ""
	local exregs = ""
	forval r = 2(2)20 {
		local r2 = `r' - 2
		local endregs = "`endregs'" + " c.pp_actamt_`r2'to`r'km#i.elig"
		local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#i.elig"
		ivreg2 phh_`v' (`endregs' = `exregs') i.elig `blvars'
		estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[6]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
	local rad = optr
	local rad2 = optr - 2

	local endregs = ""
	local exregs = ""
	forval r = 2(2)`rad' {
		local r2 = `r' - 2
		local endregs = "`endregs'" + " c.pp_actamt_`r2'to`r'km#i.elig"
		local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#i.elig"
	}

	cap gen cons = 1

	if $runGPS == 1 {
		iv_spatial_HAC phh_`v' cons i.elig `blvars', en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
	}
	if $runGPS == 0 {
		ivreg2 phh_`v' cons i.elig `blvars' (`endregs' = `exregs'), cluster(sublocation_code)
	}
	outreg2 `coeftable', `outregopt' `outregset'

	** get weights **
	sum n_elig if treat == 0 & elig == 1
	local eligcontrolweight = `r(sum)'
	sum n_inelig if elig == 0
	local ineligweight = `r(sum)'

	local untreatweight = `eligcontrolweight' + `ineligweight'

	local ATEstring_tot = 0
	foreach vrb of var pp_actamt_0to2km-pp_actamt_`r2'to`rad'km {
		sum `vrb' [aweight=n_elig] if treat == 0
		local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)' * `eligcontrolweight'/`untreatweight'" + "*" + "`vrb'#1.elig"

		sum `vrb' [aweight=n_inelig]
		local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)' * `ineligweight'/`untreatweight'" + "*" + "`vrb'#0.elig"
	}

	disp "`ATEstring_tot'"
	lincom "`ATEstring_tot'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col3
	estadd local thisstat`countse' = "`r(sestar)'": col3

	** 4. Add mean of dependent variable **
	****************************************
	if "`v'" == "n_allents" {
		replace phh_`v' = n_allents / n_hh
	}

	sum phh_`v' [weight=n_hh] if treat == 0 & hi_sat == 0

	estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col4
	estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col4

	** looping variables for tex table **
	local thisvarlabel: variable label `v'

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

	else {
		use "$da/GE_Enterprise_ECMA.dta", clear
		
		if $runGPS == 1 {
			merge 1:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
		}

		gen run_id = _n

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
		cap la var ent_cust_perhour "Customers per hour business is open"
		cap la var ent_rev_perhour "Revenue per hour business is open"

		merge m:1 village_code using `temphh'
		drop _merge
		merge m:1 village_code using `tempent_el'
		drop _merge

		** adding variable label to the table **
		local add : var label `v'
		local collabels `"`collabels' "`add'""'

		** Get number of enterprises of each group by treatment **
		sum entweight_EL if ent_type == 2 & treat == 1
		local n_ent_from_hh_treatall = r(sum)
		sum entweight_EL if ent_type == 2 & treat == 0
		local n_ent_from_hh_control = r(sum)
		sum entweight_EL if ent_type == 2 & hi_sat == 0 & treat == 0
		local n_ent_from_hh_lowsatcontrol = r(sum)
		sum entweight_EL if ent_type == 2
		local n_ent_from_hh_tot = r(sum)

		sum entweight_EL if ent_type == 1 & treat == 1
		local n_ent_outside_hh_treatall = r(sum)
		sum entweight_EL if ent_type == 1 & treat == 0
		local n_ent_outside_hh_control = r(sum)
		sum entweight_EL if ent_type == 1 & hi_sat == 0 & treat == 0
		local n_ent_outside_hh_lowsatcontrol = r(sum)
		sum entweight_EL if ent_type == 1
		local n_ent_outside_hh_tot = r(sum)

		sum entweight_EL if ent_type == 3 & treat == 1
		local n_ent_ownfarm_treatall = r(sum)
		sum entweight_EL if ent_type == 3 & treat == 0
		local n_ent_ownfarm_control = r(sum)
		sum entweight_EL if ent_type == 3 & hi_sat == 0 & treat == 0
		local n_ent_ownfarm_lowsatcontrol = r(sum)
		sum entweight_EL if ent_type == 3
		local n_ent_ownfarm_tot = r(sum)

		** Get number of enterprises of each group by eligibility **
		sum entweight_EL if ent_type == 2 & ownerm_treat == 1 & ownerm_elig == 1
		local n_ent_from_hh_treat = r(sum)
		sum entweight_EL if ent_type == 2 & (ownerm_treat == 0 | ownerm_elig == 0)
		local n_ent_from_hh_untreat = r(sum)

		sum entweight_EL if ent_type == 1 & ownerm_treat == 1 & ownerm_elig == 1
		local n_ent_outside_hh_treat = r(sum)
		sum entweight_EL if ent_type == 1 & (ownerm_treat == 0 | ownerm_elig == 0)
		local n_ent_outside_hh_untreat = r(sum)

		sum entweight_EL if ent_type == 3 & ownerm_treat == 1 & ownerm_elig == 1
		local n_ent_ownfarm_treat = r(sum)
		sum entweight_EL if ent_type == 3 & (ownerm_treat == 0 | ownerm_elig == 0)
		local n_ent_ownfarm_untreat = r(sum)

		** adding village-level baseline variables - if they are in the dataset **
		cap desc `v'_vBL M`v'_vBL
		if _rc == 0 {
			local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
		}
		else {
			local vblvars ""
		}

		** A. Dummy regressions **
		**************************

		if "`v'" == "ent_profitmargin2_wins" {
			** Here, we want to get the effect on the profit margin for the average enterprise (weighted by revenue) **
			** Get revenue weights for each group **
			gen entweight_rev_EL = entweight_EL * ent_revenue2_wins_PPP

			sum entweight_rev_EL if (ent_type == 2 & ownerm_elig == 1)
			local mean1 = r(sum)
			sum entweight_rev_EL if (ent_type == 1 & ownerm_elig == 1)
			local mean2 = r(sum)
			sum entweight_rev_EL if (ent_type == 3 & ownerm_elig == 1)
			local mean3 = r(sum)

			local withinhhweight = `mean1' / (`mean1' + `mean2' + `mean3')
			local outsidehhweight = `mean2' / (`mean1' + `mean2' + `mean3')
			local ownfarmweight = `mean3' / (`mean1' + `mean2' + `mean3')

			disp "`withinhhweight'"
			disp "`outsidehhweight'"
			disp "`ownfarmweight'"

			reg `v' c.treat#ent_type c.hi_sat#ent_type i.ent_type `vblvars' [aweight=entweight_rev_EL] if ownerm_elig == 1, cluster(village_code)
			outreg2 `coeftable', `outregopt' `outregset'
			local outregopt "append"

			local ATE_treat = "`withinhhweight' * 2.ent_type#c.treat + `outsidehhweight' * 1.ent_type#c.treat + `ownfarmweight' * 3.ent_type#c.treat"
		}

		else {
			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **

			reg `v' c.treat#ent_type c.hi_sat#ent_type i.ent_type `vblvars' [aweight=entweight_EL] if ownerm_elig == 1, cluster(village_code)
			outreg2 `coeftable', `outregopt' `outregset'
			local outregopt "append"

			if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP", "ent_cust_perhour", "ent_rev_perhour", "op_monperyear") {
				// we don't have this information for agricultural businesses
				local ATE_treat = "(2.ent_type#c.treat * `n_ent_from_hh_treat' / `n_hh_treat') + (1.ent_type#c.treat * `n_ent_outside_hh_treat' / `n_hh_treat') + (3.ent_type#c.treat * `n_ent_ownfarm_treat' / `n_hh_treat')"
			}

			if inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP", "ent_cust_perhour", "ent_rev_perhour", "op_monperyear") {
				// we don't have this information for agricultural businesses
				local ATE_treat = "(2.ent_type#c.treat * `n_ent_from_hh_treat' / `n_hh_treat') + (1.ent_type#c.treat * `n_ent_outside_hh_treat' / `n_hh_treat')"
			}
		}

		lincom "`ATE_treat'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col1
		estadd local thisstat`countse' = "`r(sestar)'": col1


		** B. Column 2 - Total effect for treated owners **
		***************************************************
		if "`v'" == "ent_profitmargin2_wins" {
			mata: optr = .,.,.,.,.,.,.,.,.,.

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			forval r = 2(2)20 {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL] if ownerm_elig == 1
				estat ic
				mata: optr[`r'/2] = st_matrix("r(S)")[6]
			}

			mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
			local rad = optr
			local rad2 = optr - 2

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
			}

			cap gen cons = 1
			** Get mean total effect on enterprises in treatment villages **
			if $runGPS == 1 {
				iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_rev_EL] if ownerm_elig == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
			}
			if $runGPS == 0 {
				ivreg2 `v' (`endregs'=`exregs') cons i.ent_type `vblvars' [aweight=entweight_rev_EL] if ownerm_elig == 1, cluster(sublocation_code)
			}			
			
			outreg2 `coeftable', `outregopt' `outregset'

			** Here, we want to get the effect on the profit margin for the average enterprise **
			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (ownerm_treat == 1 & ent_type == 2)
			local ATEstring_total = "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill"

			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (ownerm_treat == 1 & ent_type == 1)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + "*`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill"

			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (ownerm_treat == 1 & ent_type == 3)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + "*`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill"

			foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`rad2'to`rad'km {
				sum `vrb' [aweight=entweight_rev_EL] if (ownerm_treat == 1 & ent_type == 2)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (ownerm_treat == 1 & ent_type == 1)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (ownerm_treat == 1 & ent_type == 3)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"
			}
		}

		else {
			mata: optr = .,.,.,.,.,.,.,.,.,.

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			forval r = 2(2)20 {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL] if ownerm_elig == 1
				estat ic
				mata: optr[`r'/2] = st_matrix("r(S)")[6]
			}

			mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
			local rad = optr
			local rad2 = optr - 2

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
			}

			cap gen cons = 1
			if $runGPS == 1 {
				iv_spatial_HAC `v' cons i.ent_type `vblvars'  [aweight=entweight_EL] if ownerm_elig == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
			}
			if $runGPS == 0 {
				ivreg2 `v' (`endregs'=`exregs')  cons i.ent_type `vblvars' [aweight=entweight_EL] if ownerm_elig == 1, cluster(sublocation_code)
			}			
			
			outreg2 `coeftable', `outregopt' `outregset'
			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **

			sum pp_actamt_ownvill [aweight=entweight_EL] if (ownerm_treat == 1 & ent_type == 2)
			local ATEstring_total = "`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill * `n_ent_from_hh_treat' / `n_hh_treat'"

			sum pp_actamt_ownvill [aweight=entweight_EL] if (ownerm_treat == 1 & ent_type == 1)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill * `n_ent_outside_hh_treat' / `n_hh_treat'"

			if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP", "ent_cust_perhour", "ent_rev_perhour", "op_monperyear") {  // we don't have this information for agricultural businesses
				sum pp_actamt_ownvill [aweight=entweight_EL] if (ownerm_treat == 1 & ent_type == 3)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill * `n_ent_ownfarm_treat' / `n_hh_treat'"
			}

			foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`rad2'to`rad'km {
				sum `vrb' [aweight=entweight_EL] if (ownerm_treat == 1 & ent_type == 2)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_treat' / `n_hh_treat'"

				sum `vrb' [aweight=entweight_EL] if (ownerm_treat == 1 & ent_type == 1)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_treat' / `n_hh_treat'"

				if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP", "ent_cust_perhour", "ent_rev_perhour", "op_monperyear") {  // we don't have this information for agricultural businesses
					sum `vrb' [aweight=entweight_EL] if (ownerm_treat == 1 & ent_type == 3)
					local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_treat' / `n_hh_treat'"
				}
			}
		}

		disp "`ATEstring_total'"
		lincom "`ATEstring_total'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col2
		estadd local thisstat`countse' = "`r(sestar)'": col2


		** C. Column 3 - Total effect for untreated owners **
		*****************************************************
		if "`v'" == "ent_profitmargin2_wins" {

			** generate revenue weights for untreated households **
			sum entweight_rev_EL if ent_type == 2 & (ownerm_elig == 0 | ownerm_treat == 0)
			local mean1 = r(sum)
			sum entweight_rev_EL if ent_type == 1 & (ownerm_elig == 0 | ownerm_treat == 0)
			local mean2 = r(sum)
			sum entweight_rev_EL if ent_type == 3 & (ownerm_elig == 0 | ownerm_treat == 0)
			local mean3 = r(sum)

			local withinhhweight = `mean1' / (`mean1' + `mean2' + `mean3')
			local outsidehhweight = `mean2' / (`mean1' + `mean2' + `mean3')
			local ownfarmweight = `mean3' / (`mean1' + `mean2' + `mean3')

			disp "`withinhhweight'"
			disp "`outsidehhweight'"
			disp "`ownfarmweight'"

			mata: optr = .,.,.,.,.,.,.,.,.,.

			local endregs = ""
			local exregs = ""
			forval r = 2(2)20 {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#ent_type"
				ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL] if (ownerm_elig == 0 | ownerm_treat == 0)
				estat ic
				mata: optr[`r'/2] = st_matrix("r(S)")[6]
			}

			mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
			local rad = optr
			local rad2 = optr - 2

			local endregs = ""
			local exregs = ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#ent_type"
			}


			cap gen cons = 1
			** Get mean total effect on enterprises in treatment villages **
			if $runGPS == 1 {
				iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_rev_EL] if (ownerm_elig == 0 | ownerm_treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
			}
			if $runGPS == 0 {
				ivreg2 `v' (`endregs'=`exregs') cons i.ent_type `vblvars' [aweight=entweight_rev_EL] if (ownerm_elig == 0 | ownerm_treat == 0), cluster(sublocation_code)
			}			
			
			outreg2 `coeftable', `outregopt' `outregset'

			** Here, we want to get the effect on the profit margin for the average enterprise **
			local ATEstring_total = "0"
			foreach vrb of var pp_actamt_0to2km-pp_actamt_`rad2'to`rad'km {
				sum `vrb' [aweight=entweight_rev_EL] if (ownerm_elig == 0 | ownerm_treat == 0) & ent_type == 2
				local ATEstring_total = "`ATEstring_total'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (ownerm_elig == 0 | ownerm_treat == 0) & ent_type == 1
				local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (ownerm_elig == 0 | ownerm_treat == 0) & ent_type == 3
				local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"
			}
		}

		else {
			mata: optr = .,.,.,.,.,.,.,.,.,.

			local endregs = ""
			local exregs = ""
			forval r = 2(2)20 {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#ent_type"
				ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL] if (ownerm_elig == 0 | ownerm_treat == 0)
				estat ic
				mata: optr[`r'/2] = st_matrix("r(S)")[6]
			}

			mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
			local rad = optr
			local rad2 = optr - 2

			local endregs = ""
			local exregs = ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#ent_type"
			}
			cap gen cons = 1
			if $runGPS == 1 {
				iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_EL] if (ownerm_elig == 0 | ownerm_treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
			}
			if $runGPS == 0 {
				ivreg2 `v' (`endregs'=`exregs')  cons i.ent_type `vblvars' [aweight=entweight_EL] if (ownerm_elig == 0 | ownerm_treat == 0), cluster(sublocation_code)
			}
			outreg2 `coeftable', `outregopt' `outregset'

			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			local ATEstring_total = "0"
			foreach vrb of var pp_actamt_0to2km-pp_actamt_`rad2'to`rad'km {
				sum `vrb' [aweight=entweight_EL] if (ownerm_elig == 0 | ownerm_treat == 0) & ent_type == 2
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_untreat' / `n_hh_untreat'"

				sum `vrb' [aweight=entweight_EL] if (ownerm_elig == 0 | ownerm_treat == 0) & ent_type == 1
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_untreat' / `n_hh_untreat'"

				if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP", "ent_cust_perhour", "ent_rev_perhour", "op_monperyear") {  // we don't have this information for agricultural businesses
					sum `vrb' [aweight=entweight_EL] if (ownerm_elig == 0 | ownerm_treat == 0) & ent_type == 3
					local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_untreat' / `n_hh_untreat'"
				}
			}
		}

		disp "`ATEstring_total'"
		lincom "`ATEstring_total'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col3
		estadd local thisstat`countse' = "`r(sestar)'": col3


		** 4. Add mean of dependent variable **
		****************************************
		if "`v'" == "ent_profitmargin2_wins" {

			sum `v' [aweight=entweight_rev_EL] if treat == 0 & hi_sat == 0 // gives a weighted average of `v' per enterprise across all types

			** here, we want the average profit margin for the average enterprise **
			estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col4
			estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col4
		}

		else {
			sum `v' [aweight=entweight_EL] if treat == 0 & hi_sat == 0 // gives a weighted average of `v' per enterprise across all types

			** here, we want the sum of average per person profit for all enterprise types **
			local totent = `n_ent_from_hh_lowsatcontrol' + `n_ent_outside_hh_lowsatcontrol' + `n_ent_ownfarm_lowsatcontrol'
			estadd local thisstat`count' = string(`r(mean)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") : col4
			estadd local thisstat`countse' = "(" + string(`r(sd)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") + ")": col4
		}

		** looping variables for tex table **
		local thisvarlabel: variable label `v'

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
}

** end loop through outcomes
di "End outcome loop"

** exporting tex table ***
loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{5}{S}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

di "Exporting tex file"
esttab col1 col2 col3 col4 using "$dtab/TableB3_EntOutcomes_ByElig", cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Recipient Owners}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Non-Recipient Owners}}} & \\   \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ weighted mean (SD)}}") ///
stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')

project, creates("$dtab/TableB3_EntOutcomes_ByElig.tex")
