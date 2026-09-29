** Defining program to build table of coefficients for the main table for appendix  **

** Format of table:
	** Col(1): Dummy regression (treat)
	** Col(2): coef for own village (IV)
 	** Col (3): coef for 0-2km radii (IV)
	** Col (4): (as needed) coef for 2-4km radii
	** Col(5): coef for eligible*0-2km
	** Col(6): coef for ineligible*0-2km
	** Col(7): coef for eligible*2-4km
	** Col(8): coef for ineligible*2-4km
	** Col(9): Control, low sat mean


** below table: X_bar for each different group

************************************************************************************

cap program drop table_main_coef
program define table_main_coef
    syntax using, outcomes(string) [FDR(integer 0)] [firststage(integer 0) FULLtable(str)]

** SETTING UP TABLE BEFORE RUNNING SPECIFICATIONS

// Setting up blank table, 9 columns and as many rows as variables in `outcomes'
	drop _all
	local ncols = 9
	local nrows = max(2,wordcount("`outcomes'"))

// Fill in table with dummy values, set up estimation storage under names col1-col6
	eststo clear
	est drop _all
	set obs `nrows'
	gen x = 1
	gen y = 1
  quietly {
		forvalues x = 1/`ncols' {
			eststo col`x': reg x y
		}
	}


// Initialize counters, needed for "sub"-rows for each outcome variable
	local varcount = 1
	local count = 1
	local countse = `count' + 1
	local countspace = `count' + 2

	local r_table_treat = 2 // max radii band for any outcome in the treated table
	local r_table_untreat = 2 // same but for untreated households

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


// Find source for variable v; if return code _rc == 0, means variable v is found in that .dta, then set source as that .dta
		use "$da/GE_VillageLevel_ECMA.dta", clear
		capture: confirm variable `v'
		if _rc == 0 {
			local source = "$da/GE_VillageLevel_ECMA.dta"
		}

		use "$da/GE_Enterprise_ECMA.dta", clear
		capture: confirm variable `v'
		if _rc == 0 {
			local source = "$da/GE_Enterprise_ECMA.dta"
		}

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

    // Load dataset that contains variable v
    		use "`source'", clear
    		cap gen cons = 1
    // Dropping any previously weighted versions of variables
    		cap drop w_*


    ** set panel and time variables, bring in GPS if using **
    if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
      local timvar = "avgdate_vill"
      local panvar = "village_code"

      if $runGPS == 1 {
        merge 1:1 `panvar' using $dr/GE_Village_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
      }
    }

    if inlist("`source'", "$da/GE_HHLevel_ECMA.dta")  {
      local timvar = "survey_mth"
      local panvar = "hhid"

      if $runGPS == 1 {
        merge 1:1 hhid_key using $dr/GE_HH_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
      }
    }

  /*
    if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
      local timvar = "end_sur_date"
      local panvar = "end_entcode"
    }
  */

    if inlist("`source'", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
      local timvar = "survey_mth"
      local panvar = "persid"

      if $runGPS == 1 {
        merge n:1 hhid_key using $dr/GE_HH_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
      }
    }


// Label variables (program defined right before table_main_spillmechanism is called)
		ge_label_variables

// Define weight / generate weighted variables
		if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
			gen weight = 1
		}

		if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
			gen weight = entweight_EL

			// Set quantity-based weight for price variables
			if "`v'" == "wage_h_wins_PPP" {
				replace weight = weight * emp_h_tot
			}

		}

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

** 1. First column: dummy regression **
***************************************
// For dummy regression, restrict sample to eligible households only
		if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta", "$da/GE_Enterprise_ECMA.dta") {
			gen sample = 1
		}

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

// Dummy regression
		reg `v' treat hi_sat `blvars' [aweight=weight] if sample == 1, cluster(village_code)

		//mata: output_row_b = output_row_b, st_matrix("e(b)")[1,1]
		//mata: output_row_se = output_row_se, sqrt(st_matrix("e(V)")[1,1])
        pstar treat
        estadd local thisstat`count' = "`r(bstar)'": col1
        estadd local thisstat`countse' = "`r(sestar)'": col1
	//			estadd local thisstat`countN'  = string(`e(N)', "%9.0fc")


