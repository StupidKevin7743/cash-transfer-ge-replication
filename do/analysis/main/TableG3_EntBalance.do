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

project, original("$do/analysis/prep/prep_VillageLevel.do") preserve
include "$do/analysis/prep/prep_VillageLevel.do"

project, original("$da/GE_Enterprise_BL_ECMA.dta")
project, original("$da/GE_VillageLevel_ECMA.dta")

if $runGPS == 1 {
  project, original("$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta")
  project, original("$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta")
}

use "$da/GE_Enterprise_BL_ECMA.dta", clear
merge n:1 village_code using "$da/GE_VillageLevel_ECMA.dta", keepusing(avgdate_vill pp_actamt_* share_ge_elig_treat_*)

drop if _merge == 1
drop _merge


if $runGPS == 1 {
  merge 1:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen

  gen latitude_BL = latitude
  gen longitude_BL = longitude
  // aate_BL in dataset
  drop latitude longitude

  merge n:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
  * fill in missings with village-levle averages
  replace latitude_BL = latitude if mi(latitude_BL)
  replace longitude_BL = longitude if mi(longitude_BL)
  replace date_BL = avgdate_vill if mi(date_BL)

  drop latitude longitude
  ren latitude_BL latitude
  ren longitude_BL longitude
}

project, original("$da/GE_Enterprise_BL_ECMA.dta") preserve
merge 1:1 ent_id_universe using "$da/GE_Enterprise_BL_ECMA.dta", keepusing(ent_type_BL) generate(_merge2)  // _merge already defined in using
drop if _merge2 != 3
cap: drop _merge2
cap: drop _merge

tempfile ENT_BL_data
save `ENT_BL_data'

*****************************
****  RUN ENDLINE TABLE ***
*****************************
local panvar "run_id"
local timvar "date_BL"


local outcomes ent_profit2_wins_PPP_BL ent_revenue2_wins_PPP_BL ent_totcost_wins_PPP_BL  ent_wagebill_wins_PPP_BL n_allents_BL

		* for raw coefficient tables
      local outregopt "replace"
      local outregset "excel label(proper)"


* setting up blank table *
drop _all
local ncols = 4
local nrows = wordcount("`outcomes'")

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

