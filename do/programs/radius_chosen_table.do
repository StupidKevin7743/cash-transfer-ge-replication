** Table showing maximum radius selected by the BIC algorthim **


** Format of table:
** Treated
** (1) Total Effect (IV)
** (2) Total Effect (IV) -- low market access
** (3) Total Effect (IV)  -- high market access
** (4) - (6) by subcounty

** Untreated
** (7) Total Effect (IV)
** (8) Total Effect (IV) -- low market access
** (9) Total Effect (IV)  -- high market access
** (10) - (12) by subcounty


*This table is only used for household and individual level data *




************************************************************************************

cap program drop radius_chosen_table
program define radius_chosen_table
syntax using, outcomes(string)


* setting up directory for unformatted coefficients associated with tables
di `"Using: `using'"'
cap mkdir "${dtab}/coeftables"
local coeftable = subinstr(`"`using'"', `"${dtab}"', `"${dtab}/coeftables"', 1)
local coeftable = subinstr(`"`coeftable'"', ".tex", "_RawCoefs.xls", 1)

local outregopt "replace"
local outregset "excel label(proper)"

** SETTING UP TABLE BEFORE RUNNING SPECIFICATIONS

// Setting up blank table, 6 columns and as many rows as variables in `outcomes'
drop _all
local ncols = 12
local nrows = max(2,wordcount("`outcomes'"))

// Fill in table with dummy values, set up estimation storage under names col1-col6
eststo clear
quietly {
  est drop _all
  set obs `nrows'
  gen x = 1
  gen y = 1
  forvalues x = 1/`ncols' {
    eststo col`x': reg x y
  }
}

// Initialize counters, needed for "sub"-rows for each outcome variable
local varcount = 1
local count = 1
local countspace = `count' + 1

// Initialize labels, needed for what'll be written on the left side of table/organizing numbers within
local varlabels ""
local statnames ""
local collabels ""

// Set up empty matrix, 'array' of seven values
mata: output_table = .,.,.,.,.,.,.
// Tracking number of outcomes, initialize before entering loop
scalar numoutcomes = 0

// Looping through each variable in list `outcomes'
foreach v in `outcomes' {
  di "Loop for `v'"


  use "$da/GE_HHIndividualWageProfits_ECMA.dta", clear
  capture: confirm variable `v'
  if _rc == 0 {
    local source = "$da/GE_HHIndividualWageProfits_ECMA.dta"
  }

  use "$da/GE_HHLevel_ECMA.dta", clear
  capture: confirm variable `v'
  if _rc == 0 {
    local source = "$da/GE_HHLevel_ECMA.dta"
  }

  // Display name of .dta that contains variable v
  disp "`source' for `v'"


  if inlist("`source'", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
    local timvar = "survey_mth"
    local panvar = "persid"
  }

  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta")  {
    local timvar = "survey_mth"
    local panvar = "hhid"
  }

  // Load dataset that contains variable v
  use "`source'", clear

  // Label variables (program defined right before table_main_spillmechanism is called)
  ge_label_variables


  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
    gen weight = hhweight_EL
    gen ineligible = 1-eligible
    // Set quantity-based weight for price variables
    if "`v'" == "landprice_wins_PPP" {
      replace weight = weight * own_land_acres
    }
    if "`v'" == "lw_intrate_wins" {
      replace weight = weight * tot_loanamt_wins_PPP
    }
    if "`v'" == "emp_cshsal_perh_winP" {
      replace weight = weight * emp_hrs
    }
  }

  // Increase outcomes counter; started at 0, will now increase by 1 each time loop is passed through
  scalar numoutcomes = numoutcomes + 1


  // Adding variable label to the table (what appears in left of table); collabels will add on labels each loop iteration
  local add : var label `v'
  local collabels `"`collabels' "`add'""'

  if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
    gen sample = eligible
  }

  // Adding baseline variables - if they are in the dataset
  cap confirm variable `v'_BL M`v'_BL
  if _rc == 0 {
    local blvars "`v'_BL M`v'_BL"
    cap gen `v'_BL_e = eligible * `v'_BL
    cap gen M`v'_BL_e = eligible * M`v'_BL
    local blvars_untreat "`blvars' `v'_BL_e M`v'_BL_e"
  }
  else {
    local blvars ""
    local blvars_untreat ""
  }
  **adding in market_access variables**
  cap confirm variable market_access
  if _rc == 0 {
  }
  else {
    gen market_access = 0
    forval r = 2(2)10 {
      local r2 = `r' - 2
      replace market_access = market_access + (`r' - 0.5)^(-8) * p_total_`r2'to`r'km
    }

    xtile q4_market_access = market_access, n(4)
    xtile q2_market_access = market_access, n(2)
  }

  * adding subcounty variable *
  cap drop _merge
  project, original("$dr/GE_Treat_Status_Master.dta") preserve
  merge n:1 village_code using "$dr/GE_Treat_Status_Master.dta", keepusing(subcounty)
  drop if _merge == 1

  tab subcounty, m
  assert subcounty != ""


  ** Col 1: Full sample for treated households **
  ****************************************************************************************************************

     di "Starting optimal radii for full sample for treated households"

    calculate_optimal_radii `v' [aweight=hhweight_EL] if sample == 1, elig blvars("`blvars'")

      estadd local thisstat`count' = string(`r(r_max)') :col1

      di "Optimal radii for full sample: `r(r_max)'"
  		local r_full = `r(r_max)'


    return clear


  ** Col 2 and 3 : by market access **
  ****************************************************************************************************************
  di "Starting optimal radii by market access"

  forval nq = 1(1)2 {
    local clmn = `nq' + 1

    calculate_optimal_radii `v' [weight=hhweight_EL] if sample == 1 & q2_market_access == `nq', elig blvars("`blvars'")

    if `r_full' == `r(r_max)' {
      estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
    }
    else {
      estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
    }

    di "Optimal radii for `nq' access: `r(r_max)'"

    return clear
  }


  ** Col 4-6 : radii for the 3 subcounties, optr**
  ****************************************************************************************************************
  di "Starting optimal radii by subcounty"
  local clmn = 4
  foreach l in "SIAYA" "UGUNJA" "UKWALA" {

    calculate_optimal_radii `v'  [weight=hhweight_EL] if sample == 1 & subcounty=="`l'", elig blvars("`blvars'")

    if `r_full' == `r(r_max)' {
      estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
    }
    else {
      estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
    }

    di "Optimal radii for `l': `r(r_max)'"
    local ++clmn

      return clear

  }

  macro drop r_full

