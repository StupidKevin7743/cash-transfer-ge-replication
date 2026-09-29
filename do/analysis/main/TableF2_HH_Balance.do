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

project, original("$do/programs/run_ge_build_programs.do")
include "$do/programs/run_ge_build_programs.do"

** dataset dependencies **
project, original("$da/GE_HHLevel_ECMA.dta") preserve

/* Household Spatial Balance Results */
cap program drop ge_label_variables
program define ge_label_variables

	label var female_BL "\emph{Panel A: Respondent demographics} & & & & \\ Female"
	label var married_BL "Is married"
	label var haschildhh_BL "Has child"
	label var highpsych_BL "Above median psychological well-being index"
	label var emp_BL "Employed in wage work"
	label var p5_psych_index_BL "Psychological well-being index"
	label var p9_foodindex_BL "Food security index"
	cap	la var p1_assets_wins_PPP_BL "\emph{Panel B: Household assets}&&&&\\ Assets (non-land, non-house), net borrowing"
	cap la var h1_10_housevalue_wins_PPP_BL "Housing value"
	cap la var h1_11_landvalue_wins_PPP_BL "Land value"
	cap la var totincome_nonag_wins_PPP_BL "\emph{Panel C: Household cash flow}&&&& \\ Household non-ag income, annualized"
	cap la var p3_2_nonagprofit_wins_PPP_BL "Self-employment profits, annualized"
	cap la var p3_3_wageearnings_wins_PPP_BL "Wage earnings, annualized"
	cap la var tottaxpaid_all_wins_PPP_BL "Tax paid, annualized"
	cap la var landprice_wins_PPP_BL "\emph{Panel C: Input Prices} & & & & \\ Land price per acre"
 	cap la var own_land_acres_BL "Acres of land owned"
 	cap la var tot_loanamt_wins_PPP_BL "Total loan amount"
end

local demog_panel "female_BL age25up_BL married_BL stdschool_BL haschildhh_BL selfemp_BL emp_BL"
local tab1 "p1_assets_wins_PPP_BL h1_10_housevalue_wins_PPP_BL h1_11_landvalue_wins_PPP_BL totincome_nonag_wins_PPP_BL p3_2_nonagprofit_wins_PPP_BL p3_3_wageearnings_wins_PPP_BL tottaxpaid_all_wins_PPP_BL"
local tab2 "landprice_wins_PPP_BL  own_land_acres_BL tot_loanamt_wins_PPP_BL "

local outcomes "`demog_panel' `tab1' `tab2'"
local using "$dtab/TableF2_HH_Balance"


/** pulling from table_main program, but adjusting to ensure that:
	a) we drop any observations with missing baseline values for an outcome
	b) update to use baseline survey months -- to consider, should we be using baseline weights and lat/long as well? Or is endline more reprsentative here?
	c) since these are household outcomes, only using those components
**/

* setting up directory for unformatted coefficients associated with tables
di `"Using: `using'"'
	cap mkdir "${dtab}/coeftables"
	local coeftable = subinstr(`"`using'"', `"${dtab}"', `"${dtab}/coeftables"', 1)
	local coeftable = subinstr(`"`coeftable'"', ".tex", "_RawCoefs.xls", 1)
	local coeftable `"using "$dtab/coeftables/HHBaseline_SpatialPlacebo_RawCoefs.xls"'

	local outregopt "replace"
	local outregset "excel label(proper)"

	* setting up blank table *
	drop _all
	local ncols = 6
	local nrows = wordcount("`outcomes'")

	*** CREATE EMPTY TABLE ***
	eststo clear
	est drop _all
	set obs `nrows'
	gen x = 1
	gen y = 1

	forvalues x = 1/`ncols' {
		qui eststo col`x': reg x y
	}

	local varcount = 1
	local count = 1
	local countse = `count'+1
	local countspace = `count' + 2

	local varlabels ""
	local statnames ""
	local collabels ""


use "$da/GE_HHLevel_ECMA.dta", clear

if $runGPS == 1 {
	merge 1:1 hhid_key using $dr/GE_HH_GPS_Coordinates_RESTRICTED.dta, nogen
}

** Initial cleaning  **
gen survey_mth_BL = ym(year(svydate_BL), month(svydate_BL ))
gen totincome_nonag = p3_2_nonagprofit_PPP_BL + p3_3_wageearnings_PPP_BL if Mp3_2_nonagprofit_PPP_BL == 0 & Mp3_3_wageearnings_PPP_BL == 0
wins_top1 totincome_nonag
ren totincome_nonag* totincome_nonag*_PPP_BL

gen Mtotincome_nonag_wins_PPP_BL = (Mp3_2_nonagprofit_PPP_BL == 1 | Mp3_3_wageearnings_PPP_BL == 1)

gen ineligible = 1-eligible

local timvar = "survey_mth"
local panvar = "hhid"

cap gen cons = 1
forval rad = 2(2)20 {
	local r2 = `rad' - 2

	gen pp_actamt_`r2'to`rad'km_eligible = pp_actamt_`r2'to`rad'km * eligible
	gen pp_actamt_`r2'to`rad'km_ineligible = pp_actamt_`r2'to`rad'km * ineligible

	gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
	gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible
}



