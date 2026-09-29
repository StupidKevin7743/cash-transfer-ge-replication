***************************************************
* Defining program for endline enterprise tables  *
***************************************************
project, original("$do/analysis/prep/prep_VillageLevel.do") preserve

cap program drop ge_table_ent
program define ge_table_ent
  syntax using [if], outcomes(string) coeftable(string) [NOBL]

  di "No BL: `nobl'"

** Running Preliminaries **
include "$do/analysis/prep/prep_VillageLevel.do"

*****************************
**** 2. RUN ENDLINE TABLE ***
*****************************
local panvar "run_id"
local timvar "date"


		* for raw coefficient tables
      local outregopt "replace"
      local outregset "excel label(proper)"


* setting up blank table *
drop _all
local ncols = 4
local nrows = max(wordcount("`outcomes'"), 2)

*** CREATE EMPTY TABLE ***
quietly {
eststo clear
est drop _all
set obs `nrows'
gen x = 1
gen y = 1

forvalues x = 1/`ncols' {
	eststo col`x': reg x y
}
}

loc omitstring = "\text{---}"

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

	di "Outcome: `v'"

	if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {
	use "$da/GE_VillageLevel_ECMA.dta", clear
	gen run_id = _n
	gen date = run_id // pseudo-panel of depth one.

  if $runGPS == 1 {
    merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
  }

	cap la var n_allents "\emph{Panel C: Village-level} & & & & \\ Number of enterprises"
	cap la var n_operates_from_hh "Number of enterprises, operated from hh"
	cap la var n_operates_outside_hh "Number of enterprises, operated outside hh"
	cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
	cap la var n_ent_eligibletreat "Number of enterprises, owned by treated households"
	cap la var n_ent_ineligible "Number of enterprises, owned by untreated households"

	merge 1:1 village_code using `temphh'
	gen phh_`v' = `v' / n_hh

	di "checkpoint 1"

    ** adding variable label to the table **
    local add : var label `v'
    local collabels `"`collabels' "`add'""'

	* adding village-level baseline variables - if they are in the dataset **
  di "NoBL: `nobl'"

  if "`nobl'" == "" {
    cap desc `v'_BL
    if _rc == 0 {
				gen phh_`v'_BL = `v'_BL / n_hh
       local blvars "phh_`v'_BL"
    }
    else {
        local blvars ""
    }
    loc omit = 0
  }
  // if No BL is selected:
  else {
    local blvars "" // don't want to include baseline variables
    cap desc `v'_BL // no BL value, display dash instead of estimate
    if _rc == 0 {
      local omit = 0
    }
    else {
      loc omit = 1
    }
  }
  // end No BL condition

		di "Check: baseline vars: `blvars'"
    di "Check: omit: `omit'; omit string `omitstring'"

    ** for those that we do not want to omit -- run estimation **
    if `omit' == 0 {

	** A. Dummy regressions **
	**************************
    reg phh_`v' treat hi_sat `blvars' [aweight=n_hh], cluster(village_code)
	outreg2 using "`coeftable'", `outregopt' `outregset'


	** formatting for tex - column 1, indicator for treatment status **
	pstar treat
	estadd local thisstat`count' = "`r(bstar)'": col1
	estadd local thisstat`countse' = "`r(sestar)'": col1


	** B. Spatial regressions **
	****************************
	** calculate optimal radii
	calculate_optimal_radii phh_`v' [aweight=n_hh], vill blvars("`blvars'")

	local r = r(r_max)
	local r2 = `r' - 2

	cap gen cons = 1

	local endregs = "pp_actamt_ownvill"
	local exregs = "treat"
	local amount_list = ""

	forval rad = 2(2)`r' {
		local r2 = `r' - 2
		local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
		local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
		local amount_list "`amount_list' pp_actamt_ov_`r2'to`rad'km"
	}

  if $runGPS == 1 {
    iv_spatial_HAC phh_`v' cons `blvars' [aweight=n_hh], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  }
  if $runGPS == 0 {
    ivreg2 phh_`v' `blvars' (`endregs' = `exregs') [aweight=n_hh], cluster(sublocation_code)
  }

	outreg2 using "`coeftable'", `outregopt' `outregset'

	** Get mean total effect in treatment villages **
	sum pp_actamt_ownvill [aweight=n_hh] if treat == 1
	local ATEstring_tot = "`r(mean)'" + "*pp_actamt_ownvill"
	local ATEstring_spillover = "0"

	foreach vrb of local amount_list {
		sum `vrb' [aweight=n_hh] if treat == 1
		local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"

		sum `vrb' [aweight=n_hh] if treat == 0
		local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*" + "`vrb'"
	}

	disp "`ATEstring_tot'"
	lincom "`ATEstring_tot'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col2
	estadd local thisstat`countse' = "`r(sestar)'": col2

	disp "`ATEstring_spillover'"
	lincom "`ATEstring_spillover'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col3
	estadd local thisstat`countse' = "`r(sestar)'": col3

	** 4. Add mean of dependent variable **
	****************************************
	sum phh_`v' [weight=n_hh] if treat == 0 & hi_sat == 0

	estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col4
	estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col4
  }
  ** add dashes for those that we are omitting
  else if `omit' == 1 {
      estadd local thisstat`count' = "`omitstring'": col1
      estadd local thisstat`count' = "`omitstring'": col2
      estadd local thisstat`count' = "`omitstring'": col3
      estadd local thisstat`count' = "`omitstring'": col4
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
	else {
		project, original("$da/GE_Enterprise_ECMA.dta") preserve
		use "$da/GE_Enterprise_ECMA.dta", clear
		gen run_id = _n

    if $runGPS == 1 {
      merge 1:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
    }

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

		** adding village-level baseline variables - if they are in the dataset **
    di "NoBL: `nobl'"
    if "`nobl'" == "" { // if nobl specified, set to blank
		cap desc `v'_vBL M`v'_vBL
		if _rc == 0 {
			local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
		}
		else {
			local vblvars ""
		}
    loc omit = 0
  }
  else {
    local vblvars "" // don't include baseline values
    cap desc `v'_vBL M`v'_vBL // if no baseline values, omit from table
		if _rc == 0 {
      loc omit = 0
		}
    else {
      local omit = 1
    }
  }

  di "Baseline vars: `vblvars'"


		** A. Dummy regressions **
		**************************
    if `omit' == 0 {

		if "`v'" == "ent_profitmargin2_wins" {
			** Here, we want to get the effect on the profit margin for the average enterprise (weighted by revenue) **
			** Get revenue weights for each group **
			gen entweight_rev_EL = entweight_EL * ent_revenue2_wins_PPP

			sum entweight_rev_EL if (ent_type == 2)
			local mean1 = r(sum)
			sum entweight_rev_EL if (ent_type == 1)
			local mean2 = r(sum)
			sum entweight_rev_EL if (ent_type == 3)
			local mean3 = r(sum)

			local withinhhweight = `mean1' / (`mean1' + `mean2' + `mean3')
			local outsidehhweight = `mean2' / (`mean1' + `mean2' + `mean3')
			local ownfarmweight = `mean3' / (`mean1' + `mean2' + `mean3')

			disp "`withinhhweight'"
			disp "`outsidehhweight'"
			disp "`ownfarmweight'"

			reg `v' c.treat#ent_type c.hi_sat#ent_type i.ent_type `vblvars' [aweight=entweight_rev_EL], cluster(village_code)
			outreg2 using "`coeftable'", `outregopt' `outregset'

			local ATE_treat = "`withinhhweight' * 2.ent_type#c.treat + `outsidehhweight' * 1.ent_type#c.treat + `ownfarmweight' * 3.ent_type#c.treat"
		}

		else {
			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **

			reg `v' c.treat#ent_type c.hi_sat#ent_type i.ent_type `vblvars' [aweight=entweight_EL], cluster(village_code)
			outreg2 using "`coeftable'", `outregopt' `outregset'
			local outregopt "append"


			if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {
				// we don't have this information for agricultural businesses
				local ATE_treat = "(2.ent_type#c.treat * `n_ent_from_hh_treatall' / `n_hh_treatall') + (1.ent_type#c.treat * `n_ent_outside_hh_treatall' / `n_hh_treatall') + (3.ent_type#c.treat * `n_ent_ownfarm_treatall' / `n_hh_treatall')"
			}

			if inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {
				// we don't have this information for agricultural businesses
				local ATE_treat = "(2.ent_type#c.treat * `n_ent_from_hh_treatall' / `n_hh_treatall') + (1.ent_type#c.treat * `n_ent_outside_hh_treatall' / `n_hh_treatall')"
			}
		}

		lincom "`ATE_treat'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col1
		estadd local thisstat`countse' = "`r(sestar)'": col1


		** B. Spatial regressions **
		****************************

		** Column 2 -- Treated Villages **
		**********************************

		if "`v'" == "ent_profitmargin2_wins" {
			calculate_optimal_radii `v' [aweight=entweight_rev_EL], ent blvars("`vblvars'")

			local rad = r(r_max)
			local rad2 = optr - 2

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			local amount_list = ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				local amount_list = "`amount_list' pp_actamt_ov_`r2'to`r'km"
			}

			cap gen cons = 1
			** Get mean total effect on enterprises in treatment villages **
      if $runGPS == 1 {
        iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_rev_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
      if $runGPS == 0 {
        ivreg2 `v' i.ent_type `vblvars' (`endregs' = `exregs') [aweight=entweight_rev_EL], cluster(sublocation_code)
      }

			outreg2 using "`coeftable'", `outregopt' `outregset'

			** Here, we want to get the effect on the profit margin for the average enterprise **
			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 2)
			local ATEstring_total = "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill"

			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 1)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + "*`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill"

			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 3)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + "*`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill"

			local ATEstring_spillover = "0"
			foreach vrb of local amount_list {
				sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 2)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"
				sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 2)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 1)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 1)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 3)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"

				sum `vrb' [aweight=entweight_rev_EL] if (treat == 0 & ent_type == 3)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"
			}
		}

		else {
			** use endline enterprise weights
			calculate_optimal_radii `v' [aweight=entweight_EL], ent blvars("`vblvars'")

			local rad = r(r_max)
			local rad2 = `rad' - 2

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			local amount_list = ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				local amount_list = "`amount_list' pp_actamt_ov_`r2'to`r'km"
			}

			cap gen cons = 1

      if $runGPS == 1 {
        iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
			if $runGPS == 0 {
        ivreg2 `v' cons i.ent_type `vblvars' (`endregs' = `exregs') [aweight=entweight_EL], cluster(sublocation_code)
      }
			outreg2 using "`coeftable'", `outregopt' `outregset'

			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
			** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

			sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 2)
			local ATEstring_total = "`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill * `n_ent_from_hh_treatall' / `n_hh_treatall'"

			sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 1)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

			if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
				sum pp_actamt_ownvill [aweight=entweight_EL] if (treat == 1 & ent_type == 3)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill * `n_ent_ownfarm_treatall' / `n_hh_treatall'"
			}

			local ATEstring_spillover = "0"
			foreach vrb of local amount_list {
				sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 2)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_treatall' / `n_hh_treatall'"

				sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 2)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_control' / `n_hh_controlall'"

				sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 1)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

				sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 1)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_control' / `n_hh_controlall'"

				if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
					sum `vrb' [aweight=entweight_EL] if (treat == 1 & ent_type == 3)
					local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_treatall' / `n_hh_treatall'"

					sum `vrb' [aweight=entweight_EL] if (treat == 0 & ent_type == 3)
					local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_control' / `n_hh_controlall'"
				}
			}
		}

		disp "`ATEstring_total'"
		lincom "`ATEstring_total'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col2
		estadd local thisstat`countse' = "`r(sestar)'": col2

		disp "`ATEstring_spillover'"
		lincom "`ATEstring_spillover'"
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
  }
  // end of omit loop
  ** if omitting, add dashes
  else if `omit' == 1 {
    estadd local thisstat`count' = "`omitstring'" : col1
    estadd local thisstat`count' = "`omitstring'" : col2
    estadd local thisstat`count' = "`omitstring'" : col3
    estadd local thisstat`count' = "`omitstring'" : col4
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

if $runGPS == 0 {
  local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
}

di "Exporting tex file"
esttab col1 col2 col3 col4 `using', cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Treatment Villages}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Control Villages}}} & \\   \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ weighted mean (SD)}}") ///
stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

end
