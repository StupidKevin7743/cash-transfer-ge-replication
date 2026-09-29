** Defining program to build appendix table for radii robustness of main tables **

** Format of table:

** (1) Column (2) from the main table (average total effect for treated -- optimal radius)
** (2) Average total effect for treated -- specification with rmax == 4
** (3) Average total effect for treated -- specification with rmax == 6
**
** (4) Column (3) from the main table (average total effect for untreated -- optimal radius)
** (5) Average total effect for untreated -- specification with rmax == 4
** (6) Average total effect for untreated -- specification with rmax == 6
**
** (7) Control, low-saturation mean (SD)


** as 3rd row: N for each regression

** below table: X_bar for each different group






************************************************************************************

cap program drop appendix_radii_table
program define appendix_radii_table
    syntax using, outcomes(string) [maxradius(integer 2)] [FDR(integer 0)] [firststage(integer 0) FULLtable(str)]
        // default option for maxradius is 2

	* setting up directory for unformatted coefficients associated with tables
	di `"Using: `using'"'
	cap mkdir "${dtab}/coeftables"
	local coeftable = subinstr(`"`using'"', `"${dtab}"', `"${dtab}/coeftables"', 1)
	local coeftable = subinstr(`"`coeftable'"', ".tex", "_RawCoefs.xls", 1)

	local outregopt "replace"
	local outregset "excel label(proper)"

	// Setting up blank table, 6 columns and as many rows as variables in `outcomes'
	drop _all
	local ncols = 18 //biggest table needs 18 columns
	local nrows = wordcount("`outcomes'")

	// Fill in table with dummy values, set up estimation storage under names col1-col6
	eststo clear
	est drop _all
  quietly{
	set obs `nrows'
	gen x = 1
	gen y = 1
	if `nrows' > 1 {
		forvalues x = 1/`ncols' {
			eststo col`x': reg x y
		}
	}
	else {
		expand 5
		forvalues x = 1/`ncols' {
			eststo col`x': reg x y
		}
		keep if _n <= `nrows'
	}
}

	// Initialize counters, needed for "sub"-rows for each outcome variable
	local varcount = 1
	local count = 1
	local countse = `count' + 1
	local countspace = `count' + 2



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
        merge 1:1 `panvar' using $dr/GE_HH_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
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
        merge m:1 hhid using $dr/GE_HH_GPS_Coordinates_RESTRICTED.dta, keep(1 3) nogen
      }
    }


		// Label variables (program defined right before table_main_spillmechanism is called)
		ge_label_variables

		// Define weight / generate weighted variables
		if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
			gen weight = 1

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

		if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
			gen weight = entweight_EL

			// Set quantity-based weight for price variables
			if "`v'" == "wage_h_wins_PPP" {
				replace weight = weight * emp_h_tot
			}


		}

		// Increase outcomes counter; started at 0, will now increase by 1 each time loop is passed through
		scalar numoutcomes = numoutcomes + 1

		// Initiate matrix for storing beta coefficient and standard error for each regression ran
		mata: output_row_b = .
		mata: output_row_se = .

		// Adding variable label to the table (what appears in left of table); collabels will add on labels each loop iteration
        local add : var label `v'
        local collabels `"`collabels' "`add'""'


		** adding baseline variables - if they are in the dataset **
        cap desc `v'_BL M`v'_BL
        if _rc == 0 {
            local blvars "`v'_BL M`v'_BL"
            cap gen `v'_BLe = eligible * `v'_BL
            cap gen M`v'_BLe = eligible * M`v'_BL
            local blvars_untreat "`blvars' `v'_BLe M`v'_BLe"
        }
        else {
            local blvars ""
            local blvars_untreat ""
        }

		** define sample **
		if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
			gen sample = 1
		}

		if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
			gen sample = eligible
		}

		if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
			gen sample = 1
		}


		** 1. First column: total treamtment effect on the treated (eligibles) from the 'optimal' spatial regression (2nd column from main GE table) **
		******************************************************************************************************
    ** calculate optimal radii - for subcomponents of an index, we use the overall index
    ** household-level **
		if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
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

      local r = `r(r_max)'
      local r2 = `r' - 2

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
      outreg2 `coeftable', `outregopt' `outregset'
      local outregopt "append"

      ** Get mean total effect on treated eligibles **
      loc ATEstring_tot = "0"
      foreach vrb of local endregs {
        sum `vrb' [aweight=weight] if (sample == 1 & treat == 1)
        local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
      }

      disp "`ATEstring_tot'"
      lincom "`ATEstring_tot'"
      mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
      mata: output_row_se = output_row_se,st_numscalar("r(se)")

        pstar, b(`r(estimate)') se(`r(se)')
      estadd local thisstat`count' = "`r(bstar)'": col1
      estadd local thisstat`countse' = "`r(sestar)'": col1

    if `firststage' == 1{
    if `firststage_p' < 0.01{
      loc firststage_str "\textbf{$<$0.01}"
    }
    else{
      if `firststage' != . loc firststage_str "=" + string(`firststage_p', "%4.2fc")
      else loc firststage_str "= ."
    }
    loc firststage_full "\multicolumn{1}{c}{[" + "`r'" + "km; p" + "`firststage_str'" + "]}"
    estadd local thisstat`countfirststage' =  "`firststage_full'": col1
    }


  ** Average total effect for treated -- specification with rmax == 2, 4, 6 **
  **********************************************************************
  loc colnum = 2
  foreach maxradius of numlist 2(2)6 {

      local endregs "pp_actamt_ownvill"
      local exregs "treat"

      forval rad = 2(2)`maxradius' {
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

          outreg2 `coeftable', `outregopt' `outregset'
            eststo e_ive

          ** Get mean total effect on treated eligibles **
          local ATEstring_tot = "0"
          foreach vrb of local endregs {
            sum `vrb' [aweight=weight] if (sample == 1 & treat == 1)
            local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
          }

          disp "`ATEstring_tot'"
          lincom "`ATEstring_tot'"
          mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
          mata: output_row_se = output_row_se,st_numscalar("r(se)")

            *** avg treated effect for maxradius  ***
            pstar, b(`r(estimate)') se(`r(se)')
          estadd local thisstat`count' = "`r(bstar)'": col`colnum'
          estadd local thisstat`countse' = "`r(sestar)'": col`colnum'

          loc ++colnum

      }


