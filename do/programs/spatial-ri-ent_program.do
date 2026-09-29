cap program drop spatial_ri_table_ent
program define spatial_ri_table_ent
    syntax using, outcomes(string) reps(integer) postfile(string) [drawnew(integer 0)]


    project, original("$do/analysis/prep/prep_VillageLevel.do") preserve
    include "$do/analysis/prep/prep_VillageLevel.do"


    local panvar "run_id"
    local timvar "date"

quietly {
* setting up blank table *
drop _all
local ncols = 4
local nrows = max(2,wordcount("`outcomes'"))

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

}


** generating postfile **
cap postclose ent_ri
postfile ent_ri str34 outcome int(rep radii) double(ATE_treat SE_treat ATE_control SE_control)  using "`postfile'", replace
// note -- storing original estimate in 0

scalar numoutcomes = 0
foreach v in `outcomes' {
	scalar numoutcomes = numoutcomes + 1

	di "Outcome: `v'"

	if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {
	use "$da/GE_VillageLevel_ECMA.dta", clear
	gen run_id = _n
	gen date = run_id // pseudo-panel of depth one because no time-series here

  if $runGPS == 1 {
    merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", nogen keep(1 3)
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
    cap desc `v'_BL
    if _rc == 0 {
				gen phh_`v'_BL = `v'_BL / n_hh
       local blvars "phh_`v'_BL"
    }
    else {
        local blvars ""
    }

		di "Check: baseline vars: `blvars'"

    summ phh_`v' pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_18to20km treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_18to20km `blvars'


	** B. Spatial regressions **
	****************************
	mata: optr = .,.,.,.,.,.,.,.,.,.
	forval r = 2(2)20 {
		local r2 = `r' - 2
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) `blvars' [weight=n_hh]
		estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[6]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
	local r = optr
	local r2 = `r' - 2

	cap gen cons = 1

  if $runGPS == 1 {
    iv_spatial_HAC phh_`v' cons `blvars' [aweight=n_hh], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  }
	if $runGPS == 0 {
    ivreg2 phh_`v' `blvars' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km ) [aweight=n_hh], cluster(sublocation_code)
  }


	** Get mean total effect in treatment villages **
	sum pp_actamt_ownvill [weight=n_hh] if treat == 1
	local ATEstring_tot = "`r(mean)'" + "*pp_actamt_ownvill"
	local ATEstring_spillover = "0"

  foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km {
		sum `vrb' [aweight=n_hh] if treat == 1
		local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"

		sum `vrb' [aweight=n_hh] if treat == 0
		local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*" + "`vrb'"
  }

	disp "`ATEstring_tot'"
	lincom "`ATEstring_tot'"
  local total_est = `r(estimate)'
  local SE_total = `r(se)'

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col1
	estadd local thisstat`countse' = "`r(sestar)'": col1

	disp "`ATEstring_spillover'"
	lincom "`ATEstring_spillover'"
  di "check 1"
  local spill_est = `r(estimate)'
  local SE_spill = `r(se)'

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col3
	estadd local thisstat`countse' = "`r(sestar)'": col3

  di "check 2"

// recording original results in rep 0
post ent_ri ("phh_`v'") (0) (optr) (`total_est') (`SE_total') (`spill_est') (`SE_spill')

di "check 3"
	}
	else {
		project, original("$da/GE_Enterprise_ECMA.dta") preserve
		use "$da/GE_Enterprise_ECMA.dta", clear
		gen run_id = _n

    if $runGPS == 1 {
      merge 1:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", nogen keep(1 3)
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

		merge m:1 village_code using `temphh', nogen
		merge m:1 village_code using `tempent_el', nogen

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
		cap desc `v'_vBL M`v'_vBL
		if _rc == 0 {
			local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
      summ `v'_vBL if ent_type == 3
      if `r(N)' == 0 {
        summ M`v'_vBL if ent_type == 3
        assert r(min) == 1 & r(max) == 1
        summ `v'_vBL [weight=entweight_EL]
        replace `v'_vBL = r(mean) if ent_type == 3
      }
		}
		else {
			local vblvars ""
		}

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

		}

		** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
		** Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **



		** B. Spatial regressions **
		****************************

		** Column 2 -- Treated Villages **
		**********************************
    local ATEstring_total = "0"

		if "`v'" == "ent_profitmargin2_wins" {
			mata: optr = .,.,.,.,.,.,.,.,.,.

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			forval r = 2(2)20 {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL]
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
        iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_rev_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
      if $runGPS == 0 {
        ivreg2 `v' i.ent_type `vblvars' (`endregs' = `exregs') [aweight=entweight_rev_EL], cluster(sublocation_code)
      }


			** Here, we want to get the effect on the profit margin for the average enterprise **
			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 2)
			local ATEstring_total = "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill"

			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 1)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + "*`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill"

			sum pp_actamt_ownvill [aweight=entweight_rev_EL] if (treat == 1 & ent_type == 3)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + "*`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill"

			local ATEstring_spillover = "0"
			foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`rad2'to`rad'km {
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
			mata: optr = .,.,.,.,.,.,.,.,.,.

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			forval r = 2(2)20 {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]
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
        iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
		  if $runGPS == 0 {
        ivreg2 `v' i.ent_type `vblvars' (`endregs' = `exregs') [aweight=entweight_EL], cluster(sublocation_code)
      }

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
			foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`rad2'to`rad'km {
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
    local total_est = `r(estimate)'
    local SE_total = `r(se)'


		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col1
		estadd local thisstat`countse' = "`r(sestar)'": col1

		disp "`ATEstring_spillover'"
		lincom "`ATEstring_spillover'"
    local spill_est = `r(estimate)'
    local SE_spill = `r(se)'


		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col3
		estadd local thisstat`countse' = "`r(sestar)'": col3


    post ent_ri ("`v'") (0) (optr) (`total_est') (`SE_total') (`spill_est') (`SE_spill')


}

if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {
    loc keeplist "*n_hh*"
}
else {
    loc keeplist *weight* ent_type
}

    keep *`v'* `keeplist' village_code


    		tempfile sourcedata
    		save `sourcedata'

    		//}


/*****************************************************************************/
/*  start Randomization Inference loops         */
/****************************************/

    		loc total_count = 0
    		loc spill_count = 0

    		di ""
    		_dots 0, title(Spatial RI running for `v') reps(`reps')

forvalues rep = 1/`reps' {


use `sourcedata', clear

capture confirm file "$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta"

if `drawnew' == 1 | _rc == 601{ // if we specified we'd draw a new one or the current draw does not exits, draw a new one
  di "Drawing allocation `rep'"
  draw_alloc, outdir("$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta") rep(`rep')
}

merge n:1 village_code using "$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta", nogen


	** B. Spatial regressions **
	****************************

  if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {


    mata: optr = .,.,.,.,.,.,.,.,.,.
    	forval r = 2(2)20 {
    		local r2 = `r' - 2
    		ivreg2 phh_`v' (ri_pp_actamt_ownvill ri_pp_actamt_ov_0to2km-ri_pp_actamt_ov_`r2'to`r'km = ri_treat ri_share_treat_ov_0to2km-ri_share_treat_ov_`r2'to`r'km) `blvars' [weight=n_hh]
    		estat ic
    		mata: optr[`r'/2] = st_matrix("r(S)")[6]
    	}

  	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
  	local r = optr
  	local r2 = `r' - 2

	   cap gen cons = 1

     * point estimate only -- can use ivreg not conley
     	ivreg2 phh_`v' (ri_pp_actamt_ownvill ri_pp_actamt_ov_0to2km-ri_pp_actamt_ov_`r2'to`r'km = ri_treat ri_share_treat_ov_0to2km-ri_share_treat_ov_`r2'to`r'km) `blvars' [weight=n_hh]



  	** Get mean total effect in treatment villages **
  	sum ri_pp_actamt_ownvill [weight=n_hh] if ri_treat == 1
    local ATEstring_tot = "`r(mean)'" + "*ri_pp_actamt_ownvill"
  	local ATEstring_spillover = "0"

	foreach vrb of var ri_pp_actamt_ov_0to2km-ri_pp_actamt_ov_`r2'to`r'km {
		sum `vrb' [aweight=n_hh] if ri_treat == 1
		local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"

		sum `vrb' [aweight=n_hh] if ri_treat == 0
		local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*" + "`vrb'"
	}


	disp "`ATEstring_tot'"
	lincom "`ATEstring_tot'"
  loc ATE_total = `r(estimate)'

  if abs(`r(estimate)') > abs(`total_est') loc ++total_count

	disp "`ATEstring_spillover'"
	lincom "`ATEstring_spillover'"
  loc ATE_spill = `r(estimate)'
  if abs(`r(estimate)') > abs(`spill_est')  loc ++spill_count


  ** posting rep results
  post ent_ri ("phh_`v'") (`rep') (optr) (`ATE_total') (.) (`ATE_spill') (.)
}

else {

if "`v'" == "ent_profitmargin2_wins" {
  ** Here, we want to get the effect on the profit margin for the average enterprise (weighted by revenue) **
  ** Get revenue weights for each group **
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

  mata: optr = .,.,.,.,.,.,.,.,.,.

    local endregs = "c.ri_pp_actamt_ownvill#ent_type"
    local exregs = "ri_treat#ent_type"
    forval r = 2(2)20 {
      local r2 = `r' - 2
      local endregs = "`endregs'" + " c.ri_pp_actamt_ov_`r2'to`r'km#ent_type"
      local exregs = "`exregs'" + " c.ri_share_treat_ov_`r2'to`r'km#ent_type"
      ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL]
      estat ic
      mata: optr[`r'/2] = st_matrix("r(S)")[6]
    }

    mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
    local rad = optr
    local rad2 = optr - 2

    local endregs = "c.ri_pp_actamt_ownvill#ent_type"
    local exregs = "ri_treat#ent_type"
    forval r = 2(2)`rad' {
      local r2 = `r' - 2
      local endregs = "`endregs'" + " c.ri_pp_actamt_ov_`r2'to`r'km#ent_type"
      local exregs = "`exregs'" + " c.ri_share_treat_ov_`r2'to`r'km#ent_type"
    }

    cap gen cons = 1
    ** Get mean total effect on enterprises in treatment villages **
      ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL]

    ** Here, we want to get the effect on the profit margin for the average enterprise **
    sum ri_pp_actamt_ownvill [aweight=entweight_rev_EL] if (ri_treat == 1 & ent_type == 2)
    local ATEstring_total = "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.ri_pp_actamt_ownvill"

    sum ri_pp_actamt_ownvill [aweight=entweight_rev_EL] if (ri_treat == 1 & ent_type == 1)
    local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + "*`r(mean)'" + "*1.ent_type#c.ri_pp_actamt_ownvill"

    sum ri_pp_actamt_ownvill [aweight=entweight_rev_EL] if (ri_treat == 1 & ent_type == 3)
    local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + "*`r(mean)'" + "*3.ent_type#c.ri_pp_actamt_ownvill"

    local ATEstring_spillover = "0"
    foreach vrb of var ri_pp_actamt_ov_0to2km-ri_pp_actamt_ov_`rad2'to`rad'km {
      sum `vrb' [aweight=entweight_rev_EL] if (ri_treat == 1 & ent_type == 2)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"
      sum `vrb' [aweight=entweight_rev_EL] if (ri_treat == 0 & ent_type == 2)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`withinhhweight'" + "*`r(mean)'" + "*2.ent_type#c.`vrb'"

      sum `vrb' [aweight=entweight_rev_EL] if (ri_treat == 1 & ent_type == 1)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

      sum `vrb' [aweight=entweight_rev_EL] if (ri_treat == 0 & ent_type == 1)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`outsidehhweight'" + + "*`r(mean)'" + "*1.ent_type#c.`vrb'"

      sum `vrb' [aweight=entweight_rev_EL] if (ri_treat == 1 & ent_type == 3)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"

      sum `vrb' [aweight=entweight_rev_EL] if (ri_treat == 0 & ent_type == 3)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ownfarmweight'" + + "*`r(mean)'" + "*3.ent_type#c.`vrb'"
    }
  }

  else {
    mata: optr = .,.,.,.,.,.,.,.,.,.

    local endregs = "c.ri_pp_actamt_ownvill#ent_type"
    local exregs = "ri_treat#ent_type"
    forval r = 2(2)20 {
      local r2 = `r' - 2
      local endregs = "`endregs'" + " c.ri_pp_actamt_ov_`r2'to`r'km#ent_type"
      local exregs = "`exregs'" + " c.ri_share_treat_ov_`r2'to`r'km#ent_type"
      ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]
      estat ic
      mata: optr[`r'/2] = st_matrix("r(S)")[6]
    }

    mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
    local rad = optr
    local rad2 = optr - 2

    local endregs = "c.ri_pp_actamt_ownvill#ent_type"
    local exregs = "ri_treat#ent_type"
    forval r = 2(2)`rad' {
      local r2 = `r' - 2
      local endregs = "`endregs'" + " c.ri_pp_actamt_ov_`r2'to`r'km#ent_type"
      local exregs = "`exregs'" + " c.ri_share_treat_ov_`r2'to`r'km#ent_type"
    }

    cap gen cons = 1
    ** point estimate only -- can use ivreg
    ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]


    ** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
    ** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
    ** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

    sum ri_pp_actamt_ownvill [aweight=entweight_EL] if (ri_treat == 1 & ent_type == 2)
    local ATEstring_total = "`r(mean)'" + "*2.ent_type#c.ri_pp_actamt_ownvill * `n_ent_from_hh_treatall' / `n_hh_treatall'"

    sum ri_pp_actamt_ownvill [aweight=entweight_EL] if (ri_treat == 1 & ent_type == 1)
    local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.ri_pp_actamt_ownvill * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

    if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
      sum ri_pp_actamt_ownvill [aweight=entweight_EL] if (ri_treat == 1 & ent_type == 3)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.ri_pp_actamt_ownvill * `n_ent_ownfarm_treatall' / `n_hh_treatall'"
    }

    local ATEstring_spillover = "0"
    foreach vrb of var ri_pp_actamt_ov_0to2km-ri_pp_actamt_ov_`rad2'to`rad'km {
      sum `vrb' [aweight=entweight_EL] if (ri_treat == 1 & ent_type == 2)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_treatall' / `n_hh_treatall'"

      sum `vrb' [aweight=entweight_EL] if (ri_treat == 0 & ent_type == 2)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_control' / `n_hh_controlall'"

      sum `vrb' [aweight=entweight_EL] if (ri_treat == 1 & ent_type == 1)
      local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

      sum `vrb' [aweight=entweight_EL] if (ri_treat == 0 & ent_type == 1)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_control' / `n_hh_controlall'"

      if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
        sum `vrb' [aweight=entweight_EL] if (ri_treat == 1 & ent_type == 3)
        local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_treatall' / `n_hh_treatall'"

        sum `vrb' [aweight=entweight_EL] if (ri_treat == 0 & ent_type == 3)
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_control' / `n_hh_controlall'"
      }
    }
  }

  disp "`ATEstring_total'"
  lincom "`ATEstring_total'"
  loc ATE_total = `r(estimate)'
    if abs(`r(estimate)') > abs(`total_est') loc ++total_count

    disp "`ATEstring_spillover'"
  lincom "`ATEstring_spillover'"
  loc ATE_spill = `r(estimate)'

  if abs(`r(estimate)') > abs(`spill_est') loc ++spill_count

  ** posting results for rep
  post ent_ri ("`v'") (`rep') (optr) (`ATE_total') (.) (`ATE_spill') (.)

}

}

loc total_p = `total_count' / `reps'
loc spill_p = `spill_count' / `reps'

 pstar, p(`total_p') pstar pbrackets
estadd local thisstat`count' = "`r(pstar)'": col2

 pstar, p(`spill_p') pstar pbrackets
estadd local thisstat`count' = "`r(pstar)'": col4

/*** PREPARING FOR NEXT LOOP ***/

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

// end loop through outcomes
di "End outcome loop"

postclose ent_ri

*** exporting tex table ***
** dropping column 2 **
loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{6}{S}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

if $runGPS == 0 {
  local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
}


di "Exporting tex file"
esttab col1 col2 col3 col4 `using', cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Treated Villages}}} & & \multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Control Villages}}} & \\   \cline{2-3}\cline{5-6} \\ & \multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Spatial RI \\ \vspace{.1cm} \\ \emph{p}-value}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Spatial RI \\ \vspace{.1cm} \\ \emph{p}-value}}") ///
stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')

end
