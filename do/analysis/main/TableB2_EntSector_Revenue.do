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

project, original("$dir/do/global_runGPS.do")
include "$dir/do/global_runGPS.do"

// end preliminaries

/*** Enterprise Revenue Results by Sector ***/

***************************************************
** 1. Prepare important village-level quantities **
***************************************************

local panvar "run_id"
local timvar "date"


** get total number of households by group and village **
project, original("$da/GE_HHLevel_ECMA.dta") preserve
use "$da/GE_HHLevel_ECMA.dta", clear
keep village_code treat hi_sat eligible hhweight_EL
bys village_code: egen n_elig = sum(hhweight_EL) if eligible == 1
bys village_code: egen n_inelig = sum(hhweight_EL) if eligible == 0
bys village_code: egen n_hh = sum(hhweight_EL)
bys village_code: egen n_hh_treat = sum(hhweight_EL) if eligible == 1 & treat == 1
replace n_hh_treat = 0 if treat == 0
bys village_code: egen n_hh_untreat = sum(hhweight_EL) if eligible == 0 | treat == 0

sum hhweight_EL if treat == 1
local n_hh_treatall = `r(sum)'

sum hhweight_EL if treat == 0
local n_hh_controlall = `r(sum)'

sum hhweight_EL if treat == 0 & hi_sat == 0
local n_hh_lowsatcontrol = `r(sum)'

sum hhweight_EL if eligible == 1 & treat == 1
local n_hh_treat = `r(sum)'
sum hhweight_EL if eligible == 0 | treat == 0
local n_hh_untreat = `r(sum)'
sum hhweight_EL
local n_hh_tot = `r(sum)'

collapse (mean) n_elig n_inelig n_hh n_hh_treat n_hh_untreat, by(village_code)
tempfile temphh
save `temphh'


** get total number of enterprises by group and village **
project, original("$da/GE_VillageLevel_ECMA.dta") preserve
use "$da/GE_VillageLevel_ECMA.dta", clear
cap la var n_allents "Number of enterprises"
cap la var n_operates_from_hh "Number of enterprises, non-ag operated from hh"
cap la var n_operates_outside_hh "Number of enterprises, non-ag operated outside hh"
cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
keep village_code n_allents n_operates_from_hh n_operates_outside_hh
tempfile tempent
save `tempent'


***********************************************
**** 2. TABLE OF REVENUE EFFECTS BY SECTOR ****
***********************************************

project, original("$da/GE_Enterprise_ECMA.dta") preserve

use "$da/GE_Enterprise_ECMA.dta", clear

if $runGPS == 1 {
	merge 1:1 ent_id_universe using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
}

gen run_id = _n

** using version of revenue winsorized by sector **

local outcomes ent_revenue2_wins_s_PPP

la var ent_revenue2_wins_s_PPP "revenue"

replace sector = 2 if bizcat == 15 | inlist(bizcat_nonfood, 6)

* winsorizing enterprise total hours by sector *
gen ent_hrs_tot_wins_s = ent_hrs_tot
forval i = 1 / 4 {
    summ ent_hrs_tot_wins_s if sector == `i', d
    replace ent_hrs_tot_wins_s = r(p99) if ~mi(ent_hrs_tot_wins_s) & ent_hrs_tot_wins_s > r(p99) & sector == `i'
}
la var ent_hrs_tot_wins_s "Enterprise total hours (wins by sector)"