** Label variables **
ge_label_variables

gen weight = hhweight_EL

scalar numoutcomes = 0

/********************************************/
/*  STARTING LOOP OVER OUTCOMES 						*/
/********************************************/

foreach v of local outcomes {

replace `v' = . if M`v' == 1 // dropping any values that are missing at baseline and set to the mean

** adding variable label to the table **
local add : var label `v'
local collabels `"`collabels' "`add'""'

** 1 First column: Dummy regressions **
***************************************
cap drop sample
gen sample = eligible

reg `v' treat hi_sat [aweight=weight] if sample == 1, cluster(village_code)

outreg2 `coeftable', `outregopt' `outregset'
local outregopt "append"

** formatting for tex - column 1, indicator for treatment status **
pstar treat
estadd local thisstat`count' = "`r(bstar)'": col1
estadd local thisstat`countse' = "`r(sestar)'": col1


** Total treamtment effect on the treated (eligibles) from the 'optimal' spatial regression **
*****************************************************************************************************

calculate_optimal_radii `v' [aweight=weight] if sample == 1, elig blvars("`blvars'")

local r = r(r_max)

local endregs "pp_actamt_ownvill"
local exregs "treat"


forval rad = 2(2)`r' {
	local r2 = `rad' - 2
	local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
	local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
}

if $runGPS == 1 {
	iv_spatial_HAC `v' cons [aweight=weight] if sample == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
}
if $runGPS == 0 {
	ivreg2 `v' (`endregs' = `exregs') [aweight=weight] if sample == 1, cluster(sublocation_code)
}


outreg2 `coeftable', `outregopt' `outregset'
	eststo e_ive


** Get mean total effect on treated eligibles **
	local ATEstring_tot ""

	foreach vrb of local endregs {
				qui sum `vrb' [aweight=weight] if (sample == 1 & treat == 1)
				local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
	 }

disp "`ATEstring_tot'"
lincom "`ATEstring_tot'"

pstar, b(`r(estimate)') se(`r(se)')
estadd local thisstat`count' = "`r(bstar)'": col2
estadd local thisstat`countse' = "`r(sestar)'": col2



macro drop r r2

** Add spillover effects **
*******************************

** i. pooled spillover on ineligibles, and eligibles in control villages **
***************************************************************************
calculate_optimal_radii `v' [aweight=weight] if (eligible == 0 | treat == 0),  blvars("`blvars_untreat'") hhnonrec

local r = r(r_max)
local nonrec_r_full = `r'

di "full r for `v' for non-recipients is `r'"

local endregs = ""
local exregs = ""
local amount_list = ""

forval rad = 2(2)`r' {
	local r2 = `rad' - 2

	local endregs = "`endregs'" + " pp_actamt_`r2'to`rad'km_eligible" + " pp_actamt_`r2'to`rad'km_ineligible"
	local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`rad'km_el"  + " share_ge_elig_treat_`r2'to`rad'km_in"

	local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
	}