** Untreated household regressions **
****************************************************************************************************************

** Column 3 in main table paper: optimal radius***
**************************************************
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

  // for non-recipients, we use total amount within 0-2 km, without making village distinction
  local endregs = ""
  local exregs = ""
  local amount_list = ""

  forval rad = 2(2)`r' {
    local r2 = `r' - 2

    gen pp_actamt_`r2'to`rad'km_eligible = pp_actamt_`r2'to`rad'km * eligible
    gen pp_actamt_`r2'to`rad'km_ineligible = pp_actamt_`r2'to`rad'km * ineligible

    gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
    gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible

    local endregs = "`endregs'" + " pp_actamt_`r2'to`rad'km_eligible" + " pp_actamt_`r2'to`rad'km_ineligible"
    local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`rad'km_el"  + " share_ge_elig_treat_`r2'to`rad'km_in"

    local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
  }

  if $runGPS == 1 {
    iv_spatial_HAC `v' cons eligible `blvars_untreat' [aweight=weight] if (eligible == 0 | treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
  }
  if $runGPS == 0 {
    ivreg2 `v' eligible `blvars_untreat' (`endregs' = `exregs') [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
  }
  eststo e_ivie
  outreg2 `coeftable', `outregopt' `outregset'


    **************


    ** Get mean total spillover effect on eligibles in control villages and ineligibles **
    sum weight if (eligible == 1 & treat == 0)
    local mean1 = r(sum)
    sum weight if (eligible == 0)
    local mean2 = r(sum)

    local eligcontrolweight = `mean1' / (`mean1' + `mean2')
    local ineligweight = `mean2' / (`mean1' + `mean2')

    local ATEstring_spillover = "0"
    foreach vrb of local amount_list {
      sum `vrb' [weight=weight] if (eligible == 1 & treat == 0)
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`eligcontrolweight'" + "*`r(mean)'" + "*`vrb'_eligible"

      sum `vrb' [aweight=weight] if eligible == 0
      local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ineligweight'" + "*`r(mean)'" + "*`vrb'_ineligible"
    }

    disp "`ATEstring_spillover'"
    lincom "`ATEstring_spillover'"
    mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
    mata: output_row_se = output_row_se,st_numscalar("r(se)")

    **column 3 in main table 1 **
      pstar, b(`r(estimate)') se(`r(se)')
    estadd local thisstat`count' = "`r(bstar)'": col`colnum'
    estadd local thisstat`countse' = "`r(sestar)'": col`colnum'

  if `firststage' == 1{
  if `firststage_p' < 0.01{
    loc firststage_str "\textbf{$<$0.01}"
  }
  else{
    if `firststage' != . loc firststage_str "=" + string(`firststage_p', "%4.2fc")
    else loc firststage_str "= ."
  }
  loc firststage_full "\multicolumn{1}{c}{[" + "`rad'" + "km; p" + "`firststage_str'" + "]}"
  estadd local thisstat`countfirststage' =  "`firststage_full'": col5

  }

  loc ++colnum

  ** Average total effect for untreated -- specification with rmax == 2 **
  ************************************************************************
  cap drop pp_actamt_?to?km_eligible pp_actamt_?to?km_ineligible
  cap drop share_ge_elig_treat_?to?km_in share_ge_elig_treat_?to?km_el


  foreach maxradius of numlist 2(2)6 {

    loc rad = `maxradius'
    loc r2 = `rad' - 2

    gen pp_actamt_`r2'to`rad'km_eligible = pp_actamt_`r2'to`rad'km * eligible
    gen pp_actamt_`r2'to`rad'km_ineligible = pp_actamt_`r2'to`rad'km * ineligible

    gen share_ge_elig_treat_`r2'to`rad'km_el = share_ge_elig_treat_`r2'to`rad'km * eligible
    gen share_ge_elig_treat_`r2'to`rad'km_in = share_ge_elig_treat_`r2'to`rad'km * ineligible


    macro drop rad r2

    local endregs = ""
    local exregs = ""
    local amount_list = ""

    forval rad = 2(2)`maxradius' {
      local r2 = `rad' - 2
      di "rad: `rad' r2: `r2'"

      local endregs = "`endregs'" + " pp_actamt_`r2'to`rad'km_eligible" + " pp_actamt_`r2'to`rad'km_ineligible"
      local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`rad'km_el"  + " share_ge_elig_treat_`r2'to`rad'km_in"

      local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
    }

    if $runGPS == 1 {
      iv_spatial_HAC `v' cons eligible `blvars_untreat' [aweight=weight] if (eligible == 0 | treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    }
    if $runGPS == 0 {
      ivreg2 `v' eligible `blvars_untreat' (`endregs' = `exregs') [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
    }

    eststo e_ivie
    outreg2 `coeftable', `outregopt' `outregset'

      *loc firststage_p `e(idp)'
      **************


      ** Get mean total spillover effect on eligibles in control villages and ineligibles **
      sum weight if (eligible == 1 & treat == 0)
      local mean1 = r(sum)
      sum weight if (eligible == 0)
      local mean2 = r(sum)

      local eligcontrolweight = `mean1' / (`mean1' + `mean2')
      local ineligweight = `mean2' / (`mean1' + `mean2')

      local ATEstring_spillover = "0"
      foreach vrb of local amount_list {
        sum `vrb' [weight=weight] if (eligible == 1 & treat == 0)
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`eligcontrolweight'" + "*`r(mean)'" + "*`vrb'_eligible"

        sum `vrb' [aweight=weight] if eligible == 0
        local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ineligweight'" + "*`r(mean)'" + "*`vrb'_ineligible"
      }

      disp "`ATEstring_spillover'"
      lincom "`ATEstring_spillover'"
      mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
      mata: output_row_se = output_row_se,st_numscalar("r(se)")


        pstar, b(`r(estimate)') se(`r(se)')
      estadd local thisstat`count' = "`r(bstar)'": col`colnum'
      estadd local thisstat`countse' = "`r(sestar)'": col`colnum'

      if `firststage' == 1{
      if `firststage_p' < 0.01{
        loc firststage_str "\textbf{$<$0.01}"
      }
      else{
        if `firststage' != . loc firststage_str "=" + string(`firststage_p', "%4.2fc")
        else loc firststage_str "= ."
      }
      loc firststage_full "\multicolumn{1}{c}{[" + "`rad'" + "km; p" + "`firststage_str'" + "]}"
      estadd local thisstat`countfirststage' =  "`firststage_full'": col`colnum'

      }

      loc ++colnum
  }


