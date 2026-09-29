/* This do file generates alternative spatial and temporal treatment allocations for market locations
 Author: Tilman Graff
 Date: 2019-10-31 */

 set seed 20191031

use "$da/pp_GDP_calculated.dta", clear
global pp_GDP = pp_GDP[1]
global pp_GDP_r = pp_GDP_r[1]
clear

cap program drop draw_alloc_markets
program define draw_alloc_markets
    syntax, outdir(string)

	quietly{

	tempfile using
	save `using'

	*********
	* Initialising
	*********
	use "$dr/CleanGeography_PUBLIC", clear

	keep if ge_village == 1

	keep location_code sublocation_code village_code subcounty
	merge 1:1 village_code using "$dr/GE_Treat_Status_Master.dta", keepusing(satlevel_name low_exposure_zone)

	keep if _m == 3
	drop _m

	encode satlevel_name, generate(satcluster)

	*encode location_code, generate(loc1)
	gen loc1 = location_code
	*encode sublocation_code, generate(subloc1)
	gen subloc1 = sublocation_code

	drop location_code sublocation_code satlevel_name
	ren loc1 location
	ren subloc1 sublocation


  gen subcounty_order = subcounty

  qui: summ subcounty_order if subcounty == 1 & low_exposure_zone == 0
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

  // adding seed for sorting
  randtreat, gen(vill_group) strata(strata) multiple(3) misfits(global) setseed($current_rep)

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
	preserve
	keep if subcounty == 1
	sort villrand

	gen order = _n
	qui sum order
	loc maxorder = `r(max)'
	tempfile siaya
	save `siaya'
	restore

	** Second Ugunja
	preserve
	keep if subcounty == 2
	sort locrand villrand
	gen order = _n + `maxorder'
	qui sum order
	loc maxorder = `r(max)'
	tempfile ugunja
	save `ugunja'
	restore

	** Third Ukwala
	keep if subcounty == 3
	sort locrand villrand
	gen order = _n + `maxorder'

	append using `siaya' `ugunja'
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
	merge 1:m village_code using "$da/market_buffers_hhs_ge.dta", keepusing(market_code distance hh_ge_eligible) nogen

	sort market_code distance village_code
	order market_code distance village_code

	*********
	* Monthly flows
	*********

	gen ri_tokenmonth = ri_treatmonth
	gen ri_ls1month = ri_treatmonth + 2
	gen ri_ls2month = ri_ls1month + 6

	qui summ ri_tokenmonth
	loc startmonth = `r(min)'
	loc endmonth = `r(max)' + 16

	forvalues m = `startmonth'/`endmonth'{
		gen ri_actamt_KES_m`m' = 0

		** Take into account average rollout across villages **
		matrix invillrollout = (0.615839493, 0.180042239, 0.060718057, 0.038648363, 0.034952482, 0.019852165, 0.02407603, 0.01467793, 0.011193242) // these are the share of HHs that get phased into treatment each month -- capped at 8 mohths

		forval i = 1/9 {
			qui replace ri_actamt_KES_m`m' = invillrollout[1,`i']*(ri_actamt_KES_m`m' + 7000 * hh_ge_eligible * ri_treat) if ri_tokenmonth == `m' + 1 - `i'
			qui replace ri_actamt_KES_m`m' = invillrollout[1,`i']*(ri_actamt_KES_m`m' + 40000 * hh_ge_eligible * ri_treat) if ri_ls1month == `m' + 1 - `i'
			qui replace ri_actamt_KES_m`m' = invillrollout[1,`i']*(ri_actamt_KES_m`m' + 40000 * hh_ge_eligible * ri_treat) if ri_ls2month == `m' + 1 - `i'
		}
	}

	egen ri_actamt_KES = rowtotal(ri_actamt_KES_m???)

	***********
	* Collapsing
	***********
	collapse (sum) *KES*, by(market_code distance)
	drop if distance > 20

	merge 1:1 market_code distance using "$da/market_radiipop_long.dta", keepusing(p_total) nogen

	*********
	* PP amounts
	*********
	forvalues m = `startmonth'/`endmonth'{
		gen ri_pp_amt_m`m' = ri_actamt_KES_m`m' / (p_total * $pp_GDP)
		drop ri_actamt_KES_m`m'
	}

	*********
	* Keep and reshape
	*********

	* first: reshape long for months
	drop ri_actamt_KES p_total
	reshape long ri_pp_amt_m, i(market_code distance) j(month)

	* second: reshape wide for radii
	gen diststring = "_" + string(distance-2) + "to" + string(distance) + "km"
	drop distance

	foreach var of varlist *_m{
		loc newname = subinstr("`var'", "_m", "", 1)
		ren `var' `newname'
	}

	reshape wide ri_pp_amt, i(market_code month) j(diststring) string

	order *, sequential
	order market_code, first

	gen market_id = market_code

	**********
	* Time series details
	**********
	tsset market_code month
	forvalues r = 2(2)20{
		loc r2 = `r' - 2
		tsegen ri_tcum_l2_pp_amt_`r2'to`r'km = rowtotal(L(0/2).ri_pp_amt_`r2'to`r'km)
	}

	**********
	* Transfers into growing radii
	**********

	forvalues r = 2(2)20{
		loc r2 = `r' - 2
		egen ri_cum_pp_amt_`r'km = rowtotal(ri_pp_amt_0to2km-ri_pp_amt_`r2'to`r'km)
	}

	save "`outdir'", replace
	use `using', clear
	}
end