tempfile current
save `current'

*** STARTING SET-UP OF TABLE ***
* setting up blank table *
drop _all
local ncols = 5
local nrows = 25

*** CREATE EMPTY TABLE ***
eststo clear
est drop _all
quietly{
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

**** looping through sectors ****

* for raw coefficient tables
	local outregopt "replace"
	local outregset "excel label(proper)"


forval i = 1 / 4 { // total of 4 sectors

    use `current', clear
    keep if sector == `i'

    scalar numoutcomes = 0

    foreach v in `outcomes' {
	       scalar numoutcomes = numoutcomes + 1


		merge m:1 village_code using `temphh'
		drop _merge
		merge m:1 village_code using `tempent'
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
		cap desc `v'_vBL M`v'_vBL
		if _rc == 0 {
			local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
		}
		else {
			local vblvars ""
            di "Warning: no baseline variables included"
		}

        di "Check: Baseline variables: `vblvars'"

		** A. Dummy regressions **
		**************************

		** Get number of firms in treatment villages IN THIS SECTOR, by enterprise type **
		sum entweight_EL if (ent_type == 2) & `v' != . & treat == 1
		local n_withinhh = r(sum)
		sum entweight_EL if (ent_type == 1) & `v' != . & treat == 1
		local n_outsidehh = r(sum)
		sum entweight_EL if (ent_type == 3) & `v' != . & treat == 1
		local n_ownfarm = r(sum)

		sum entweight_EL if (ent_type == 2) & `v' != . & treat == 0
		local n_withinhh_control = r(sum)
		sum entweight_EL if (ent_type == 1) & `v' != . & treat == 0
		local n_outsidehh_control = r(sum)
		sum entweight_EL if (ent_type == 3) & `v' != . & treat == 0
		local n_ownfarm_control = r(sum)

		reg `v' c.treat#ent_type c.hi_sat#ent_type i.ent_type `vblvars' [aweight=entweight_EL], cluster(village_code)
		outreg2 using "$dtab/coeftables/EntRevenue_bySector_RawCoefs.xls", `outregopt' `outregset'
		local outregopt "append"

        local ATE_treat = ""

        if !inlist("`v'", "ag_rev", "ag_prof") & `i' != 4 {
			local ATE_treat = "(2.ent_type#c.treat * `n_withinhh' / `n_hh_treatall') + (1.ent_type#c.treat * `n_outsidehh' / `n_hh_treatall')"
		}

		if inlist("`v'", "ag_rev", "ag_prof") | `i' == 4 {
			local ATE_treat = "(3.ent_type#c.treat * `n_ownfarm' / `n_hh_treatall')"
		}


		lincom "`ATE_treat'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col1
		estadd local thisstat`countse' = "`r(sestar)'": col1


		** B. Spatial regressions **
		****************************
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

		gen cons = 1

		** Get mean total effect on enterprises in treatment villages **
		if $runGPS == 1 {
			iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
		}
		if $runGPS == 0 {
			ivreg2 `v' i.ent_type `vblvars' (`endregs' = `exregs') [aweight=entweight_EL], cluster(sublocation_code)
		}
		outreg2 using "$dtab/coeftables/EntRevenue_bySector_RawCoefs.xls", `outregopt' `outregset'

		local n_obs = e(N)

        ** calculate effects for sectors other than ag **
        //
		if `i' != 4 {

			sum pp_actamt_ownvill [aweight=entweight_EL] if (`v' != . & treat == 1 & ent_type == 2)
			local ATEstring_total = "`r(mean)'" + "*2.ent_type#c.pp_actamt_ownvill * `n_withinhh' / `n_hh_treatall'"

			sum pp_actamt_ownvill [aweight=entweight_EL] if (`v' != . & treat == 1 & ent_type == 1)
			local ATEstring_total = "`r(mean)'" + "*1.ent_type#c.pp_actamt_ownvill * `n_outsidehh' / `n_hh_treatall'"
        }
        ** calculate effects for ag **
        if `i' == 4 {
            sum pp_actamt_ownvill [aweight=entweight_EL] if (`v' != . & treat == 1 & ent_type == 3)
			local ATEstring_total = "`r(mean)'" + "*3.ent_type#c.pp_actamt_ownvill * `n_ownfarm' / `n_hh_treatall'"
        }

		local ATEstring_spillover = "0"
		foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`rad2'to`rad'km {
            ** calculate effects for non-ag **
			if `i' != 4 {

				sum `vrb' [aweight=entweight_EL] if (`v' != . & treat == 1 & ent_type == 2)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_withinhh' / `n_hh_treatall'"

				sum `vrb' [aweight=entweight_EL] if (`v' != . & treat == 0 & ent_type == 2)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*2.ent_type#c.`vrb' * `n_withinhh_control' / `n_hh_controlall'"

				sum `vrb' [aweight=entweight_EL] if (`v' != . & treat == 1 & ent_type == 1)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_outsidehh' / `n_hh_treatall'"

				sum `vrb' [aweight=entweight_EL] if (`v' != . & treat == 0 & ent_type == 1)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*1.ent_type#c.`vrb' * `n_outsidehh_control' / `n_hh_controlall'"
			}

            ** calculate effects for ag **
			if `i' == 4 {
                sum `vrb' [aweight=entweight_EL] if (`v' != . & treat == 1 & ent_type == 3)
				local ATEstring_total = "`ATEstring_total'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ownfarm' / `n_hh_treatall'"

                sum `vrb' [aweight=entweight_EL] if (`v' != . & treat == 0 & ent_type == 3)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`r(mean)'" + "*3.ent_type#c.`vrb' * `n_ownfarm_control' / `n_hh_controlall'"
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
		sum entweight_EL if `v' != . & treat == 0 & hi_sat == 0
		local totent = `r(sum)'

		sum `v' [aweight=entweight_EL] if treat == 0 & hi_sat == 0 // gives a weighted average of `v' per enterprise across all types
		di "Control mean: `r(mean)'"

		estadd local thisstat`count' = string(`r(mean)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") : col4
		estadd local thisstat`countse' = "(" + string(`r(sd)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") + ")": col4

		**5. Store number of observations **
		************************************
		estadd local thisstat`count' = string(`n_obs', "%9.0f") : col5

        ** looping variables for tex table **
        // getting sector
        local sector : label (sector) `i'
        local vl : variable label `v'

		local thisvarlabel "`sector' `vl'"

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

** end loop through outcomes
di "End outcome loop"


}
** end loop over sectors **
di "End sector loop"

** exporting tex table ***
local cols = 7
loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{`cols'}{S}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

if $runGPS == 0 {
	local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
}

di "Exporting tex file"
esttab col1 col2 col3 col4 using "$dtab/TableB2_EntRevenue_bySector.tex", cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Treatment Villages}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Control Villages}}} & \\  \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ weighted mean (SD)}}")  ///
stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

project, creates("$dtab/TableB2_EntRevenue_bySector.tex") preserve