** 2. Second column: total treamtment effect on the treated (eligibles) from the 'optimal' spatial regression **
****************************************************************************************************************
** calculate optimal radii - for subcomponents of an index, we use the overall index
** household-level **
if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") { //,  {
  ** for consumption, use overall consumption
      if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
        calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if sample == 1, elig // no bl vars
      }
    ** for assets, use total assets
    else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
      calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if sample == 1, elig blvars("`blvars'") // no bl vars
    }
    ** for hours or salary by ag/non-ag, use overall
  else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
    local vrb = subinstr("`v'","_agri","",.)
    local vrb = subinstr("`v'","_nag","",.)
    calculate_optimal_radii `vrb' [aweight=weight] if sample == 1, elig // no baseline vars for individual obs
  }
  ** for all others -- use variable
  else {
    calculate_optimal_radii `v' [aweight=weight] if sample == 1, elig blvars("`blvars'")
  }
}
** village- level **
else if inlist("`source'","$da/GE_VillageLevel_ECMA.dta") {
    calculate_optimal_radii `v' [aweight=weight] if sample == 1, vill blvars("`blvars'")
  }
  else {
    di "Error: not a valid source"
    stop
  }

  // returning max radii band from program
  local r = r(r_max)
  local r_table_treat = max(`r', `r_table_treat')


			// Set optimal radii band from r2 to r
			local r2 = `r' - 2
			display "Optimal buffer for total effect on treated regression: `r2' to `r'"


  *** Estimating total effects: IV with spatially correlated standard errors ***
  // for recipient households, we use amount to own village and amount to other villages, with shares of eligibles treated as instrument
  local endregs "pp_actamt_ownvill"
  local exregs "treat"

  forval rad = 2(2)`r' {
    local r2 = `rad' - 2
    local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
    local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
  }

  if $runGPS == 1 {
    iv_spatial_HAC `v' cons `blvars' [aweight=weight] if sample == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  }
  if $runGPS == 0 {
    ivreg2 `v' `blvars' (`endregs' = `exregs') [aweight=weight] if sample == 1, cluster(sublocation_code)
  }

// Saving p-value of underidentification LM statistic as firststage_p
			loc firststage_p `e(idp)'

			** column 2: treated own village effect **
			pstar pp_actamt_ownvill
			estadd local thisstat`count' = "`r(bstar)'": col2
			estadd local thisstat`countse' = "`r(sestar)'": col2

			* if first time through, add in mean cash amount *
			if `varcount' == 1 {
				sum pp_actamt_ownvill [weight=weight]  if (sample == 1 & treat == 1)
				estadd local x_bar = string(`r(mean)', "%9.2f"): col2
				}
			* add in the number of observations
			if `r' == 2 {
				loc multi = 2
			}
			else {
				loc multi = 3
			}


		** 3. Third column: treated 0-2km radii**
			pstar pp_actamt_ov_0to2km
			estadd local thisstat`count' = "`r(bstar)'": col3
			estadd local thisstat`countse' = "`r(sestar)'": col3

			* if first time through, add in mean cash amount *
			if `varcount' == 1 {
				sum pp_actamt_ov_0to2km [weight=weight]  if (sample == 1 & treat == 1)
				estadd local x_bar = string(`r(mean)', "%9.2f"): col3
			}

		** 4. Fourth column: treated 2-4km radii (if exists) **
			if `r' > 2 {
				pstar pp_actamt_ov_2to4km
				estadd local thisstat`count' = "`r(bstar)'": col4
				estadd local thisstat`countse' = "`r(sestar)'": col4

				* if first time through, add in mean cash amount *
				sum pp_actamt_ov_2to4km [weight=weight]  if (sample == 1 & treat == 1)
				cap: estadd local x_bar = string(`r(mean)', "%9.2f"): col4
			}

		macro drop r


** Untreated household regression **
****************************************************************************************************************
*** Calculating optimal radii for non-recipient households***
if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") { //,  {
  ** for consumption, use overall consumption
      if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
        calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec // no bl vars
      }
    ** for assets, use total assets
    else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
      calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'")
    }
    ** for hours or salary by ag/non-ag, use overall
  else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
    local vrb = subinstr("`v'","_agri","",.)
    local vrb = subinstr("`v'","_nag","",.)
    calculate_optimal_radii `vrb' [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec  // no baseline vars for individual obs
  }
  ** for all others -- use variable
  else {
    calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'")
  }
}
** village-level
else if inlist("`source'","$da/GE_VillageLevel_ECMA.dta") {
    calculate_optimal_radii `v' [aweight=weight] if sample == 1, vill blvars("`blvars'")
  }
  else {
    di "Error: not a valid source"
    stop
  }

  local r=r(r_max)
	local r2 = `r' - 2
	display "Optimal buffer for untreated households regression: `rad2' to `rad'"

