** Defining program to build main table for presentations **
************************************************************
cap program drop table_main
program define table_main
    syntax using [if], outcomes(string) [FDR(integer 0)] [firststage(integer 0)]

    * setting up directory for unformatted coefficients associated with tables
      di `"Using: `using'"'
      cap mkdir "${dtab}/coeftables"
      local coeftable = subinstr(`"`using'"', `"${dtab}"', `"${dtab}/coeftables"', 1)
      local coeftable = subinstr(`"`coeftable'"', ".tex", "_RawCoefs.xls", 1)

      local outregopt "replace"
      local outregset "excel label(proper)"

	* setting up blank table *
	drop _all
	local ncols = 4
	local nrows = wordcount("`outcomes'")

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
	local countse = `count'+1
	local countspace = `count' + 2

  ** MW 2022-03-11: do we use this for any tables in the paper?
	if `fdr' == 1 {
		local countse = `count'+1
		local countfdr = `count'+2
		local countspace = `count' + 3
	}

  ** MW 2022-03-11: do we use this for any tables in the paper?
	if `firststage' == 1 {
		local countse = `count'+1
		local countfirststage = `count'+2
		local countspace = `count' + 3
	}


	local varlabels ""
	local statnames ""
	local collabels ""

	mata: output_table = .,.,.,.,.
	scalar numoutcomes = 0

	foreach v in `outcomes' {
        di "Loop for `v'"

        /** This could be a program, with variable lists, rather than having to load datasets every time **/
		** Find source for variable v **
		use "$da/GE_VillageLevel_ECMA.dta", clear
		capture: confirm variable `v'
		if _rc == 0 {
			local source = "$da/GE_VillageLevel_ECMA.dta"
		}

/*
		use "$da/GE_Enterprise_ECMA.dta", clear
		capture: confirm variable `v'
		if _rc == 0 {
			local source = "$da/GE_Enterprise_ECMA.dta"
		}
