
** Defining program to build main table for presentations **
************************************************************
cap program drop table_main_migration
program define table_main_migration
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
	eststo clear
	est drop _all
	set obs `nrows'
	gen x = 1
	gen y = 1

	forvalues x = 1/`ncols' {
		eststo col`x': reg x y
	}

	local varcount = 1
	local count = 1
	local countse = `count'+1
	local countspace = `count' + 2

	if `fdr' == 1 {
		local countse = `count'+1
		local countfdr = `count'+2
		local countspace = `count' + 3
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

		** Find source for variable v **
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

		disp "`source'"

    ** Load dataset **
    use "`source'", clear
    cap gen cons = 1
    cap drop w_*

    ren hh_n hhsize1


    ** set panel and time variables **
    if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
      local timvar = "avgdate_vill"
      local panvar = "village_code"
      if $runGPS == 1 {
        merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", nogen
      }
    }

    if inlist("`source'", "$da/GE_HHLevel_ECMA.dta")  {
      local timvar = "survey_mth"
      local panvar = "hhid"
      if $runGPS == 1 {
        merge 1:1 hhid using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", nogen keep(1 3)
      }
    }

    if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
      local timvar = "date"
      local panvar = "run_id"
      //adjusted time and panel variables according to the main enterprise analysis
      if $runGPS == 1 {
        merge 1:1 entcode_EL using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", nogen keep(1 3)
      }
    }

    if inlist("`source'", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
      local timvar = "survey_mth"
      local panvar = "persid"
      if $runGPS == 1 {
        merge n:1 hhid using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", nogen keep(1 3)
      }
    }


    if !inlist("`v'", "p11_1_frmigrated", "p11_4_migration_nethhchange", "hhsize1") {
      keep if p11_1_frmigrated == 0
    }


		** Label variables **
		ge_label_variables

		** define weight / generate weighted variables **
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
		mata: output_row_b = output_row_b,st_matrix("e(b)")[1,1]
		mata: output_row_se = output_row_se, sqrt(st_matrix("e(V)")[1,1])

		outreg2 `coeftable', `outregopt' `outregset'
		local outregopt "append"

        ** formatting for tex - column 1, indicator for treatment status **
        pstar treat
        estadd local thisstat`count' = "`r(bstar)'": col1
        estadd local thisstat`countse' = "`r(sestar)'": col1


		** 2. Add total treamtment effect on the treated (eligibles) from the 'optimal' spatial regression **
		*****************************************************************************************************
		if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta", "$da/GE_VillageLevel_ECMA.dta") {
			if "`v'"!= "nondurables_exp_wins_PPP" & "`v'" != "h2_1_foodcons_12mth_wins_PPP" & "`v'" != "h2_3_temptgoods_12_wins_PPP" & "`v'" != "durables_exp_wins_PPP" ///
			& "`v'" != "assets_agtools_wins_PPP" & "`v'" != "assets_pot_prod_wins_PPP" & "`v'" != "assets_livestock_wins_PPP" & "`v'" != "assets_prod_nonag_wins_PPP" & "`v'" != "assets_nonprod_wins_PPP" { // for components of consumption or assets, take overall radii
			mata: optr = .,.,.,.,.,.,.,.,.,.

			if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
				  local vrb = subinstr("`v'","_agri","",.)
				  local vrb = subinstr("`vrb'","_nag","",.)
			}
			else {
				local vrb = "`v'"
			}

			forval r = 2(2)20 {
				local r2 = `r' - 2
				ivreg2 `vrb' `blvars' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) [aweight=weight] if sample == 1
				estat ic
				mata: optr[`r'/2] = st_matrix("r(S)")[6]
			}
		}

			mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
			local r = optr
			local r2 = `r' - 2

      if $runGPS == 1 {
        iv_spatial_HAC `v' cons `blvars' [aweight=weight] if sample == 1, en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km) in(treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
			if $runGPS == 0 {
        ivreg2 `v' `blvars' (pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km = treat share_ge_elig_treat_ov_0to2km-share_ge_elig_treat_ov_`r2'to`r'km) [aweight=weight] if sample == 1, cluster(sublocation_code)
      }
      outreg2 `coeftable', `outregopt' `outregset'
        eststo e_ive

			** Get mean total effect on treated eligibles **
			sum pp_actamt_ownvill [weight=weight]  if (sample == 1 & treat == 1)
			local ATEstring_tot = "`r(mean)'" + "*pp_actamt_ownvill"

			foreach vrb of var pp_actamt_ov_0to2km-pp_actamt_ov_`r2'to`r'km {
				sum `vrb' [aweight=weight] if (sample == 1 & treat == 1)
				local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`vrb'"
			}

			disp "`ATEstring_tot'"
			lincom "`ATEstring_tot'"
			mata: output_row_b = output_row_b,st_numscalar("r(estimate)")
			mata: output_row_se = output_row_se,st_numscalar("r(se)")

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
		}

		** 3. Add spillover effects **
		*******************************

		** i. pooled spillover on ineligibles, and eligibles in control villages **
		***************************************************************************
		if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") {
      if "`v'"!= "nondurables_exp_wins_PPP" & "`v'" != "h2_1_foodcons_12mth_wins_PPP" & "`v'" != "h2_3_temptgoods_12_wins_PPP" & "`v'" != "durables_exp_wins_PPP" { // for components of consumption, take consumption radii

			mata: optr = .,.,.,.,.,.,.,.,.,.

      if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
      				local vrb = subinstr("`v'","_agri","",.)
      				local vrb = subinstr("`vrb'","_nag","",.)
      			}

      			else {
      				local vrb = "`v'"
      			}

			local endregs = ""
			local exregs = ""
			forval r = 2(2)20 {
				local r2 = `r' - 2
				local endregs = "`endregs'" + " c.pp_actamt_`r2'to`r'km#eligible"
				local exregs = "`exregs'" + " c.share_ge_elig_treat_`r2'to`r'km#eligible"
				ivreg2 `vrb' (`endregs' = `exregs') eligible `blvars_untreat' [aweight=weight] if (eligible == 0 | treat == 0)
				estat ic
				mata: optr[`r'/2] = st_matrix("r(S)")[6]
			}

			mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
			local rad = optr
			local rad2 = optr - 2

    }

			local endregs = ""
			local exregs = ""
			forval r = 2(2)`rad' {
				local r2 = `r' - 2

				gen pp_actamt_`r2'to`r'km_eligible = pp_actamt_`r2'to`r'km * eligible
				gen pp_actamt_`r2'to`r'km_ineligible = pp_actamt_`r2'to`r'km * ineligible

				gen share_ge_elig_treat_`r2'to`r'km_el = share_ge_elig_treat_`r2'to`r'km * eligible
				gen share_ge_elig_treat_`r2'to`r'km_in = share_ge_elig_treat_`r2'to`r'km * ineligible

				local endregs = "`endregs'" + " pp_actamt_`r2'to`r'km_eligible" + " pp_actamt_`r2'to`r'km_ineligible"
				local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`r'km_el"  + " share_ge_elig_treat_`r2'to`r'km_in"
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
			foreach vrb of var pp_actamt_0to2km-pp_actamt_`rad2'to`rad'km {
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

		}

		** 4. Add mean of dependent variable **
		****************************************
		sum `v' [weight=weight] if treat == 0 & hi_sat == 0

		mata: output_row_b = output_row_b,st_numscalar("r(mean)")
		mata: output_row_se = output_row_se,st_numscalar("r(sd)")

		estadd local thisstat`count' = string(`r(mean)', "%9.2f") : col4
		estadd local thisstat`countse' = "(" + string(`r(sd)', "%9.2f") + ")": col4

		** Add to output table **
		mata: output_table = output_table\output_row_b\output_row_se\(.,.,.,.,.)

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
	stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

end