local r_table_untreat = max(`r', `r_table_untreat')

	// Reset endogenous and exogenous regressors
			local endregs = ""
			local exregs = ""
      local amount_list = ""
	// Want to run through the optimal rad2 to rad radii bands
			forval rad = 2(2)`r' {
				local r2 = `r' - 2

	// Interact endogenous regressors with eligibility status
	// For each household, one of the two will be zero
				gen pp_actamt_`r2'to`rad'km_el = pp_actamt_`r2'to`rad'km * eligible
				gen pp_actamt_`r2'to`rad'km_in = pp_actamt_`r2'to`rad'km * ineligible
	// Interact exogenous regressors with eligbiility status
				gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
				gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible

				local endregs = "`endregs'" + " pp_actamt_`r2'to`rad'km_el" + " pp_actamt_`r2'to`rad'km_in"
				local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`rad'km_el"  + " share_ge_elig_treat_`r2'to`rad'km_in"

        local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
			}
			di "endogenous regressors: `endregs'"
			di "exogenous regressors: `exregs'"

	// Running regression using optimal radii band
  if $runGPS == 1 {
  iv_spatial_HAC `v' cons eligible `blvars_untreat' [aweight=weight] if (eligible == 0 | treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
}
  if $runGPS == 0 {
    ivreg2 `v' eligible `blvars_untreat' (`endregs' = `exregs')  [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
  }
			loc firststage_p `e(idp)'

			** Column 5: control eligible, 0-2km **
			pstar pp_actamt_0to2km_el
			estadd local thisstat`count' = "`r(bstar)'": col5
			estadd local thisstat`countse' = "`r(sestar)'": col5

			* if first time through, add in mean cash amount *
			if `varcount' == 1 {
				sum pp_actamt_0to2km [weight=weight]  if (eligible == 1 & treat == 0)
				estadd local x_bar = string(`r(mean)', "%9.2f"): col5
			}

			* add in the number of observations
			if `r' == 2 {
				loc multi = 2
			}
			else if `r' > 2 {
				loc multi = 4
			}


			** Column 6: control ineligible, 0-2km **
			pstar pp_actamt_0to2km_in
			estadd local thisstat`count' = "`r(bstar)'": col6
			estadd local thisstat`countse' = "`r(sestar)'": col6

			* if first time through, add in mean cash amount *
			if `varcount' == 1 {
				sum pp_actamt_0to2km [weight=weight]  if (eligible == 0)
				estadd local x_bar = string(`r(mean)', "%9.2f"): col6
			}

			** if going out to 4 km
			if `r' == 4 {

				** Column 7: control eligible, 2-4km **
				pstar pp_actamt_2to4km_el
				estadd local thisstat`count' = "`r(bstar)'": col7
				estadd local thisstat`countse' = "`r(sestar)'": col7

				* if first time through, add in mean cash amount *
				sum pp_actamt_2to4km [weight=weight]  if (eligible == 1 & treat == 0)
				cap: estadd local x_bar = string(`r(mean)', "%9.2f"): col7

				** Column 8: control ineligible, 0-2km **
				pstar pp_actamt_2to4km_in
				estadd local thisstat`count' = "`r(bstar)'": col8
				estadd local thisstat`countse' = "`r(sestar)'": col8

				* if first time through, add in mean cash amount *
				sum pp_actamt_2to4km [weight=weight]  if (eligible == 0)
				cap: estadd local x_bar = string(`r(mean)', "%9.2f"): col8
			}



** 9. Ninth column: Add control, low sat mean of dependent variable **
**********************************************************************
		sum `v' [weight=weight] if treat == 0 & hi_sat == 0

		//mata: output_row_b = output_row_b,st_numscalar("r(mean)")
		//mata: output_row_se = output_row_se,st_numscalar("r(sd)")

		estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col9
		estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col9


		local thisvarlabel: variable label `v'

		if `firststage' == 0 {
			if numoutcomes == 1 {
				local varlabels `" " "`varlabels' "`thisvarlabel'" " " " " "'
				local statnames "thisstat`countspace' `statnames' thisstat`count' thisstat`countse' thisstat`countspace'"
			}
			else {
				local varlabels `"`varlabels' "`thisvarlabel'" " " " " "'
				local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countspace'"
			}

// Incrementing counters because next `v' coefficient will fall three lines under the preceding coefficient when thinking column wise
			local count = `count' + 3
			local countse = `count' + 1
			local countspace = `count' + 2
		}

		if `firststage' == 1 {
			if numoutcomes == 1 {
				local varlabels `" " "`varlabels' "`thisvarlabel'" " " " " " " "'
				local statnames "thisstat`countspace' `statnames' thisstat`count' thisstat`countse' thisstat`countfirststage' thisstat`countspace'"
			}
			else {
				local varlabels `"`varlabels' "`thisvarlabel'" " " " " " " "'
				local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countfirststage' thisstat`countspace'"
			}

// Incrementing counters because next `v' coefficient will fall four lines under the preceding coefficient when thinking column wise
			local count = `count' + 4
			local countse = `count' + 1
			local countfirststage = `count'+ 2
			local countspace = `count' + 3
		}

		if `fdr' == 1 {
			if numoutcomes == 1 {
				local varlabels `" " "`varlabels' "`thisvarlabel'" " " " " " " "'
				local statnames "thisstat`countspace' `statnames' thisstat`count' thisstat`countse' thisstat`countfdr' thisstat`countspace'"
			}
			else {
				local varlabels `"`varlabels' "`thisvarlabel'" " " " " " " "'
				local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countfdr' thisstat`countspace'"
			}

			local count = `count' + 4
			local countse = `count' + 1
			local countfdr = `count'+ 2
			local countspace = `count' + 3
		}

		local ++varcount
	}