scalar numoutcomes = 0
foreach v in `outcomes' {
	scalar numoutcomes = numoutcomes + 1

	di "Outcome: `v'"

	if inlist("`v'", "n_allents_BL") {
	use "$da/GE_VillageLevel_ECMA.dta", clear

	if $runGPS == 1 {
		merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
	}

	gen run_id = _n
	gen date_BL = run_id // pseudo-panel of depth one.

	cap la var n_allents_BL "\emph{Panel C: Village-level} & & & & \\ Number of enterprises"
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

		local blvars "" // testing balance by this, do not want to include

		di "Check: baseline vars: `blvars'"

	** A. Dummy regressions **
	**************************
	reg phh_`v' treat hi_sat [aweight=n_hh], cluster(village_code)
	outreg2 using "$dtab/coeftables/EntOutcomes_BL_RawCoefs.xls", `outregopt' `outregset'


	** formatting for tex - column 1, indicator for treatment status **
	pstar treat
	estadd local thisstat`count' = "`r(bstar)'": col1
	estadd local thisstat`countse' = "`r(sestar)'": col1


	** B. Spatial regressions **
	****************************
	mata: optr = .,.,.,.,.,.,.,.,.,.
	local endregs = "pp_actamt_ownvill"
	local exregs = "treat"

	forval r = 2(2)20 {
		local r2 = `r' - 2
		local endregs "`endregs' pp_actamt_ov_`r2'to`r'km"
		local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`r'km"
		ivreg2 phh_`v' (`endregs' = `exregs') [aweight=n_hh]
		estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[6]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
	local r = optr
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
    iv_spatial_HAC phh_`v' cons [aweight=n_hh], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  }
  if $runGPS == 0 {
    ivreg2 phh_`v' (`endregs' = `exregs') [aweight=n_hh], cluster(sublocation_code)
  }

	outreg2 using "$dtab/coeftables/EntOutcomes_BL_RawCoefs.xls", `outregopt' `outregset'

	** Get mean total effect in treatment villages **
	sum pp_actamt_ownvill [aweight=n_hh] if treat == 1
	local ATEstring_tot = "`r(mean)'" + "*pp_actamt_ownvill"
	local ATEstring_spillover = "0"

	foreach vrb of local amount_list  {
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

	** Add mean of dependent variable **
	****************************************
	sum phh_`v' [aweight=n_hh] if treat == 0 & hi_sat == 0

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
		use `ENT_BL_data', clear

    cap drop ent_type
		ren ent_type_BL ent_type

		drop if ent_type == .
		drop if entweight_BL == .

		gen run_id = _n

		cap la var ent_profit2_wins_PPP_BL "\emph{Panel A: Non-agricultural enterprises}&&&&\\ Enterprise profits, annualized"
		cap la var ent_profmarg2_wins_PPP_BL "Enterprise profit margin"
		cap la var ent_revenue2_wins_PPP_BL "Enterprise revenue, annualized"
		cap la var ent_totcost_wins_PPP_BL "\emph{Panel B: All enterprises} & & & & \\ Enterprise costs, annualized"
		cap la var ent_wagebill_wins_PPP_BL "\hspace{1em}Enterprise wagebill, annualized"

		merge m:1 village_code using `temphh'
		drop if _merge == 1
		drop _merge
		merge m:1 village_code using `tempent_bl'
		drop _merge

		** adding variable label to the table **
		local add : var label `v'
		local collabels `"`collabels' "`add'""'

		* setting baseline values for weights
		gen entweight = entweight_BL

		if "`v'" == "ent_profmarg2_wins_PPP_BL" {
			** Here, we want to get the effect on the profit margin for the average enterprise (weighted by revenue) **
			** Get revenue weights for each group **
			replace entweight = entweight * ent_revenue2_wins_PPP_BL
		}


		** Get number of enterprises of each group by treatment **
		sum entweight if ent_type == 2 & treat == 1
		local n_ent_from_hh_treatall = r(sum)
		sum entweight if ent_type == 2 & treat == 0
		local n_ent_from_hh_control = r(sum)
		sum entweight if ent_type == 2 & hi_sat == 0 & treat == 0
		local n_ent_from_hh_lowsatcontrol = r(sum)
		sum entweight if ent_type == 2
		local n_ent_from_hh_tot = r(sum)

		sum entweight if ent_type == 1 & treat == 1
		local n_ent_outside_hh_treatall = r(sum)
		sum entweight if ent_type == 1 & treat == 0
		local n_ent_outside_hh_control = r(sum)
		sum entweight if ent_type == 1 & hi_sat == 0 & treat == 0
		local n_ent_outside_hh_lowsatcontrol = r(sum)
		sum entweight if ent_type == 1
		local n_ent_outside_hh_tot = r(sum)

		sum entweight if ent_type == 3 & treat == 1
		local n_ent_ownfarm_treatall = r(sum)
		sum entweight if ent_type == 3 & treat == 0
		local n_ent_ownfarm_control = r(sum)
		sum entweight if ent_type == 3 & hi_sat == 0 & treat == 0
		local n_ent_ownfarm_lowsatcontrol = r(sum)
		sum entweight if ent_type == 3
		local n_ent_ownfarm_tot = r(sum)



		** adding village-level baseline variables - if they are in the dataset **
		local vblvars "" // do not want to include these for anyone

		** A. Dummy regressions **
		**************************

				** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **

			reg `v' c.treat#ent_type c.hi_sat#ent_type i.ent_type [aweight=entweight], cluster(village_code)
			outreg2 using "$dtab/coeftables/EntOutcomes_BL_RawCoefs.xls", `outregopt' `outregset'
			local outregopt "append"


			if !inlist("`v'", "ent_profit2_wins_PPP_BL", "ent_revenue2_wins_PPP_BL", "ent_profmarg2_wins_PPP_BL") {
				// we don't have this information for agricultural businesses
				local ATE_treat = "(2.ent_type#c.treat * `n_ent_from_hh_treatall' / `n_hh_treatall') + (1.ent_type#c.treat * `n_ent_outside_hh_treatall' / `n_hh_treatall') + (3.ent_type#c.treat * `n_ent_ownfarm_treatall' / `n_hh_treatall')"
			}
			else {
				local ATE_treat = "(2.ent_type#c.treat * `n_ent_from_hh_treatall' / `n_hh_treatall') + (1.ent_type#c.treat * `n_ent_outside_hh_treatall' / `n_hh_treatall')"
			}

			di "`ATE_treat'"

		lincom "`ATE_treat'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col1
		estadd local thisstat`countse' = "`r(sestar)'": col1


		** B. Spatial regressions **
		****************************

		** Column 2 -- Treated Villages **
		**********************************

		calculate_optimal_radii `v' [aweight=entweight], ent

			local rad = r(r_max)
			local rad2 = r(r_min)

			local endregs = "c.pp_actamt_ownvill#ent_type"
			local exregs = "treat#ent_type"
			local amount_list ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				local amount_list = "`amount_list' pp_actamt_ov_`r2'to`r'km"
			}

			cap gen cons = 1

      if $runGPS == 1 {
        iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
      if $runGPS == 0 {
        ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight], cluster(sublocation_code)
       }

			outreg2 using "$dtab/coeftables/EntOutcomes_BL_RawCoefs.xls", `outregopt' `outregset'

			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
			** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

			sum pp_actamt_ownvill [aweight=entweight] if (treat == 1 & ent_type == 2)
			local ATEstring_total = "`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill * `n_ent_from_hh_treatall' / `n_hh_treatall'"

			sum pp_actamt_ownvill [aweight=entweight] if (treat == 1 & ent_type == 1)
			local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

			if !inlist("`v'", "ent_profit2_wins_PPP_BL", "ent_revenue2_wins_PPP_BL") {  // we don't have this information for agricultural businesses
				sum pp_actamt_ownvill [aweight=entweight] if (treat == 1 & ent_type == 3)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill * `n_ent_ownfarm_treatall' / `n_hh_treatall'"
			}

			local ATEstring_spillover = "0"
			foreach vrb of local amount_list {
				sum `vrb' [aweight=entweight] if (treat == 1 & ent_type == 2)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_treatall' / `n_hh_treatall'"

				sum `vrb' [aweight=entweight] if (treat == 0 & ent_type == 2)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_ent_from_hh_control' / `n_hh_controlall'"

				sum `vrb' [aweight=entweight] if (treat == 1 & ent_type == 1)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_treatall' / `n_hh_treatall'"

				sum `vrb' [aweight=entweight] if (treat == 0 & ent_type == 1)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_ent_outside_hh_control' / `n_hh_controlall'"

				if !inlist("`v'", "ent_profit2_wins_PPP_BL", "ent_revenue2_wins_PPP_BL") {  // we don't have this information for agricultural businesses
					sum `vrb' [aweight=entweight] if (treat == 1 & ent_type == 3)
					local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_treatall' / `n_hh_treatall'"

					sum `vrb' [aweight=entweight] if (treat == 0 & ent_type == 3)
					local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ent_ownfarm_control' / `n_hh_controlall'"
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


		** Column 4. Add mean of dependent variable **
		****************************************
			sum `v' [aweight=entweight] if treat == 0 & hi_sat == 0 // gives a weighted average of `v' per enterprise across all types

			** here, we want the sum of average per person profit for all enterprise types **
			local totent = `n_ent_from_hh_lowsatcontrol' + `n_ent_outside_hh_lowsatcontrol' + `n_ent_ownfarm_lowsatcontrol'
			estadd local thisstat`count' = string(`r(mean)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") : col4
			estadd local thisstat`countse' = "(" + string(`r(sd)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") + ")": col4


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
esttab col1 col2 col3 col4 using "$dtab/TableG3_EntBalance.tex", cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Treatment Villages}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Control Villages}}} & \\   \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ weighted mean (SD)}}") ///
stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

project, creates("$dtab/TableG3_EntBalance.tex")