*************************************************************************
*               NON-RECIPIENT HOUSEHOLDS
*************************************************************************

  ** Col 7: total treamtment effect on untreated, optr**
  ****************************************************************************************************************
  di "Starting optimal radii for full sample non-recipients"

  calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'")

    estadd local thisstat`count' = string(`r(r_max)') : col7

    di "Optimal radii for full sample non-recipients: `r(r_max)'"
    local r_full = `r(r_max)'



  ** Col 8 & 9: total treamtment effect on untreated,low and high market access  optr**
  ****************************************************************************************************************
  forval nq = 1(1)2 {
    local clmn = `nq' + 7

    calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0) & q2_market_access == `nq', hhnonrec  blvars("`blvars_untreat'")

    if `r_full' == `r(r_max)' {
      estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
    }
    else {
      estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
    }

    di "Optimal radii for `nq' access: `r(r_max)'"

    return clear

    }


  ** Col 10-12: total treamtment effect on untreated, subcounties  optr**
  ****************************************************************************************************************
  local clmn = 10
  foreach l in "SIAYA" "UGUNJA" "UKWALA" {

    calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0) & subcounty == "`l'", hhnonrec  blvars("`blvars_untreat'")

    if `r_full' == `r(r_max)' {
      estadd local thisstat`count' = string(`r(r_max)'):col`clmn'
    }
    else {
      estadd local thisstat`count' = "\textbf{" + string(`r(r_max)') + "}" :col`clmn' // bolding those that don't match
    }

    di "Optimal radii for `l' non-recipients: `r(r_max)'"

    return clear

    loc ++clmn

    }



  local thisvarlabel: variable label `v'

  if numoutcomes == 1 {
      local varlabels `" " "`varlabels' "`thisvarlabel'" " " "'
      local statnames "thisstat`countspace' `statnames' thisstat`count' thisstat`countspace'"
    }
    else {
      local varlabels `"`varlabels' "`thisvarlabel'" "  " "'
      local statnames "`statnames' thisstat`count' thisstat`countspace'"
    }

    // Incrementing counters because next `v' coefficient will fall three lines under the preceding coefficient when thinking column wise
    local count = `count' + 2

    local countspace = `count' + 1


    local ++varcount

}
// END OF LOOP THROUGH OUTCOMES
di "End outcome loop"



local columns = 12

// Exporting tex table
if "`fulltable'" == "1" {
  loc prehead "\begin{table}[htbp]\centering \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \caption{$sumtitle} \label{tab:$sumpath} \maxsizebox*{\linewidth}{\textheight}{ \begin{threeparttable} \begin{tabular}{l*{`columns'}{S}} \toprule"
  loc postfoot "\bottomrule \end{tabular} \begin{tablenotes}[flushleft] \footnotesize \item \emph{Notes:} @note \end{tablenotes} \end{threeparttable} } \end{table}"
}
else {
  loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{`columns'}{c}} \toprule"
  loc postfoot "\bottomrule\end{tabular}}"
}

di "Exporting tex file"

** Exporting table going out to 2km **


esttab col1 col2 col3 col4 col5 col6 col7 col8 col9 col10 col11 col12 `using', cells(none) booktabs nonotes compress replace ///
mgroups("\textbf{Recipient Households}" "\textbf{Non-recipient Households}" , pattern(1 0 0 0 0 0 1 0 0 0 0 0 1) ///
prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
mtitle("\shortstack{Full Sample}" "\shortstack{low market access}" "\shortstack{high market access}" "\shortstack{Alego}" "\shortstack{Ugunja}" "\shortstack{Ukwala}" "\shortstack{Full Sample}" "\shortstack{low market \\ access}" "\shortstack{high market \\ access}" "Alego" "Ugunja" "Ukwala") ///
stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')



end