// END OF LOOP THROUGH OUTCOMES
    di "End outcome loop"


*** ADDING IN MEANS OF DEPENDENT VARIABLES ***

* column 1: not using amount, so not reporting *


local varlabels `"`varlabels' "\midrule $\bar{X}$" "'
local statnames "`statnames' x_bar"


** calculating columns **
if `r_table_treat' == 2 & `r_table_untreat' == 2 {
	local columns = 6
}
else if `r_table_treat' > 2 & `r_table_untreat' == 2 {
	local columns = 7
}
else {
	local columns = 9
}


// Exporting tex table
	if "`fulltable'" == "1" {
		loc prehead "\begin{table}[htbp]\centering \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \caption{$sumtitle} \label{tab:$sumpath} \maxsizebox*{\linewidth}{\textheight}{ \begin{threeparttable} \begin{tabular}{l*{`columns'}{S}} \toprule"
		loc postfoot "\bottomrule \end{tabular} \begin{tablenotes}[flushleft] \footnotesize \item \emph{Notes:} @note \end{tablenotes} \end{threeparttable} } \end{table}"
	}
	else {
		loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{`columns'}{S}} \toprule"
		loc postfoot "\bottomrule\end{tabular}}"
	}

	di "Exporting tex file"

  if $runGPS == 0 {
    local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
  }


	** Exporting table going out to 2km **
	if `columns' == 6 {
		esttab col1 col2 col3 col5 col6 col9  `using', cells(none) booktabs nonotes compress replace ///
		mgroups("\textbf{Recipient households}" "\textbf{Non-recipient households}", pattern(1 0 0 1 0 1) ///
		prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
		mtitle("\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }" "\shortstack{Amt Own Village \\ IV}" "\shortstack{Amt Other Villages \\ 0-2km \\ IV}" "\shortstack{Amount, Control Eligibles \\ 0-2km \\ IV}" "\shortstack{Amount, Ineligibles \\ 0-2km \\ IV}" "\shortstack{Control, low-saturation \\ mean (SD)}") ///
		stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')
}
else if `columns' == 7 {
	esttab col1 col2 col3 col4 col5 col6 col9 `using', cells(none) booktabs nonotes compress replace ///
	mgroups("\textbf{Recipient households}" "\textbf{Non-recipient households}", pattern(1 0 0 0 1 0 1) ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
	mtitle("\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }" "\shortstack{Amt Own Village \\ IV}" "\shortstack{Amt Other Villages \\ 0-2km \\ IV}" "\shortstack{Amt Other Villages \\ 2-4km \\ IV}" "\shortstack{Amount, Control Eligibles \\ 0-2km \\ IV}" "\shortstack{Amount, Ineligibles \\ 0-2km \\ IV}" "\shortstack{Control, low-saturation \\ mean (SD)}") ///
	stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

}
else {

** Exporting table going out to 4km **
	esttab col1 col2 col3 col4 col5 col6 col7 col8 col9 `using', cells(none) booktabs nonotes compress replace ///
	mgroups("\textbf{Recipient Households}" "\textbf{Non-recipient Households}", pattern(1 0 0 0 1 0 0 0 1) ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
	mtitle("\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }" "\shortstack{Amt Own Village \\ IV}" "\shortstack{Amt Other Villages \\ 0-2km \\ IV}" "\shortstack{Amt Other Villages \\ 2-4km \\ IV}" "\shortstack{Amount, Control Eligibles \\ 0-2km \\ IV}" "\shortstack{Amount, Ineligibles \\ 0-2km \\ IV}" "\shortstack{Amount, Control Eligibles \\ 2-4km \\ IV}" "\shortstack{Amount, Ineligibles \\ 2-4km \\ IV}" "\shortstack{Control, low-saturation \\ mean (SD)}") ///
	stats(`statnames', labels(`varlabels')) note("$sumnote") prehead(`prehead') postfoot(`postfoot')
}


end