** Column 7: Add control, low sat mean of dependent variable **
***************************************************************
		sum `v' [weight=weight] if treat == 0 & hi_sat == 0

		mata: output_row_b = output_row_b,st_numscalar("r(mean)")
		mata: output_row_se = output_row_se,st_numscalar("r(sd)")

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
*/
		local ++varcount
	}
// END OF LOOP THROUGH OUTCOMES
    di "End outcome loop"



local varlabels `"`varlabels' "'
local statnames "`statnames' "


** Column size for table **

	local columns = 9

  *********************

// Exporting tex table
	if "`fulltable'" == "1" {
		loc prehead "\begin{table}[htbp]\centering \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \caption{$sumtitle} \label{tab:$sumpath} \maxsizebox*{\linewidth}{\textheight}{ \begin{threeparttable} \begin{tabular}{l*{`columns'}{S}} \toprule"
		loc postfoot "\bottomrule \end{tabular} \begin{tablenotes}[flushleft] \footnotesize \item \emph{Notes:} @note \end{tablenotes} \end{threeparttable} } \end{table}"
	}
	else {
		loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{`columns'}{S}} \toprule"
		loc postfoot "\bottomrule\end{tabular}}"
	}

  if $runGPS == 0 {
    local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
  }


	di "Exporting tex file"

	** Exporting table  **
    local name = "$dtab/Appendix_" + `filebase'+ "_RadiiRobustness.tex"
		esttab col1 col2 col3 col4 col5 col6 col7 col8 col9 `using', cells(none) booktabs nonotes compress replace ///
		mgroups("\textbf{Recipient households}" "\textbf{Non-recipient households}", pattern(1 0 0 0 1 0 0 0 1) ///
		prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    mtitle("\shortstack{Total Effect \\ IV \\ Optimal Radius}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 2$ }" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 4$ }" "\shortstack{Total Effect \\ IV \\  $\bar{R} = 6$}" "\shortstack{Total Effect \\ IV \\ Optimal Radius}" "\shortstack{Total Effect \\ IV \\ $\bar{R} = 2$ }" "\shortstack{Total Effect \\ IV \\  $\bar{R} = 4$}" "\shortstack{Total Effect \\ IV \\  $\bar{R} = 6$}" "\shortstack{Control, low-saturation \\ mean (SD)}") ///
		stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')



end
