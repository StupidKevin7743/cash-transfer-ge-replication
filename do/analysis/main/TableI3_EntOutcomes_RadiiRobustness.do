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

*****************************
**** RUN ENDLINE TABLE ***
*****************************
local panvar "run_id"
local timvar "date"

local outcomes ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP  n_allents

		* for raw coefficient tables
      local outregopt "replace"
      local outregset "excel label(proper)"


* setting up blank table *
drop _all
local ncols = 9
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

	if inlist("`v'", "n_allents", "n_operates_outside_hh", "n_operates_from_hh", "n_ent_ownfarm") {
	use "$da/GE_VillageLevel_ECMA.dta", clear
	
      if $runGPS == 1 {
        merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
      }
	  
	gen run_id = _n
	gen date = run_id // TG we have no time series here, so I just create a pseudo-panel of depth one.

	cap la var n_allents "\emph{Panel C: Village-level} & & & & \\ Number of enterprises"
	cap la var n_operates_from_hh "Number of enterprises, operated from hh"
	cap la var n_operates_outside_hh "Number of enterprises, operated outside hh"
	cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
	cap la var n_ent_eligibletreat "Number of enterprises, owned by treated households"
	cap la var n_ent_ineligible "Number of enterprises, owned by untreated households"

	merge 1:1 village_code using `temphh', nogen
	gen phh_`v' = `v' / n_hh

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


	** B. Spatial regressions **
	****************************
	mata: optr = .,.,.,.,.,.,.,.,.,.
	forval r = 2(2)20 {
		local r2 = `r' - 2
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) `blvars' [aweight=n_hh]
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
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) cons `blvars' [aweight=n_hh], cluster(sublocation_code)
	}	
	outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

	** Get mean total effect in treatment villages **
	sum pp_actamt_ownvill [aweight=n_hh] if treat == 1
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

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col1 //column 1 = column 2 in main table, ATE optimal r
	estadd local thisstat`countse' = "`r(sestar)'": col1

	disp "`ATEstring_spillover'"
	lincom "`ATEstring_spillover'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col5 //column 5 = column 3 main table, ATE optimal r for control group
	estadd local thisstat`countse' = "`r(sestar)'": col5

	********************* ATE for fixed max radius 2 *************************


	local maxradius = 2

	mata: optr = .,.,.,.,.,.,.,.,.,.
	forval r = 2(2)`maxradius' {
		local r2 = `r' - 2
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) `blvars' [aweight=n_hh]
		estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[6]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
	local r = `maxradius'
	local r2 = `r' - 2

	cap gen cons = 1

	if $runGPS == 1 {
		iv_spatial_HAC phh_`v' cons `blvars' [aweight=n_hh], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
	}
	if $runGPS == 0 {
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km)  cons `blvars' [aweight=n_hh], cluster(sublocation_code)
	}	
	outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

	** Get mean total effect in treatment villages **
	sum pp_actamt_ownvill [aweight=n_hh] if treat == 1
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

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col2 //column 2, ATE fixed radius treated
	estadd local thisstat`countse' = "`r(sestar)'": col2

	disp "`ATEstring_spillover'"
	lincom "`ATEstring_spillover'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col6 //column 6, ATE fixed radius for control group
	estadd local thisstat`countse' = "`r(sestar)'": col6


	********************* ATE for fixed max radius 4 *************************

	local maxradius = 4
	mata: optr = .,.,.,.,.,.,.,.,.,.
	forval r = 2(2)`maxradius' {
		local r2 = `r' - 2
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) `blvars' [aweight=n_hh]
		estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[6]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
	local r = `maxradius'
	local r2 = `r' - 2

	cap gen cons = 1

	if $runGPS == 1 {
		iv_spatial_HAC phh_`v' cons `blvars' [aweight=n_hh], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
	}
	if $runGPS == 0 {
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) cons `blvars' [aweight=n_hh], cluster(sublocation_code)
	}	
	
	outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

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

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col3
	estadd local thisstat`countse' = "`r(sestar)'": col3

	disp "`ATEstring_spillover'"
	lincom "`ATEstring_spillover'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col7
	estadd local thisstat`countse' = "`r(sestar)'": col7

	********************* ATE for fixed max radius 6*************************

	local maxradius = 6
	mata: optr = .,.,.,.,.,.,.,.,.,.
	forval r = 2(2)`maxradius' {
		local r2 = `r' - 2
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) `blvars' [aweight=n_hh]
		estat ic
		mata: optr[`r'/2] = st_matrix("r(S)")[6]
	}

	mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
	local r = `maxradius'
	local r2 = `r' - 2

	cap gen cons = 1

	if $runGPS == 1 {
		iv_spatial_HAC phh_`v' cons `blvars' [aweight=n_hh], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
	}
	if $runGPS == 0 {
		ivreg2 phh_`v' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) cons `blvars' [aweight=n_hh], cluster(sublocation_code)
	}		
	
	outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

	** Get mean total effect in treatment villages **
	sum pp_actamt_ownvill [aweight=n_hh] if treat == 1
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

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col4
	estadd local thisstat`countse' = "`r(sestar)'": col4

	disp "`ATEstring_spillover'"
	lincom "`ATEstring_spillover'"

	pstar, b(`r(estimate)') se(`r(se)')
	estadd local thisstat`count' = "`r(bstar)'": col8
	estadd local thisstat`countse' = "`r(sestar)'": col8

	** 4. Add mean of dependent variable **
	****************************************
	sum phh_`v' [aweight=n_hh] if treat == 0 & hi_sat == 0

	estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col9 //column 9 = main table column 4,  weighted mean
	estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col9


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



		** B. Spatial regressions **
		****************************

		******** Treated Villages ********
		**********************************

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
				ivreg2 `v' (`endregs' = `exregs') cons i.ent_type `vblvars' [aweight=entweight_rev_EL], cluster(sublocation_code)
			}			
			
			outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

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
				ivreg2 `v' (`endregs' = `exregs') cons i.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code)
			}				
			outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

			** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
			** Column 1: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
			** Column 5: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

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
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col1
		estadd local thisstat`countse' = "`r(sestar)'": col1

		disp "`ATEstring_spillover'"
		lincom "`ATEstring_spillover'"
		pstar, b(`r(estimate)') se(`r(se)')
		estadd local thisstat`count' = "`r(bstar)'": col5
		estadd local thisstat`countse' = "`r(sestar)'": col5

		********** ATE for fixed radius 2 **********
		********************************************
					local maxradius = 2
					if "`v'" == "ent_profitmargin2_wins" {
						mata: optr = .,.,.,.,.,.,.,.,.,.

						local endregs = "c.pp_actamt_ownvill#ent_type"
						local exregs = "treat#ent_type"
						forval r = 2(2)`maxradius' {
							local r2 = `r' - 2
							local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
							local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
							ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL]
							estat ic
							mata: optr[`r'/2] = st_matrix("r(S)")[6]
						}

						mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
						local rad = `maxradius'
						local rad2 = `rad' - 2

						local endregs = "c.pp_actamt_ownvill#ent_type"
						local exregs = "treat#ent_type"
						forval r = 2(2)`maxradius' {
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
							ivreg2 `v' (`endregs' = `exregs')  cons i.ent_type `vblvars' [aweight=entweight_rev_EL], cluster(sublocation_code)
						}						
						outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

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
						local maxradius = 2
						mata: optr = .,.,.,.,.,.,.,.,.,.

						local endregs = "c.pp_actamt_ownvill#ent_type"
						local exregs = "treat#ent_type"
						forval r = 2(2)`maxradius' {
							local r2 = `r' - 2
							local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
							local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
							ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]
							estat ic
							mata: optr[`r'/2] = st_matrix("r(S)")[6]
						}

						mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
						local rad = `maxradius'
						local rad2 = `rad' - 2

						local endregs = "c.pp_actamt_ownvill#ent_type"
						local exregs = "treat#ent_type"
						forval r = 2(2)`maxradius' {
							local r2 = `r' - 2
							local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
							local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
						}

						cap gen cons = 1
						if $runGPS == 1 {
							iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
						}
						if $runGPS == 0 {
							ivreg2 `v' (`endregs' = `exregs')  cons i.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code)
						}	
						outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

						** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
						** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
						** Column 6: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

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
					pstar, b(`r(estimate)') se(`r(se)')
					estadd local thisstat`count' = "`r(bstar)'": col2
					estadd local thisstat`countse' = "`r(sestar)'": col2

					disp "`ATEstring_spillover'"
					lincom "`ATEstring_spillover'"
					pstar, b(`r(estimate)') se(`r(se)')
					estadd local thisstat`count' = "`r(bstar)'": col6
					estadd local thisstat`countse' = "`r(sestar)'": col6


********** ATE for fixed radius 4 **********
********************************************
			local maxradius = 4
			if "`v'" == "ent_profitmargin2_wins" {
				mata: optr = .,.,.,.,.,.,.,.,.,.

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
					ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL]
					estat ic
					mata: optr[`r'/2] = st_matrix("r(S)")[6]
				}

				mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
				local rad = `maxradius'
				local rad2 = `rad' - 2

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
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
					ivreg2 `v' (`endregs' = `exregs')  cons i.ent_type `vblvars' [aweight=entweight_rev_EL], cluster(sublocation_code)
				}	
				outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

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
				local maxradius = 4
				mata: optr = .,.,.,.,.,.,.,.,.,.

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
					ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]
					estat ic
					mata: optr[`r'/2] = st_matrix("r(S)")[6]
				}

				mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
				local rad = `maxradius'
				local rad2 = `rad' - 2

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				}

				cap gen cons = 1
				if $runGPS == 1 {
					iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
				}
				if $runGPS == 0 {
					ivreg2 `v' (`endregs' = `exregs')  cons i.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code)
				}	
				outreg2 using "$dtab/coeftables/TableI3_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

				** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
				** Column 3: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
				** Column 7: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

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
			pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col3
			estadd local thisstat`countse' = "`r(sestar)'": col3

			disp "`ATEstring_spillover'"
			lincom "`ATEstring_spillover'"
			pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col7
			estadd local thisstat`countse' = "`r(sestar)'": col7

********** ATE for fixed radius 6 **********
********************************************
			local maxradius = 6
			if "`v'" == "ent_profitmargin2_wins" {
				mata: optr = .,.,.,.,.,.,.,.,.,.

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
					ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_rev_EL]
					estat ic
					mata: optr[`r'/2] = st_matrix("r(S)")[6]
				}

				mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
				local rad = `maxradius'
				local rad2 = `rad' - 2

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
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
					ivreg2 `v' (`endregs' = `exregs')  cons i.ent_type `vblvars' [aweight=entweight_rev_EL], cluster(sublocation_code)
				}	
				outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

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
				local maxradius = 6
				mata: optr = .,.,.,.,.,.,.,.,.,.

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
					ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL]
					estat ic
					mata: optr[`r'/2] = st_matrix("r(S)")[6]
				}

				mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
				local rad = `maxradius'
				local rad2 = `rad' - 2

				local endregs = "c.pp_actamt_ownvill#ent_type"
				local exregs = "treat#ent_type"
				forval r = 2(2)`maxradius' {
					local r2 = `r' - 2
					local endregs = "`endregs'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
					local exregs = "`exregs'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
				}

				cap gen cons = 1
				if $runGPS == 1 {
					iv_spatial_HAC `v' cons i.ent_type `vblvars' [aweight=entweight_EL], en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
				}
				if $runGPS == 0 {
					ivreg2 `v' (`endregs' = `exregs')  cons i.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code)
				}
				outreg2 using "$dtab/coeftables/Appendix_EntOutcomes_RadiiRobustness_RawCoefs.xls", `outregopt' `outregset'

				** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
				** Column 4: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
				** Column 8: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

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
			pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col4
			estadd local thisstat`countse' = "`r(sestar)'": col4

			disp "`ATEstring_spillover'"
			lincom "`ATEstring_spillover'"
			pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col8
			estadd local thisstat`countse' = "`r(sestar)'": col8

		** 4. Add mean of dependent variable **
		****************************************
		if "`v'" == "ent_profitmargin2_wins" {

			sum `v' [aweight=entweight_rev_EL] if treat == 0 & hi_sat == 0 // gives a weighted average of `v' per enterprise across all types

			** here, we want the average profit margin for the average enterprise **
			estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col9
			estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col9
		}

		else {

			sum `v' [aweight=entweight_EL] if treat == 0 & hi_sat == 0 // gives a weighted average of `v' per enterprise across all types

			** here, we want the sum of average per person profit for all enterprise types **
			local totent = `n_ent_from_hh_lowsatcontrol' + `n_ent_outside_hh_lowsatcontrol' + `n_ent_ownfarm_lowsatcontrol'
			estadd local thisstat`count' = string(`r(mean)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") : col9
			estadd local thisstat`countse' = "(" + string(`r(sd)' * `totent' / `n_hh_lowsatcontrol', "%9.2f") + ")": col9
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
loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{`ncols'}{S}} \toprule"
loc postfoot "\bottomrule\end{tabular}}"

di "Exporting tex file"
	esttab col1 col2 col3 col4 col5 col6 col7 col8 col9 using "$dtab/TableI3_EntOutcomes_RadiiRobustness", cells(none) booktabs nonotes compress replace ///
	mgroups("\textbf{Treatment Villages}" "\textbf{Control Villages}", pattern(1 0 0 0 1 0 0 0 1) ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
	mtitle("\shortstack{Total Effect \\ IV \\ Optimal Radius}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 2$}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 4$}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 6$}" "\shortstack{Total Effect \\ IV \\ Optimal Radius}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 2$}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 4$}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 6$}"  "\shortstack{Control, low-saturation \\ mean (SD)}") ///
	stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')


project, creates("$dtab/TableI3_EntOutcomes_RadiiRobustness.tex")
