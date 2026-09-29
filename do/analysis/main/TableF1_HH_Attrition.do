/*
 * Filename: TableF1_HH_Attrition.do
 * Description: This do file creates general attrition tables for the GE project.
 *    It focuses on whether or not households are part of the endline survey, the main
 *    round used for analysis across all different projects.
 *
 *
 * Author: Michael Walker
 * Last modified: 1 Apr 2019
 *
 */

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



/*** SETTING UP DATASETS  ***/

/* based on PAP, we include the following variables:
1. FR female
2. FR 25 & up
3. FR married
4. FR completed primary school
5. At least 1 child in hh
6. above median subjective well-being
7. self-employed
8. wage worker
*/

local demog_panel "female_BL age25up_BL married_BL stdschool_BL haschildhh_BL selfemp_BL emp_BL"

local outcome_panel "p1_assets_wins_PPP_BL_z p3_totincome_wins_PPP_BL_z p4_totrevenue_wins_PPP_BL_z p5_psych_index_BL p9_foodindex_BL" // p5_psych_index_BL bring in education, health status (how closely can we match this), baseline hours worked. Should have something for everything but p2 (expenditure), p8 (female empowerment)

loc BL_vector `demog_panel' `outcome_panel'

*** STARTING WITH BASELINE DATASET ***
/* Baseline datasets are currently dropping observations that were not surveyed at endline. Need to figure out how workflow will work for this- is it a separate dataset for attrition? So for now, things that are using baseline data and conditional on being surveyed at endline work fine, but those require households that were not surveyed at endline are not working */
project, original("$da/GE_HH-Survey-BL_Analysis_AllHHs.dta") preserve // eventually should be uses
use "$da/GE_HH-Survey-BL_Analysis_AllHHs.dta", clear

cap drop _merge

*** MERGING IN VARIABLES FROM ATTRITION DATASET ***
/* here, we want to keep all observations from attrition datset, even those that don't merge, as that is the "full sample" of everyone that we tried to survey as part of endline */
project, original("$da/GE_HH-Survey_Tracking_Attrition.dta") preserve
merge 1:1 hhid_key using "$da/GE_HH-Survey_Tracking_Attrition.dta", gen(_mergenew) // will need to make sure that keeping right stuff, but presumably will need all o fhtis for stuff to work right


la var treat "Treatment Village"
la var hi_sat "High Saturation Sublocation"

foreach var in p1_assets_wins_PPP_BL p3_totincome_wins_PPP_BL p4_totrevenue_wins_PPP_BL{
	summ `var'
	gen `var'_z = (`var' - `r(mean)')/`r(sd)'
}

label var p1_assets_wins_PPP_BL_z "Total non-land, non-home assets, net loans (z-scored)"
label var p3_totincome_wins_PPP_BL_z "Total household income in the last 12 months (z-scored)"
label var p4_totrevenue_wins_PPP_BL_z "Total business revenue in the last 12 months (z-scored)"
label var surveyed_rd2 "Surveyed at endline"
label var female_BL "Female"
label var married_BL "Is married"
label var haschildhh_BL "Has child"
label var highpsych_BL "Above median psychological well-being index"
label var emp_BL "Employed in wage work"
label var p5_psych_index_BL "Psychological well-being index"
label var p9_foodindex_BL "Food security index"





** generating versions for eligible and ineligible households **
preserve
tempfile dta_elig
keep if eligible == 1
save `dta_elig'

restore
tempfile dta_inelig
keep if eligible == 0
save `dta_inelig'


/************************************************/
/* REGRESSIONS - LOOPING THROUGH FOR ELIGIBLE
	& INELIGIBLE HOUSEHOLDS 					*/
/************************************************/


