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

project, original("$do/analysis/prep/prep_VillageLevel.do") preserve
include "$do/analysis/prep/prep_VillageLevel.do"

**************************
**** RUN ENDLINE TABLE ***
**************************
local panvar "run_id"
local timvar "date"


local outcomes ent_profit2_wins_PPP ent_revenue2_wins_PPP ent_totcost_wins_PPP ent_wagebill_wins_PPP ent_profitmargin2_wins ent_inventory_wins_PPP ent_inv_wins_PPP n_allents

* for raw coefficient tables
local outregopt "replace"
local outregset "excel label(proper)"


* setting up blank table *
drop _all
local ncols = 12
local nrows = max(2,wordcount("`outcomes'"))

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

local varcount = 1
local count = 1
local countspace = `count' + 1


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
		gen date = run_id // creating a pseudo-panel of depth one

		cap la var n_allents "\emph{Panel C: Village-level} & & & & \\ Number of enterprises"
		cap la var n_operates_from_hh "Number of enterprises, operated from hh"
		cap la var n_operates_outside_hh "Number of enterprises, operated outside hh"
		cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
		cap la var n_ent_eligibletreat "Number of enterprises, owned by treated households"
		cap la var n_ent_ineligible "Number of enterprises, owned by untreated households"

		cap drop _merge
		merge 1:1 village_code using `temphh'
		drop _merge

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

		* adding in market access variables *
		cap confirm variable market_access
		if _rc != 0 {
			gen market_access = 0
			forval r = 2(2)10 {
				local r2 = `r' - 2
				replace market_access = market_access + (`r' - 0.5)^(-8) * p_total_`r2'to`r'km
			}

			xtile q4_market_access = market_access, n(4)
			xtile q2_market_access = market_access, n(2)
		}

		* adding subcounty variable *
		cap drop subcounty

		project, original("$dr/GE_Treat_Status_Master.dta") preserve
		merge 1:1 village_code using "$dr/GE_Treat_Status_Master.dta", keepusing(subcounty)

		drop if _merge == 2
		drop _merge

		tab subcounty
		assert subcounty != ""

		** Identify radii for overall sample **
		***************************************
		di "Starting optimal radii for full sample"
		calculate_optimal_radii phh_`v' [aweight=n_hh], vill blvars("`blvars'")

		estadd local thisstat`count' = string(`r(r_max)') :col1

		di "Optimal radii for full sample: `r(r_max)'"

		local r_full = `r(r_max)'

		return clear

		********************* ATE for low and high market access *************************
			di "Starting optimal radii by market access"

		forval nq = 1(1)2 {
			local clmn = `nq' + 1

			calculate_optimal_radii phh_`v' [aweight=n_hh] if q2_market_access==`nq', vill blvars("`blvars'")

			if `r_full' == `r(r_max)' {
	      estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
	    }
	    else {
	      estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
	    }

			di "Optimal radii for `nq' access: `r(r_max)'"

			return clear

		}

		********************* ATE for subcounties *************************
		di "Starting optimal radii by subcounty"
		local clmn = 4
		foreach l in "SIAYA" "UGUNJA" "UKWALA" {

			calculate_optimal_radii phh_`v' [aweight=n_hh] if subcounty=="`l'", vill blvars("`blvars'")

			if `r_full' == `r(r_max)' {
				estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
			}
			else {
				estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
			}

			di "Optimal radii for `l': `r(r_max)'"
			local ++clmn

		}

		** looping variables for tex table **
		local thisvarlabel: variable label `v'

		if numoutcomes == 1 {
			local varlabels `" " "`varlabels' "`thisvarlabel'"  " " "'
			local statnames "thisstat`countspace' `statnames' thisstat`count'  thisstat`countspace'"
		}
		else {
			local varlabels `"`varlabels' "`thisvarlabel'" " " "'
			local statnames "`statnames' thisstat`count'  thisstat`countspace'"
		}

		local count = `count' + 2

		local countspace = `count' + 1


		local ++varcount
	}
	******else********
	else {
		project, original("$da/GE_Enterprise_ECMA.dta") preserve
		use "$da/GE_Enterprise_ECMA.dta", clear
		gen run_id = _n

		cap la var ent_profit2_wins_PPP "\emph{Panel A: All enterprises} & & & & \\ Enterprise profits, annualized"
		cap la var ent_profitmargin2_wins "Enterprise profit margin"
		cap la var ent_revenue2_wins_PPP "Enterprise revenue, annualized"
		cap la var ent_totcost_wins_PPP "Enterprise costs, annualized"
		cap la var ent_wagebill_wins_PPP "\hspace{1em}Enterprise wagebill, annualized"
		cap la var ent_inventory_wins_PPP "\emph{Panel B: Non-agricultural enterprises} & & & & \\ Enterprise inventory"
		cap la var ent_inv_wins_PPP "Enterprise investment, annualized"
		cap la var ent_cust_perhour "Customers per hour business is open"
		cap la var ent_rev_perhour "Revenue per hour business is open"

		** adding village-level baseline variables - if they are in the dataset **
		cap desc `v'_vBL M`v'_vBL
		if _rc == 0 {
			local vblvars "c.`v'_vBL#ent_type M`v'_vBL#ent_type"
		}
		else {
			local vblvars ""
		}

		* adding in market access variables *
		cap confirm variable market_access
		if _rc != 0 {
			gen market_access = 0
			forval r = 2(2)10 {
				local r2 = `r' - 2
				replace market_access = market_access + (`r' - 0.5)^(-8) * p_total_`r2'to`r'km
			}

			xtile q4_market_access = market_access, n(4)
			xtile q2_market_access = market_access, n(2)
		}


		* adding subcounty variable *
		cap drop subcounty
		merge n:1 village_code using "$dr/GE_Treat_Status_Master.dta", keepusing(subcounty)
		drop if _merge == 2
		drop _merge

		tab subcounty
		assert subcounty != ""


		if "`v'" == "ent_profitmargin2_wins" {
			** Here, we want to get the effect on the profit margin for the average enterprise (weighted by revenue) **
			** Get revenue weights for each group **
			gen entweight = entweight_EL * ent_revenue2_wins_PPP
		}
		else {
			gen entweight = entweight_EL
		}

		** FULL SAMPLE **
		**********************************
		di "Starting optimal radii for full sample"

		calculate_optimal_radii `v' [aweight=entweight], ent blvars("`vblvars'")

		di "Optimal radii for full sample: `r(r_max)'"

		estadd local thisstat`count' = string(`r(r_max)'):col1

		local r_full = `r(r_max)'

		return clear

		***** Total Effect for low / high market access ************
		***************************************************************************************
		di "Starting optimal radii by market access"

		forval nq = 1(1)2 {
			local clmn = `nq' + 1

			calculate_optimal_radii `v' [aweight=entweight] if q2_market_access == `nq', ent blvars("`vblvars'")

			if `r_full' == `r(r_max)' {
				estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
			}
			else {
				estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
			}

			di "Optimal radii for market acces `nq': `r(r_max)'"

			return clear

		}


		***** Total Effect for subcounty ************
		***************************************************************************************
		di "Starting optimal radii by subcounty"
		local clmn = 4
		foreach l in "SIAYA" "UGUNJA" "UKWALA" {

			calculate_optimal_radii `v' [aweight=entweight] if subcounty == "`l'", ent blvars("`vblvars'")

			if `r_full' == `r(r_max)' {
	      estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
	    }
	    else {
	      estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
	    }

			di "Optimal radii for `l': `r(r_max)'"

			local ++clmn
		}


		** looping variables for tex table **
		local thisvarlabel: variable label `v'

		if numoutcomes == 1 {
			local varlabels `" " "`varlabels' "`thisvarlabel'" "  " "'
			local statnames "thisstat`countspace' `statnames' thisstat`count'  thisstat`countspace'"
		}
		else {
			local varlabels `"`varlabels' "`thisvarlabel'"  " " "'
			local statnames "`statnames' thisstat`count'  thisstat`countspace'"
		}

		local count = `count' + 2

		local countspace = `count' + 1

		local ++varcount
	}
}


	** end loop through outcomes
	di "End outcome loop"

	local columns = 6

	** exporting tex table ***
	loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{`columns'}{c}}\toprule"
	loc postfoot "\bottomrule\end{tabular}}"

	di "Exporting tex file"
	esttab col1 col2 col3 col4 col5 col6  using "$dtab/TableI9_EntOutcomes_MaxRadius.tex", cells(none) booktabs nonotes compress replace ///
	mgroups("\textbf{Market Access}" "\textbf{Subcounty}", pattern(0 1 0 1 0 0) ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
	mtitle("\shortstack{Full Sample}" "\shortstack{low market \\ access}" "\shortstack{high market \\ access}" "\shortstack{Alego}" "\shortstack{Ugunja}" "\shortstack{Ukwala}" ) ///
	stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')

	//mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Treatment Villages}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Control Villages}}} & \\   \cline{2-3}\cline{5-5} \\ " "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect: max rad 2km \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect max rad 2km \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ weighted mean (SD)}}") ///
	project, creates("$dtab/TableI9_EntOutcomes_MaxRadius.tex")
