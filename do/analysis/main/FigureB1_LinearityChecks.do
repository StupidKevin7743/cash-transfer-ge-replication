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

// end preliminaries

local n_bins = 5

***************************************************
** 1. Prepare important village-level quantities **
***************************************************

** get total number of households by group and village **
project, original("$da/GE_HHLevel_ECMA.dta") preserve
use "$da/GE_HHLevel_ECMA.dta", clear
gen run_id = _n
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

*********************************
**** 1. Household consumption ***
*********************************
use "$da/GE_HHLevel_ECMA.dta", clear


** generate bins of treatment variables **
egen bn_share_ge_elig_treat_ov_0to2km = cut(share_ge_elig_treat_ov_0to2km), group(`n_bins') label
replace bn_share_ge_elig_treat_ov_0to2km = bn_share_ge_elig_treat_ov_0to2km + 1

** fix labels at average of each bin **
mata: atmat_ov = J(1,`n_bins',.)
forval i = 1/`n_bins' {
	sum share_ge_elig_treat_ov_0to2km if bn_share_ge_elig_treat_ov_0to2km == `i'
	local lab`i' = `r(mean)'
	mata: atmat_ov[1,`i'] = st_numscalar("r(mean)")
}

label def treatlab_ov 1 "`lab1'" 2 "`lab2'" 3 "`lab3'" 4 "`lab4'" 5 "`lab5'" 6 "`lab6'" 7 "`lab7'" 8 "`lab8'" 9 "`lab9'" 10 "`lab10'" 11 "`lab11'" 12 "`lab12'" 13 "`lab13'" 14 "`lab14'" 15 "`lab15'" 16 "`lab16'" 17 "`lab17'" 18 "`lab18'" 19 "`lab19'" 20 "`lab20'"
label val bn_share_ge_elig_treat_ov_0to2km treatlab_ov


egen bn_share_ge_elig_treat_0to2km = cut(share_ge_elig_treat_0to2km), group(`n_bins') label
replace bn_share_ge_elig_treat_0to2km = bn_share_ge_elig_treat_0to2km + 1

** fix labels at average of each bin **
mata: atmat = J(1,`n_bins',.)
forval i = 1/`n_bins' {
	sum share_ge_elig_treat_0to2km if bn_share_ge_elig_treat_0to2km == `i'
	local lab`i' = `r(mean)'
	mata: atmat[1,`i'] = st_numscalar("r(mean)")
}

label def treatlab 1 "`lab1'" 2 "`lab2'" 3 "`lab3'" 4 "`lab4'" 5 "`lab5'" 6 "`lab6'" 7 "`lab7'" 8 "`lab8'" 9 "`lab9'" 10 "`lab10'" 11 "`lab11'" 12 "`lab12'" 13 "`lab13'" 14 "`lab14'" 15 "`lab15'" 16 "`lab16'" 17 "`lab17'" 18 "`lab18'" 19 "`lab19'" 20 "`lab20'"
label val bn_share_ge_elig_treat_0to2km treatlab


*local outcomes ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_inventory_wins_PPP ent_inv_wins_PPP ent_profitmargin2_wins n_allents
local outcomes p2_consumption_wins_PPP

** a) spillover on all households overall **
scalar numoutcomes = 0
foreach v in `outcomes' {
	scalar numoutcomes = numoutcomes + 1

	di "Outcome: `v'"

	cap la var p2_consumption_wins_PPP "Consumption expenditure, annualized"

	** adding baseline variables - if they are in the dataset **
	cap desc `v'_BL M`v'_BL
	if _rc == 0 {
		local blvars "`v'_BL#ent_type M`v'_BL"
	}
	else {
		local blvars ""
	}

	** Run Non-Linear Regression **
	*******************************
	gen cons = 1

	//ivreg2 `v' (`endregs' = `exregs') i.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code)
	*ols_spatial_HAC `v' treat#ent_type c.share_ge_elig_treat_0to2km#ent_type cons i.ent_type `vblvars' [aweight=entweight_EL], lat(latitude) lon(longitude) timevar(survey_mth) panelvar(ent_id_universe) dist(10) lag(0) dropvar
	reg `v' ib1.bn_share_ge_elig_treat_ov_0to2km ibn.eligible 1.treat#1.eligible `blvars' cons [aweight=hhweight_EL], cluster(sublocation_code) nocons

	mata: coefmat = J(3,`n_bins',.)
	mata: st_numscalar("abc", atmat_ov[1,2] - atmat_ov[1,1])
	local xdiff = abc
	local linearity_test = "2.bn_share_ge_elig_treat_ov_0to2km / `xdiff'"

	forval i = 2/`n_bins' {
		lincom "`i'.bn_share_ge_elig_treat_ov_0to2km"

		mata {
			coefmat[1,`i'] = st_numscalar("r(estimate)")
			coefmat[2,`i'] = st_numscalar("r(lb)")
			coefmat[3,`i'] = st_numscalar("r(ub)")
		}

		if `i' > 2 {
			local i2 = `i'-1
			mata: st_numscalar("abc", atmat_ov[1,`i'] - atmat_ov[1,`i'-1])
			local xdiff = abc
			local linearity_test = "`linearity_test'" + " = (`i'.bn_share_ge_elig_treat_ov_0to2km - `i2'.bn_share_ge_elig_treat_ov_0to2km) / `xdiff'"
		}
	}

	disp "`linearity_test'"
	test "`linearity_test'"
	local lintest_p: di %3.2f `=round(r(p),0.01)'

	** get linear prediction **
	reg `v' share_ge_elig_treat_ov_0to2km ibn.eligible 1.treat#1.eligible `blvars' cons [aweight=hhweight_EL], cluster(sublocation_code) nocons

	** get average slope **
	lincom "share_ge_elig_treat_ov_0to2km"
	mata: slope = st_numscalar("r(estimate)")

	** prepare matrices **
	mata: linmat = J(1,`n_bins',.)
	mata: intercept = coefmat[1,1]
	forval i = 1/`n_bins' {
		mata: linmat[1,`i'] = (atmat_ov[1,`i'] - atmat_ov[1,1])*slope
	}

	mata {
		coefmat[1,1] = 0 // everything is relative to this bin

		st_matrix("coefmat", coefmat)
		st_matrix("linmat", linmat)
		st_matrix("atmat_ov", atmat_ov)
	}

	** make graph **
	local thisvarlabel: variable label `v'

	coefplot (matrix(coefmat[1]), ci((coefmat[2] coefmat[3])) label("Non-linear coefficient estimates")) (matrix(linmat), recast(line) label("Linear specification")), at(matrix(atmat_ov)) /*xlabel(0(0.2)1) xscale(range(0(0.2)1))*/ xtitle("Share of eligibles treated within 0 to 2km", margin(top)) ytitle("`thisvarlabel'") scheme(tufte) legend(off) /*legend(cols(2) size(small) bmargin(tiny))*/ name(gph_cons, replace) ///
	ylabel(-200(200)800) yscale(range(-200(200)800)) ///
	text(780 0.2 "p-value :  `lintest_p'", placement(se) just(left))
	*text(580 0.19 "H{sub:0}         :  effect is linear" "p-value :  `lintest_p'", placement(se) just(left))
}



******************************
**** 2. Enterprise Revenue ***
******************************

** get total number of enterprises by group and village **
use "$da/GE_VillageLevel_ECMA.dta", clear
gen run_id = _n
gen date = run_id // TG we have no time series here, so I just create a pseudo-panel of depth one.

cap la var n_allents "Number of enterprises"
cap la var n_operates_from_hh "Number of enterprises, non-ag operated from hh"
cap la var n_operates_outside_hh "Number of enterprises, non-ag operated outside hh"
cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
keep village_code n_allents n_operates_from_hh n_operates_outside_hh
tempfile tempent
save `tempent'

local outcomes ent_revenue2_wins_PPP

scalar numoutcomes = 0
foreach v in `outcomes' {
	scalar numoutcomes = numoutcomes + 1

	di "Outcome: `v'"

	use "$da/GE_Enterprise_ECMA.dta", clear

	cap la var n_allents "Number of enterprises"
	cap la var ent_revenue2_wins_PPP "Enterprise revenue, annualized"

	merge m:1 village_code using `temphh'
	drop _merge
	merge m:1 village_code using `tempent'
	drop _merge

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
		local vblvars "c.`v'_vBL#ibn.ent_type M`v'_vBL#ibn.ent_type"
	}
	else {
		local vblvars ""
	}

	** Run Non-Linear Regression **
	*******************************

	** generate bins of treatment variables **
	egen bn_share_ge_elig_treat_ov_0to2km = cut(share_ge_elig_treat_ov_0to2km), group(`n_bins') label
	replace bn_share_ge_elig_treat_ov_0to2km = bn_share_ge_elig_treat_ov_0to2km + 1

	** fix labels at average of each bin **
	mata: atmat = J(1,`n_bins',.)
	forval i = 1/`n_bins' {
		sum share_ge_elig_treat_ov_0to2km if bn_share_ge_elig_treat_ov_0to2km == `i'
		local lab`i' = `r(mean)'
		mata: atmat[1,`i'] = st_numscalar("r(mean)")
	}

	label def treatlab 1 "`lab1'" 2 "`lab2'" 3 "`lab3'" 4 "`lab4'" 5 "`lab5'" 6 "`lab6'" 7 "`lab7'" 8 "`lab8'" 9 "`lab9'" 10 "`lab10'" 11 "`lab11'" 12 "`lab12'" 13 "`lab13'" 14 "`lab14'" 15 "`lab15'" 16 "`lab16'" 17 "`lab17'" 18 "`lab18'" 19 "`lab19'" 20 "`lab20'"
	label val bn_share_ge_elig_treat_ov_0to2km treatlab

	reg `v' ent_type#ib1.bn_share_ge_elig_treat_ov_0to2km ibn.ent_type 1.treat#ibn.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code) nocons

	** Here, we want the sum of the effect per household for each enterprise group, as these are additive variables **
	** Column 2: Rescale by number of enterprises in treatment villages / number of households in treatment villages -- this assumes all profits/revenues stay within the village **
	** Column 3: Rescale by number of enterprises in control villages / number of households in control villages -- this assumes all profits/revenues stay within the village **

	mata: coefmat = J(3,`n_bins',.)
	mata: st_numscalar("abc", atmat[1,2] - atmat[1,1])
	local xdiff = abc
	local linearity_test = "(2.ent_type#2.bn_share_ge_elig_treat_ov_0to2km * `n_ent_from_hh_tot' / `n_hh_tot' +  1.ent_type#2.bn_share_ge_elig_treat_ov_0to2km * `n_ent_outside_hh_tot' / `n_hh_tot'"

	if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
		local linearity_test = "`linearity_test'" + " + 3.ent_type#2.bn_share_ge_elig_treat_ov_0to2km * `n_ent_ownfarm_tot' / `n_hh_tot'"
	}

	local linearity_test = 	"`linearity_test'" + ") / `xdiff'"

	forval i = 2/`n_bins' {
		local ATEstring_spillover = "2.ent_type#`i'.bn_share_ge_elig_treat_ov_0to2km * `n_ent_from_hh_tot' / `n_hh_tot'"
		local ATEstring_spillover = "`ATEstring_spillover'" + "+" + " 1.ent_type#`i'.bn_share_ge_elig_treat_ov_0to2km * `n_ent_outside_hh_tot' / `n_hh_tot'"


		if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
			local ATEstring_spillover = "`ATEstring_spillover'" + "+" + " 3.ent_type#`i'.bn_share_ge_elig_treat_ov_0to2km * `n_ent_ownfarm_tot' / `n_hh_tot'"
		}

		disp "`ATEstring_spillover'"
		lincom "`ATEstring_spillover'"

		mata {
			coefmat[1,`i'] = st_numscalar("r(estimate)")
			coefmat[2,`i'] = st_numscalar("r(lb)")
			coefmat[3,`i'] = st_numscalar("r(ub)")
		}

		** build linearity test **
		if `i' > 2 {
			local i2 = `i'-1
			mata: st_numscalar("abc", atmat[1,`i'] - atmat[1,`i'-1])
			local xdiff = abc

			local linearity_test = "`linearity_test'" + " = ((2.ent_type#`i'.bn_share_ge_elig_treat_ov_0to2km - 2.ent_type#`i2'.bn_share_ge_elig_treat_ov_0to2km) * `n_ent_from_hh_tot' / `n_hh_tot' +  (1.ent_type#`i'.bn_share_ge_elig_treat_ov_0to2km - 1.ent_type#`i2'.bn_share_ge_elig_treat_ov_0to2km) * `n_ent_outside_hh_tot' / `n_hh_tot'"
			if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
				local linearity_test = "`linearity_test'" + " + (3.ent_type#`i'.bn_share_ge_elig_treat_ov_0to2km - 3.ent_type#`i2'.bn_share_ge_elig_treat_ov_0to2km) * `n_ent_ownfarm_tot' / `n_hh_tot'"
			}

			local linearity_test = 	"`linearity_test'" + ") / `xdiff'"
		}
	}

	disp "`linearity_test'"
	test "`linearity_test'"
	local lintest_p: di %3.2f `=round(r(p),0.01)'

	** get linear prediction **
	reg `v' ent_type#c.share_ge_elig_treat_ov_0to2km ibn.ent_type 1.treat#ibn.ent_type `vblvars' [aweight=entweight_EL], cluster(sublocation_code) nocons

	** get average slope **
	local avgslope = "2.ent_type#c.share_ge_elig_treat_ov_0to2km * `n_ent_from_hh_tot' / `n_hh_tot'"
	local avgslope = "`avgslope'" + "+" + " 1.ent_type#c.share_ge_elig_treat_ov_0to2km * `n_ent_outside_hh_tot' / `n_hh_tot'"

	if !inlist("`v'", "ent_inventory_wins_PPP", "ent_inv_wins_PPP") {  // we don't have this information for agricultural businesses
		local avgslope = "`avgslope'" + "+" + " 3.ent_type#c.share_ge_elig_treat_ov_0to2km * `n_ent_ownfarm_tot' / `n_hh_tot'"
	}

	disp "`avgslope'"
	lincom "`avgslope'"
	mata: slope = st_numscalar("r(estimate)")

	** prepare matrices **
	mata: linmat = J(1,`n_bins',.)
	mata: intercept = coefmat[1,1]
	forval i = 1/`n_bins' {
		mata: linmat[1,`i'] = (atmat[1,`i'] - atmat[1,1])*slope
	}

	mata {
		coefmat[1,1] = 0 //
		coefmat[2,1] = . //
		coefmat[3,1] = . //

		st_matrix("coefmat", coefmat)
		st_matrix("linmat", linmat)
		st_matrix("atmat", atmat)
	}

	** make graph **
	local thisvarlabel: variable label `v'

	coefplot (matrix(coefmat[1]), ci((coefmat[2] coefmat[3])) label("Non-linear coefficient estimates")) (matrix(linmat), recast(line) label("Linear specification")), at(matrix(atmat)) /*xlabel(0(0.2)1) xscale(range(0(0.2)1))*/ xtitle("Share of eligibles treated within 0 to 2km", margin(top)) ytitle("`thisvarlabel'") scheme(tufte) legend(off) /*legend(cols(2) size(small) bmargin(tiny))*/ name(gph_rev, replace) ///
	ylabel(-200(200)800) yscale(range(-200(200)800)) ///
	text(780 0.2 "p-value :  `lintest_p'", placement(se) just(left))
	*text(900 0.19 "H{sub:0}         :  effect is linear" "p-value :  `lintest_p'", placement(se) just(left))
}

graph combine gph_cons gph_rev, cols(2) xsize(8) ysize(5) scheme(tufte)
graph export "$dfig/FigureB1_LinearityCheck_ConsRev.pdf", replace
