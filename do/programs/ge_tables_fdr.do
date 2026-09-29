** Defining program to build main table for presentations **
************************************************************
cap program drop table_fdr
program define table_fdr
    syntax using, outcomes(string) [FDR(integer 0)] [firststage(integer 0)]

    * setting up directory for unformatted coefficients associated with tables
    di `"Using: `using'"'
      cap mkdir "${dtab}/coeftables"
      local coeftable = subinstr(`"`using'"', `"${dtab}"', `"${dtab}/coeftables"', 1)
      local coeftable = subinstr(`"`coeftable'"', ".tex", "_RawCoefs.xls", 1)

      local outregopt "replace"
      local outregset "excel label(proper)"

	* setting up blank table *
	drop _all
	local ncols = 5
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
	local countse = `count'+1
	local countspace = `count' + 2

	if `fdr' == 1 {
		local countse = `count'+1
		local countfdr = `count'+2
		local countspace = `count' + 3

    // Generating datasets for multiple testing adjustment
    local n_results = `ncols' - 1 // last column summary means
    	forval i = 1/`n_results' {
        cap postclose mc`i'
    		postfile mc`i' str30 variable double(pval`i' beta se) obs using "$dt/mc`i'.dta", replace
    	}
    	postutil dir

	}

	if `firststage' == 1 {
		local countse = `count'+1
		local countfirststage = `count'+2
		local countspace = `count' + 3
	}

	//local countn = `count'+2

	local varlabels ""
	local statnames ""
	local collabels ""

	mata: output_table = .,.,.,.,.
	scalar numoutcomes = 0

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
      local merge `"merge n:1 village_code using "$dr/GE_Treat_Status_Master.dta", keepusing(satlevel_name) nogen"'
		}

		disp "`source'"


    ** Load dataset **
    use "`source'", clear
	cap: drop _merge
    `merge'
    cap egen satcluster = group(satlevel_name)
    cap gen cons = 1
    cap drop w_*

		if inlist("`source'", "$da/GE_HHLevel_ECMA.dta")  {
			local timvar = "survey_mth"
			local panvar = "hhid"
      if $runGPS == 1 {
        merge m:1 hhid using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
      }
		}


		if inlist("`source'", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
			local timvar = "survey_mth"
			local panvar = "persid"

      if $runGPS == 1 {
        merge n:1 hhid using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
      }
		}



		** Label variables **
		ge_label_variables

		** define weight / generate weighted variables **
		if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
			gen weight = 1

		/*	gen w_`v' = `v'
			gen w_cons = cons

			foreach varb of var pp_actamt_* share_* {
				gen w_`varb' = `varb'
			}
		*/
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

		/*	cap gen w_elig = sqrt(hhweight_EL)*eligible

			gen w_`v' = sqrt(hhweight_EL)*`v'
			gen w_cons = sqrt(hhweight_EL)

			foreach varb of var pp_actamt_* share_* {
				gen w_`varb' = `varb' * sqrt(hhweight_EL)
			}
		*/
		}

		scalar numoutcomes = numoutcomes + 1

    ** adding variable label to the table **
    local add : var label `v'
    local collabels `"`collabels' "`add'""'


		** 1 First column: Dummy regressions **
		***************************************

		** define sample **
		gen sample = eligible

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

        // posting to file for multiple testing adjustment
        test treat
        local pval1 = `r(p)'
        post mc1 ("`thisvarname'") (`pval1') (_b[treat]) (_se[treat]) (`e(N)')


		** 2. Add total treatment effect on the treated (eligibles) from the 'optimal' spatial regression **
		*****************************************************************************************************

      calculate_optimal_radii `v' [aweight = weight] if sample ==1 , elig blvars("`blvars'")

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

      if $runGPS == 1 {
        iv_spatial_HAC `v' cons `blvars' [aweight=weight] if sample == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
			if $runGPS == 0 {
        ivreg2 `v' `blvars' (`endregs' = `exregs') [aweight=weight] if sample == 1, cluster(sublocation_code)
      }
      outreg2 `coeftable', `outregopt' `outregset'
			*loc firststage_p `e(idp)'
        eststo e_ive

			** Get mean total effect on treated eligibles **
			local ATEstring_tot = "0"

			foreach vrb of local endregs {
				sum `vrb' [aweight=weight] if (sample == 1 & treat == 1)
				local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
			}

			disp "`ATEstring_tot'"
			lincom "`ATEstring_tot'"

      if `fdr' == 1 {
      // posting to file for multiple testing adjustment
      //test treat
      local pval2 = `r(p)'
      post mc2 ("`thisvarname'") (`pval2') (`r(estimate)') (`r(se)') (`e(N)')

      }

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


		** 3. Add spillover effects **
		*******************************

		** i. pooled spillover on ineligibles, and eligibles in control villages **
		***************************************************************************

      calculate_optimal_radii `v' [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec blvars("`blvars_untreat'")

      local rad = r(r_max)

      local endregs = ""
			local exregs = ""
      local amount_list = ""

			forval r = 2(2)`rad' {
				local r2 = `r' - 2

				gen pp_actamt_`r2'to`r'km_eligible = pp_actamt_`r2'to`r'km * eligible
				gen pp_actamt_`r2'to`r'km_ineligible = pp_actamt_`r2'to`r'km * ineligible

				gen share_ge_elig_treat_`r2'to`r'km_el = share_ge_elig_treat_`r2'to`r'km * eligible
				gen share_ge_elig_treat_`r2'to`r'km_in = share_ge_elig_treat_`r2'to`r'km * ineligible

				local endregs = "`endregs'" + " pp_actamt_`r2'to`r'km_eligible" + " pp_actamt_`r2'to`r'km_ineligible"
				local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`r'km_el"  + " share_ge_elig_treat_`r2'to`r'km_in"
        local amount_list "`amount_list' pp_actamt_`r2'to`r'km"
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


      // posting to file for multiple testing adjustment
      if `fdr' == 1 {
      //test treat
      local pval3 = `r(p)'
      post mc3 ("`thisvarname'") (`pval3') (`r(estimate)') (`r(se)') (`e(N)')
      }

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



    ** 4. Add pooled saturation coefficient **
		****************************************
    * ensure we have interaction terms
    cap gen treat_elig = treat * eligible
    cap gen treat_hisat = treat * hi_sat
    cap gen treat_hisat_eligible = treat * hi_sat * eligible
    cap gen hisat_eligible = hi_sat * eligible

    // Run Equation (1) regression: triple interaction
    reg `v' treat eligible hi_sat treat_elig treat_hisat hisat_eligible treat_hisat_eligible `blvars', cluster(satcluster)
    outreg2 `coeftable', `outregopt' `outregset'

    // Defining weights
		loc t_w = 0.5 // treatment share
		loc c_w = (1-`t_w') // control share
		loc e_w = 1/3 // eligible share (from census data)
		loc ie_w = (1-`e_w') // ineligible share (from census data)

		qui lincom `t_w'*`e_w'*(_b[hi_sat] + _b[treat_hisat] + _b[hisat_eligible] + _b[treat_hisat_eligible]) + ///
			(`c_w' * `e_w') * (_b[hi_sat] + _b[hisat_eligible]) + ///
			(`t_w' * `ie_w') * (_b[hi_sat] + _b[treat_hisat]) + ///
			(`c_w' * `ie_w') * (_b[hi_sat])

		local lincom_t = r(estimate) / r(se)
		local lincom_p = 2*ttail((r(df)),abs(`lincom_t'))

    post mc4 ("`thisvarname'") (`lincom_p') (`r(estimate)') (`r(se)') (`e(N)')


    pstar, b(`r(estimate)') se(`r(se)') p(`lincom_p')
		estadd local thisstat`count' = "`r(bstar)'": col4
		estadd local thisstat`countse' = "`r(sestar)'": col4


		** 4. Add mean of dependent variable **
		****************************************
		sum `v' [aweight=weight] if treat == 0 & hi_sat == 0

		estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col5
		estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col5

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

			local count = `count' + 4

			local countse = `count' + 1
			local countfdr = `count'+ 2
			local countspace = `count' + 3
		}


		local ++varcount

	}
    // end loop through outcomes
    di "End outcome loop"

*** CALCULATING FDR ADJUSTMENT, FILLING TABLE BACK IN ***
// Multiple testing adjustment: FDR test using minq wrapper

if `fdr' == 1 {
  di "Begin FDR adjustment"
  // Closing mc postfile
  forval i=1/`n_results' {
    postclose mc`i'
  }

	cap drop _all

	forval i = 1/`n_results' {
		use "$dt/mc`i'.dta"
		mkmat pval`i', matrix(plist`i')
		minq plist`i', q(qlist`i') step(0.001)
		di "Naive p-values:"
		matrix list plist`i'
		di "Minimum sharpened q-values:"
		matrix list qlist`i'

		estimates dir

		// Need to create another row for FDR q-values for each variable(_N)
		// tabmax will keep track of inputting these in every third row
		local tabmax = 4*_N // multiplying by 4 to keep space row
		local qcount = 1

		// Looping through every third row where FDR q-values will be stored
		forval newcount = 3(4)`tabmax' {
			local q = qlist`i'[`qcount',1]
			pstar, p(`q') pbracket prec(2) pstar
			estadd local thisstat`newcount' = "`r(pstar)'" : col`i'
			local ++qcount
		}
	}
}
// close of FDR calculations


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
	esttab col1 col2 col3 col4 col5 `using', cells(none) booktabs extracols(3) nonotes compress replace ///
	mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Recipient Households}}} & & \multicolumn{1}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Non-Recipient Households}}} & \\   \cline{2-3}\cline{5-5} \\ & \multicolumn{1}{c}{\shortstack{$\mathds{1}(\text{Treat village})$ \\ \vspace{.1cm} \\ Reduced form }}"  "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{Pooled saturation \\ effect}}""\multicolumn{1}{c}{\shortstack{Control, low saturation \\ mean (SD)}}") ///
	stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

end
