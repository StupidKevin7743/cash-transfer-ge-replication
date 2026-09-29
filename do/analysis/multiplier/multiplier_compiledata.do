/*
 * Filename: multiplier_robustness_table.do
 * Description: This .do file takes raw outputs from bootstraps and creates final table
 * Author: Dennis Egger
 * Date created: 10 July 2019
 *
 */

/* Preliminaries */
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

** Import all IRFs **
foreach type in joint {
	disp "`type'"
	local files : dir "$dt/IRF_values/`type'/" files "*.txt"
	foreach file in `files' {
		local file = subinstr("`file'","withrarieda","withRarieda",.)
		local file = subinstr("`file'","irf","IRF",.)
		local i = `i' + 1
		clear
		project, uses("$dt/IRF_values/`type'/`file'")
		infile a using "$dt/IRF_values/`type'/`file'"
		keep if _n >= 12
		if substr("`file'",strpos("`file'","_IRF")-2,2) == "_r" {
			local name = substr("`file'",1,strpos("`file'","_IRF")-3)
			gen deflated = 1
		}
		else {
			local name = substr("`file'",1,strpos("`file'","_IRF")-1)
			gen deflated = 0
		}

		if substr("`file'",-18,14) == "_r_withRarieda" {
			gen withRarieda = 1
		}
		else {
			gen withRarieda = 0
		}

		ren a `name'
		gen quarter = _n
		gen type = "`type'"
		tempfile a`i'
		save `a`i'', replace
	}
}

foreach type in treated untreated {
	disp "`type'"
	local files : dir "$dt/IRF_values/`type'/" files "*.txt"
	foreach file in `files' {
		local file = subinstr("`file'","withrarieda","withRarieda",.)
		local file = subinstr("`file'","irf","IRF",.)
		local i = `i' + 1
		clear
		project, uses("$dt/IRF_values/`type'/`file'")
		infile a using "$dt/IRF_values/`type'/`file'"
		gen quarter = _n - 11 if inrange(_n,12,21)
		gen series = 1 if inrange(_n,12,21)
		replace quarter = _n - 22 if inrange(_n,23,32)
		replace series = 2 if inrange(_n,23,32)
		replace quarter = _n - 33 if inrange(_n,34,43)
		replace series = 3 if inrange(_n,34,43)
		drop if quarter == .
		reshape wide a, i(quarter) j(series)

		if substr("`file'",strpos("`file'","_IRF")-2,2) == "_r" {
			local name = substr("`file'",1,strpos("`file'","_IRF")-3)
			gen deflated = 1
		}
		else {
			local name = substr("`file'",1,strpos("`file'","_IRF")-1)
			gen deflated = 0
		}

		if substr("`file'",-18,14) == "_r_withRarieda" {
			gen withRarieda = 1
		}
		else {
			gen withRarieda = 0
		}

		ren a1 `name'
		ren a2 `name'_l
		ren a3 `name'_h
		gen type = "`type'"
		tempfile a`i'
		save `a`i'', replace
	}
}

disp "`i'"

** append all **
clear
insobs 12
gen quarter = _n
expand = 9
sort quarter
bys quarter: gen deflated = _n <= 6
bys quarter deflated: gen withRarieda = (_n <= 3 & deflated == 1)
bys quarter deflated withRarieda: gen type = "joint" if _n == 1
bys quarter deflated withRarieda: replace type = "untreated" if _n == 2
bys quarter deflated withRarieda: replace type = "treated" if _n == 3
sort deflated withRarieda type quarter
order deflated withRarieda type quarter

forval j = 1/`i' {
	merge 1:1 deflated withRarieda type quarter using `a`j'', update
	drop _merge
}

** Fill in Rarieda data that doesn't change **
tempfile temp
foreach def in 0 1 {
	foreach type in treated untreated joint {
		preserve
		keep if deflated == `def' & type == "`type'" & withRarieda == 0
		replace withRarieda = 1
		save `temp', replace
		restore
		merge 1:1 deflated withRarieda type quarter using `temp', update
		drop if _merge == 2
		drop _merge
	}
}

** Generate totals **

** stocks are summed up in total **
foreach v of var ent_inventory_wins totval_hhassets_h_wins {
	bys deflated withRarieda type: egen a = sum(`v')
	replace `v' = a if quarter == 11
	replace `v' = a if quarter == 12
	drop a
}

** flows are summed up only q4-10 **
foreach v of var ent_inv_wins ent_profit2_wins ent_rentcost_wins ent_totaltaxes_wins nondurables_exp_wins p3_3_wageearnings_wins {
	bys deflated withRarieda type: egen a = sum(`v')
	replace `v' = a if quarter == 11
	bys deflated withRarieda type: egen b = sum(`v') if inrange(quarter,4,10)
	bys deflated withRarieda type: egen c = mean(b)
	replace `v' = c if quarter == 12
	drop a b c
}

egen multiplier_exp = rowtotal(ent_inventory_wins ent_inv_wins nondurables_exp_wins totval_hhassets_h_wins)
egen multiplier_inc = rowtotal(ent_profit2_wins ent_rentcost_wins ent_totaltaxes_wins p3_3_wageearnings_wins)
order deflated withRarieda type quarter multiplier*

replace quarter = 99 if quarter == 11
replace quarter = 98 if quarter == 12

** Save **
save "$dt/multiplier_estimates.dta", replace
project, creates("$dt/multiplier_estimates.dta")