if $runGPS == 1 {
	iv_spatial_HAC `v' cons eligible [aweight=weight] if (eligible == 0 | treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
}
if $runGPS == 0 {
	ivreg2 `v' (`endregs' = `exregs') eligible [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
}

eststo e_ivie
outreg2 `coeftable', `outregopt' `outregset'

** Get mean total spillover effect on eligibles in control villages and ineligibles **
sum weight if (eligible == 1 & treat == 0)
local mean1 = r(sum)
sum weight if (eligible == 0)
local mean2 = r(sum)

local eligcontrolweight = `mean1' / (`mean1' + `mean2')
local ineligweight = `mean2' / (`mean1' + `mean2')

local ATEstring_spillover = "0"

*** FOR EXTENDED TABLE VERSION -- SEPARATE THIS OUT ***
local ATEstring_eligcontrol_spill = "0"
local ATEstring_inelig_spill = "0"

foreach vrb of local amount_list {
	sum `vrb' [weight=weight] if (eligible == 1 & treat == 0)
	local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`eligcontrolweight'" + "*`r(mean)'" + "*`vrb'_eligible"
	sum `vrb' [aweight=weight] if eligible == 0
	local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ineligweight'" + "*`r(mean)'" + "*`vrb'_ineligible"

	// Get mean total spillover effect on control eligibles
		local ATEstring_eligcontrol_spill = "`ATEstring_eligcontrol_spill'" + "+" + "`r(mean)'" + "*`vrb'_eligible"
	// Get mean total spillover effect on ineligibles
		sum `vrb' [aweight=weight] if eligible == 0
		local ATEstring_inelig_spill = "`ATEstring_inelig_spill'" + "+" + "`r(mean)'" + "*`vrb'_ineligible"

}

disp "`ATEstring_spillover'"
lincom "`ATEstring_spillover'"

pstar, b(`r(estimate)') se(`r(se)')
estadd local thisstat`count' = "`r(bstar)'": col3
estadd local thisstat`countse' = "`r(sestar)'": col3

** Adding as columns 5 & 6
disp "`ATEstring_eligcontrol_spill'"
lincom "`ATEstring_eligcontrol_spill'"

pstar, b(`r(estimate)') se(`r(se)')
estadd local thisstat`count' = "`r(bstar)'": col5
estadd local thisstat`countse' = "`r(sestar)'": col5

disp "`ATEstring_inelig_spill'"
lincom "`ATEstring_inelig_spill'"

pstar, b(`r(estimate)') se(`r(se)')
estadd local thisstat`count' = "`r(bstar)'": col6
estadd local thisstat`countse' = "`r(sestar)'": col6



** 4. Add mean of dependent variable **
****************************************
sum `v' [weight=weight] if treat == 0 & hi_sat == 0

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
// end loop through outcomes
di "End outcome loop"

** Exporting table **

** displaying locals for troubleshooting **
di "`statnames'"
di `"`varlabels'"'

	*** exporting tex table -- average effects ***

loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{6}{S}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

if $runGPS == 0 {
	local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
}


di "Exporting tex file"
esttab col1 col2 col3 col4 using "`using'.tex", cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Recipient Households}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Non-recipient Households}}} & \\   \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}"  "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ mean (SD)}}") ///
stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

project, creates("`using'.tex") preserve

/*
*** Extended version for referee response ***

loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{8}{S}}\toprule"
loc postfoot "\bottomrule\end{tabular}}"

di "Exporting tex file"
esttab col1 col2 col3  col5 col6 col4 using "`using'_Extended.tex", cells(none) booktabs extracols(3) nonotes compress replace ///
mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Recipient Households}}} & & \multicolumn{3}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Non-recipient Households}}} & \\   \cline{2-3}\cline{5-7} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}"  "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control eligibles}}" "\multicolumn{1}{c}{\shortstack{Ineligibles}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ mean (SD)}}") ///
stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')

project, creates("`using'_Extended.tex") preserve
*/
