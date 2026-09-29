/*
This do file generates alternative spatial and temporal treatment allocations
 Author: Tilman Graff
 Created: 2019-10-31 */

 set seed 20191031

use "$da/pp_GDP_calculated.dta", clear
global pp_GDP = pp_GDP[1]
global pp_GDP_r = pp_GDP_r[1]
clear

cap program drop draw_alloc
program define draw_alloc
    syntax, [monthly(integer 0)] outdir(string) rep(integer)

	//quietly{

	tempfile using
	save `using'

	*********
	* Initialising
	*********

	use "$dr/CleanGeography_PUBLIC", clear

	keep if ge_village == 1

	keep location_code sublocation_code village_code subcounty
	merge 1:1 village_code using "$dr/GE_Treat_Status_Master.dta", keepusing(satlevel_name low_exposure_zone) gen(_m)

	keep if _m == 3
	drop _m

	encode satlevel_name, generate(satcluster)
	gen loc1 = location_code
	gen subloc1 = sublocation_code

	drop location_code sublocation_code satlevel_name
	ren loc1 location
	ren subloc1 sublocation

  gen subcounty_order = subcounty

  qui: summ subcounty_order if subcounty == 1 & low_exposure_zone == 0 // Alego
  local alego_0_count = r(N)
  qui: summ subcounty_order if subcounty == 1 & low_exposure_zone == 1
  local alego_1_count = r(N)

  qui: summ subcounty_order if subcounty != 1
  local ug_uk_count = r(N)

	*********
	* Generate pseudo treatment assignment
	*********
	tempfile vill_treat
	save `vill_treat'


	**** First, randomise saturation areas
  bys satcluster: gen village_tally = _N
	keep satcluster village_tally low_exposure_zone subcounty subcounty_order
	bys satcluster: keep if _n == 1

  sort satcluster
	gen rand = uniform()

  ** Alego saturation assignment **
  bysort subcounty_order low_exposure_zone (rand): egen cum_vill = sum(village_tally) if subcounty == 1
  by subcounty_order low_exposure_zone (rand): gen siaya_rank = _n if subcounty == 1
  gen diff_from_even      = cum_vill - (`alego_0_count' / 2) if low_exposure_zone == 0
  replace diff_from_even  = cum_vill - (`alego_1_count' / 2) if low_exposure_zone == 1

  summ diff_from_even if diff_from_even > 0 & low_exposure_zone == 0
  summ siaya_rank if (diff_from_even == `r(min)') & low_exposure_zone == 0
  loc cutoff0 = r(mean)

  summ diff_from_even if diff_from_even > 0 & low_exposure_zone == 1
  summ siaya_rank if (diff_from_even == `r(min)') & low_exposure_zone == 1
  loc cutoff1 = r(mean)

	gen hi_sat_ri = (siaya_rank >= `cutoff0') if subcounty == 1 & low_exposure_zone == 0
  replace hi_sat_ri = (siaya_rank >= `cutoff1') if subcounty == 1 & low_exposure_zone == 1

    macro drop cutoff0 cutoff1

  ** Ugunja & Ukwala saturation assignment **
  drop cum_vill diff_from_even

  gen rand_group = 2 if subcounty == 1 // just need these coming after for counts to work right
  replace  rand_group = 1 if subcounty != 1

  bys rand_group (rand): egen cum_vill = sum(village_tally) if subcounty != 1
  by rand_group (rand): gen ug_uk_rank = _n if subcounty != 1
  gen diff_from_even = cum_vill - (`ug_uk_count' / 2)
  summ diff_from_even if diff_from_even > 0
  summ ug_uk_rank if diff_from_even == `r(min)'
  loc cutoff = `r(mean)'

  replace hi_sat_ri = 1 if ug_uk_rank <= `cutoff' & subcounty != 1
  replace hi_sat_ri = 0 if ug_uk_rank > `cutoff' & ~mi(ug_uk_rank) & subcounty != 1

    tab hi_sat_ri
    bys hi_sat_ri: egen tot_vill = total(village_tally)
    by hi_sat_ri: summ tot_vill
    assert hi_sat_ri != .

  drop rand diff_from_even cum_vill tot_vill siaya_rank ug_uk_rank


	**** Then, randomise treatment status
	merge 1:m satcluster using `vill_treat', nogen

  sort village_code
	gen rand = uniform()

  egen strata = group(satcluster)

  randtreat, gen(vill_group) strata(strata) multiple(3) misfits(global) setseed(`rep')

  tab vill_group

	gen ri_treat = 0 if vill_group == 0 // group 0 -- always control
  replace ri_treat = 1 if vill_group == 2 // group 2 -- always treat
  replace ri_treat = 0 if vill_group == 1 & hi_sat_ri == 0 // group 1 - treat in hi sat, control in low sat
  replace ri_treat = 1 if vill_group == 1 & hi_sat_ri == 1

  tab ri_treat
  tab hi_sat_ri ri_treat

	preserve
	keep village_code ri_treat
	tempfile ri_treat
	save `ri_treat'
	restore


	*********
	* Generate pseudo treatment time schedule
	*********
  sort village_code
	gen villrand = uniform()
	bys location: gen locrand = villrand[1]
	bys sublocation: gen sublocrand = villrand[1]

	** First Alego
	sort subcounty_order villrand

	gen order = _n if subcounty == 1
	qui sum order
	loc maxorder = `r(max)'

	** Second Ugunja & Ukwala
	sort subcounty_order locrand villrand
	replace order = _n + `maxorder' if subcounty != 1

  assert ~mi(order)
  assert ~mi(ri_treat)

  gen xtreat = 1 - ri_treat

	sort xtreat order
	gen treatorder = _n if ri_treat == 1

	sort order
	drop *rand* xtreat

	**** Assign months
	gen treatmonthrel = floor(treatorder / 28.5) // GD did about 28.5 treated villages per month

	gen ri_treatmonth = tm(2014m09) + treatmonthrel
	format ri_treatmonth %tm

	keep village_code ri_*

	*********
	* Merge over to spatial side
	*********
  project, original("$da/village_buffers_hhs_ge.dta") preserve
	merge 1:m village_code using "$da/village_buffers_hhs_ge.dta", nogen

	sort treatvill_code distance village_code
	order treatvill_code distance village_code


	*********
	* Create RI equivalent of various treatment data
	*********
	gen ri_hh_ge_eligible_treat = hh_ge_eligible * ri_treat
	gen ri_hh_ge_eligible_treat_ov = hh_ge_eligible_ov * ri_treat
	gen ri_hh_ge_eligible_treat_ownvill = hh_ge_eligible_ownvill * ri_treat
	gen ri_hh_ge_treat = hh_ge * ri_treat
	gen ri_hh_ge_treat_ownvill = hh_ge_ownvill * ri_treat
	gen ri_hh_ge_treat_ov = hh_ge_ov * ri_treat

	*********
	* Monthly flows
	*********
	if `monthly' == 1{

		gen ri_tokenmonth = ri_treatmonth
		gen ri_ls1month = ri_treatmonth + 2
		gen ri_ls2month = ri_ls1month + 6

		qui summ ri_tokenmonth
		loc startmonth = `r(min)'
		loc endmonth = `r(max)' + 16


		foreach vil in "" "_ownvill" "_ov"{

			forvalues m = `startmonth'/`endmonth'{
				gen double ri_actamt_KES`vil'_m`m' = 0

				** Take into account average rollout across villages **
				matrix invillrollout = (0.615839493, 0.180042239, 0.060718057, 0.038648363, 0.034952482, 0.019852165, 0.02407603, 0.01467793, 0.011193242) // these are the share of HHs that get phased into treatment each month -- capped at 8 mohths

				forval i = 1/9 {
					replace ri_actamt_KES`vil'_m`m' = invillrollout[1,`i']*(ri_actamt_KES`vil'_m`m' + 7000 * ri_hh_ge_eligible_treat`vil') if ri_tokenmonth == `m' + 1 - `i'
					replace ri_actamt_KES`vil'_m`m' = invillrollout[1,`i']*(ri_actamt_KES`vil'_m`m' + 40000 * ri_hh_ge_eligible_treat`vil') if ri_ls1month == `m' + 1 - `i'
					replace ri_actamt_KES`vil'_m`m' = invillrollout[1,`i']*(ri_actamt_KES`vil'_m`m' + 40000 * ri_hh_ge_eligible_treat`vil') if ri_ls2month == `m' + 1 - `i'
				}
			}
			***egen ri_actamt_KES`vil' = rowtotal(ri_actamt_KES`vil'_?*)
		}
	}

	foreach vil in "" "_ownvill" "_ov"{
		gen double ri_actamt_KES`vil' = 87000 * ri_hh_ge_eligible_treat`vil'
	}

	*********
	* Adding in other sources and collapsing
	*********
	tempfile ri_buffers
	save `ri_buffers'

  project, original("$da/village_buffers_hhs_gd.dta") preserve
	use "$da/village_buffers_hhs_gd.dta", clear
	merge m:1 village_code using "$dr/CleanGeography_PUBLIC.dta"
	drop if _merge == 2 // these are villages where we do not have gd data
	keep if gd == 1 // we only want to use the gd data where we do not have data from ge
	drop _merge

	merge 1:1 treatvill_code distance village_code using `ri_buffers' // none should merge
	tab ge gd if _merge == 1
	drop _merge

	***********
			collapse (sum) hh_gd p_gd hh_ge* p_ge* ri_*, by(treatvill_code distance)
	***********

	drop if distance > 20
	tempfile radiipop
	save `radiipop'

  project, original("$da/village_buffers_hhs_census.dta") preserve
	use "$da/village_buffers_hhs_census.dta", clear
	drop if distance > 20

	merge 1:1 treatvill_code distance using `radiipop'
	replace hh_census = 0 if _merge == 2 // these are radii which have no census households in them
	replace p_census = 0 if _merge == 2 // these are radii which have no census households in them

	drop _merge
	sort treatvill_code distance

	foreach v of var hh_* p_* {
		replace `v' = 0 if `v' == .
	}

  di "Generating totals"
	egen hh_total = rowtotal(hh_census hh_gd hh_ge)
	egen hh_total_ov = rowtotal(hh_census hh_gd hh_ge_ov)
	egen hh_total_ownvill = rowtotal(hh_ge_ownvill)

	di "Generating populations"
  egen p_total = rowtotal(p_census p_gd p_ge)
	egen p_total_ov = rowtotal(p_census p_gd p_ge_ov)
	egen p_total_ownvill = rowtotal(p_ge_ownvill)


	*********
	* PP amounts
	*********
  di "Generating PP amounts"

  desc ri_actamt_KES* p_total*, full

	foreach vil in "" "_ownvill" "_ov" {
		gen ri_pp_actamt_KES`vil'  = ri_actamt_KES`vil' / p_total`vil'
		replace ri_pp_actamt_KES`vil' = 0 if ri_pp_actamt_KES`vil' == .
	}

	if `monthly' == 1 {

		foreach vil in "" "_ownvill" "_ov" {
			forvalues m = `startmonth'/`endmonth' {
				gen ri_pp_actamt_KES`vil'_m`m'  = ri_actamt_KES`vil'_m`m' / p_total`vil'
				replace ri_pp_actamt_KES`vil'_m`m' = 0 if ri_pp_actamt_KES`vil'_m`m' == .
			}
		}

	}

	foreach var of varlist ri_pp_actamt_KES* {
		loc newstring = subinstr("`var'", "_KES", "", 1)
		gen `newstring' = `var'  / ($pp_GDP)
	}

	*********
	* Share eligible who got treated
	*********
  di "Generating share of eligibls treated"

	foreach vil in "" "_ov"{
		gen ri_share_ge_elig_treat`vil' = ri_hh_ge_eligible_treat`vil' / hh_ge_eligible`vil'
	}


	*********
	* rename monthly vars to comply with Stata's stupid varname length rule
	*********

	if `monthly' == 1 {
		foreach var of varlist ri_pp_actamt*_m?*{
			loc newstring = subinstr("`var'", "pp_actamt", "pac", 1)
			clonevar `newstring' = `var'
			drop `var'
		}
	}


	*********
	* Keep and reshape
	*********
	di "Keeping and reshaping"

	if `monthly' == 1 loc monthstring "ri_pac*"
	keep treatvill_code distance ri_pp_act* ri_share_ge* `monthstring'
	drop *_KES*

	gen diststring = "_" + string(distance-2) + "to" + string(distance) + "km"
	drop distance

	ren treatvill_code village_code

	ren ri_share_ge_elig_treat ri_share_treat
	ren ri_share_ge_elig_treat_ov ri_share_treat_ov

	reshape wide ri_pp_actamt* `monthstring' ri_share_treat ri_share_treat_ov, i(village_code) j(diststring) string

	egen ri_pp_actamt_ownvill = rowtotal(ri_pp_actamt_ownvill*)
	drop ri_pp_actamt_ownvill?*

	order *, sequential
	order village_code, first

	merge 1:1 village_code using `ri_treat', keepusing(ri_treat) nogen

	save "`outdir'", replace
	use `using', clear

end