*/
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

		disp "`source'"

    ** Load dataset **
		use "`source'", clear
		cap gen cons = 1
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



		if "`if'" != "" {
		  keep `if'
		}

		** Label variables **
		ge_label_variables

		** define weight **
		if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
			gen weight = 1
		}

		if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
			gen weight = hhweight_EL
			gen ineligible = 1-eligible
			** set quantity-based weight for price variables **
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

    *** MW 2022-03-11: we use tables_ent for all enterprise results now, right?
		if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
			gen weight = entweight_EL

			** set quantity-based weight for price variables **
			if "`v'" == "wage_h_wins_PPP" {
				replace weight = weight * emp_h_tot
			}
		}

		scalar numoutcomes = numoutcomes + 1

		mata: output_row_b = .
		mata: output_row_se = .

        ** adding variable label to the table **
        local add : var label `v'
        local collabels `"`collabels' "`add'""'


		** 1 First column: Dummy regressions **
		***************************************

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

		reg `v' treat hi_sat `blvars' [aweight=weight] if sample == 1, cluster(village_code)

		outreg2 `coeftable', `outregopt' `outregset'
		local outregopt "append"

        ** formatting for tex - column 1, indicator for treatment status **
        pstar treat
        estadd local thisstat`count' = "`r(bstar)'": col1
        estadd local thisstat`countse' = "`r(sestar)'": col1


		** 2. Add total treamtment effect on the treated (eligibles) from the 'optimal' spatial regression **
		*****************************************************************************************************
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



      *** Estimating total effects: IV with spatially correlated standard errors ***
      // for recipient households, we use amount to own village and amount to other villages, with shares of eligibles treated as instrument
      local endregs "pp_actamt_ownvill"
      local exregs "treat"

      forval rad = 2(2)`r' {
        local r2 = `rad' - 2
        local endregs "`endregs' pp_actamt_ov_`r2'to`rad'km"
        local exregs "`exregs' share_ge_elig_treat_ov_`r2'to`rad'km"
      }

      ** Running version from paper, with spatial SEs (requires household / enterprise GPS data)
    if $runGPS == 1 {
			iv_spatial_HAC `v' cons `blvars' [aweight=weight] if sample == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
    }
    if $runGPS == 0 {
      ivreg2 `v' `blvars' (`endregs' = `exregs') [aweight=weight] if sample == 1, cluster(sublocation_code)
    }

      outreg2 `coeftable', `outregopt' `outregset'
      eststo e_ive

			** Get mean total effect on treated eligibles - loop through endogenous regressors **
      local ATEstring_tot = "0"
      foreach var of local endregs {
        sum `var' [weight=weight]  if (sample == 1 & treat == 1)
  			local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`var'"
      }

			disp "`ATEstring_tot'"
			lincom "`ATEstring_tot'"

      pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col2
			estadd local thisstat`countse' = "`r(sestar)'": col2

		if `firststage' == 1{
		if `firststage_p' < 0.01{
			loc firststage_str "\textbf{$<$0.01}"
		}
		else{
			if `firststage' != . loc firststage_str "=" + string(`firststage_p', "%4.2fc")
			else loc firststage_str "= ."
		}
		loc firststage_full "\multicolumn{1}{c}{[" + "`r'" + "km; p" + "`firststage_str'" + "]}"
		estadd local thisstat`countfirststage' =  "`firststage_full'": col2
		}

    macro drop r

		** 3. Add spillover effects **
		*******************************

		** i. pooled spillover on ineligibles, and eligibles in control villages **
		***************************************************************************
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
				local r2 = `rad' - 2

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
        ivreg2 `v' eligible `blvars_untreat' (`endregs' = `exregs')  [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
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
			foreach vrb of local amount_list {
				sum `vrb' [weight=weight] if (eligible == 1 & treat == 0)
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`eligcontrolweight'" + "*`r(mean)'" + "*`vrb'_eligible"

				sum `vrb' [aweight=weight] if eligible == 0
				local ATEstring_spillover = "`ATEstring_spillover'" + "+" + "`ineligweight'" + "*`r(mean)'" + "*`vrb'_ineligible"
			}

			disp "`ATEstring_spillover'"
			lincom "`ATEstring_spillover'"

      pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col3
			estadd local thisstat`countse' = "`r(sestar)'": col3

		if `firststage' == 1{
		if `firststage_p' < 0.01{
			loc firststage_str "\textbf{$<$0.01}"
		}
		else{
			if `firststage' != . loc firststage_str "=" + string(`firststage_p', "%4.2fc")
			else loc firststage_str "= ."
		}
		loc firststage_full "\multicolumn{1}{c}{[" + "`rad'" + "km; p" + "`firststage_str'" + "]}"
		estadd local thisstat`countfirststage' =  "`firststage_full'": col3

		}



		** 4. Add mean of dependent variable **
		****************************************
		sum `v' [weight=weight] if treat == 0 & hi_sat == 0

		estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col4
		estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col4

		** looping variables for tex table **
		local thisvarlabel: variable label `v'

		if `firststage' == 0 & `fdr' == 0 {
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

			local count = `count' + 4
			local countse = `count' + 1
			local countfirststage = `count'+ 2
			local countspace = `count' + 3


		}

		if `fdr' == 1 {
			if numoutcomes == 1 {
				local varlabels `" " " "`thisvarlabel'" " " " " " ""'
				local statnames " thisstat`countspace' thisstat`count' thisstat`countse' thisstat`countfdr' thisstat`countspace'"
			}
			else {
				local varlabels `" `varlabels' "`thisvarlabel'" " " " " " ""'
				local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countfdr' thisstat`countspace'"
			}

			local count = `count' + 1
			local countse = `count' + 1
			local countfdr = `count'+ 2
			local countspace = `count' + 3
		}


		local ++varcount

	}

    // end loop through outcomes
    di "End outcome loop"


  ** displaying locals for troubleshooting **
  di "`statnames'"
  di `"`varlabels'"'

    *** exporting tex table -- average effects ***
    ** dropping column 2 **
	loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{6}{S}}\toprule"
	loc postfoot "\bottomrule\end{tabular}}"

  if $runGPS == 0 {
    local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
  }

	di "Exporting tex file"
	esttab col1 col2 col3 col4 `using', cells(none) booktabs extracols(3) nonotes compress replace ///
	mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Recipient Households}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Non-recipient Households}}} & \\   \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}"  "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Control, low saturation \\ mean (SD)}}") ///
	stats(`statnames', labels(`varlabels')) note(`note') prehead(`prehead') postfoot(`postfoot')

end