**** Create Empty Table to fill later
	local treat_pvallist ""
	local hisat_pvallist ""
	clear
	local ncols = 8
	local nrows = wordcount("`BL_vector'")

	*** CREATE EMPTY TABLE ***
		*eststo clear
		*est drop _all
		set obs `nrows'
		gen x = 1
		gen y = 1

		forvalues x = 1/`ncols' {
			eststo col`x': qui reg x y
		}
*****


loc col = 101

foreach type in elig inelig {

	if "`type'" == "elig" loc fullname "eligible"
	if "`type'" == "inelig" loc fullname "ineligible"

	di "Loop for `fullname' households"


		use `dta_`type'', clear


	/*** TRACKING TABLE ***/

	loc j = 1


	* looping through panels
	foreach cond in "" "if surveyed_rd2 == 1" "if surveyed_rd1 == 1" {
		loc i = 1
		* looping through columns
		foreach var of varlist surveyed_rd2 surveyed_rd1 surveyed_both {

			di "Storing `var', `cond' as e`j'_`i'"
		eststo `type'`j'_`i': reg `var' treat hi_sat `cond', cluster(village_code)

		if ("`var'" == "surveyed_rd2" & "`cond'" == "if surveyed_rd2 == 1") | ("`var'" == "surveyed_rd1" & "`cond'" == "if surveyed_rd1 == 1") {
			di "No regression coefficients"
			estadd loc b_treat = ""
			estadd loc b_hi_sat = ""
			estadd loc c_mean = ""
		}
		else {
			pstar treat, prec(3)
			estadd local b_treat = "`r(bstar)'"
			estadd local se_treat = "`r(sestar)'"

			pstar hi_sat, prec(3)
			estadd local b_hisat = "`r(bstar)'"
			estadd local se_hisat = "`r(sestar)'"


			summ `var' if e(sample) == 1 & treat == 0 & hi_sat == 0
			estadd loc c_mean 	= string(`r(mean)', "%6.3fc")
			estadd loc c_sd 	= "(" + string(`r(sd)', "%6.3fc") + ")"
			estadd loc obsN = "\multicolumn{1}{c}{" + string(`e(N)', "%6.0fc") + "}"
		}
		local ++i
		}
		// end of variable loop
		local ++j
	}
	// end of sample loop
}

	*** SETTING UP TABLE ***

	loc path "$dtab/TableF1_HH_Attrition.tex"

	texdoc init "`path'", replace force

	loc columns = 4 // 5 once bringing initially-sampled back in
	loc collab ""
	forval i = 1 / `columns' {
		loc collab "`collab' & \multicolumn{1}{c}{(`i')}"
	}
	loc blankline ""
	forval i = 0 / `columns' {
		loc blankline " & "
	}
	loc blankline "`blankline' \\"

	glo sumpath "hh-attrition"
	glo sumtitle "Household tracking and attrition"

	loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{`columns'}{S}} \toprule"


	texdoc write `prehead'
	texdoc write `collab' \\
	texdoc write & \multicolumn{2}{c}{\textbf{Eligible}} &  \multicolumn{2}{c}{\textbf{Ineligible}} \\ \cline{2-3} \cline{4-5}
	texdoc write & \multicolumn{1}{c}{\shortstack{Surveyed at \\ endline}} & \multicolumn{1}{c}{\shortstack{Surveyed at baseline \\  and endline}} & \multicolumn{1}{c}{\shortstack{Surveyed at \\ endline}} & \multicolumn{1}{c}{\shortstack{Surveyed at baseline \\  and endline}} \\ \hline

		** Panel A: All households **
	texdoc write \multicolumn{`columns'}{l}{\emph{Panel A: All households targeted at endline}} & \\


	esttab elig1_1 elig1_3 inelig1_1 inelig1_3 using "`path'", frag append label cells(none) ///
		stats(b_treat se_treat b_hisat se_hisat c_mean c_sd obsN, labels("Treatment Village" " " "High Saturation Sublocation" " " "Control, Low Sat Mean (SD)" " " "Observations")) ///
		nomtitles nonumbers star(* 0.10 ** 0.05 *** 0.01) ///
		 nolines noobs

	** Panel B: Households surveyed at endline (main analysis sample) **
	texdoc write `blankline'
	texdoc write \multicolumn{`columns'}{l}{\emph{Panel B: Among households surveyed at endline}} & \\


	esttab elig2_1 elig2_3 inelig2_1 inelig2_3  using "`path'", frag append label cells(none) ///
		stats(b_treat se_treat b_hisat se_hisat c_mean c_sd obsN, labels("Treatment Village" " " "High Saturation Sublocation" " " "Control, Low Sat Mean (SD)" " " "Observations")) ///
		nomtitles nonumbers star(* 0.10 ** 0.05 *** 0.01) ///
		 nolines noobs


	** Panel C: households surveyed at baseline **
	texdoc write `blankline'
	texdoc write \multicolumn{`columns'}{l}{\emph{Panel C: Among households surveyed at baseline}} & \\


	esttab elig3_1 elig3_3 inelig3_1 inelig3_3  using "`path'", frag append label cells(none) ///
		stats(b_treat se_treat b_hisat se_hisat c_mean c_sd obsN, labels("Treatment Village" " " "High Saturation Sublocation" " " "Control, Low Sat Mean (SD)" " " "Observations")) ///
		nomtitles nonumbers star(* 0.10 ** 0.05 *** 0.01) ///
		 nolines


	loc postfoot "\bottomrule \end{tabular}}"


	texdoc write `postfoot'
	texdoc close

	project, creates("$dtab/TableF1_HH_Attrition.tex")
