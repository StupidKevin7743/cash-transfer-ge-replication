cap program drop spatial_ri_table
program define spatial_ri_table
    syntax using, outcomes(string) reps(integer) postfile(string) [drawnew(integer 0)]

	quietly{
	* setting up blank table *
	drop _all
	local ncols = 4
	local nrows = 10

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


	//local countn = `count'+2

	local varlabels ""
	local statnames ""
	local collabels ""

	}

  cap postclose hh_ris
  postfile hh_ris str34 outcome int(rep radii_total radii_spill) double(ATE_total SE_total ATE_spill SE_spill)  using "`postfile'", replace
  // note -- storing original estimate in 0

	foreach v in `outcomes' {
	//quietly{
        di "Loop for `v'"
		//quietly{
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

    ** set panel and time variables **
    if inlist("`source'", "$da/GE_VillageLevel_ECMA.dta") {
      local timvar = "avgdate_vill"
      local panvar = "village_code"
      if $runGPS == 1 {
        merge 1:1 village_code using "$dr/GE_Village_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
      }
    }

    if inlist("`source'", "$da/GE_HHLevel_ECMA.dta")  {
      local timvar = "survey_mth"
      local panvar = "hhid"
      if $runGPS == 1 {
        merge 1:1 hhid using "$dr/GE_HH_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
      }
    }

    if inlist("`source'", "$da/GE_Enterprise_ECMA.dta") {
      local timvar = "date"
      local panvar = "run_id"
      //adjusted time and panel variables according to the main enterprise analysis
      if $runGPS == 1 {
        merge 1:1 entcode_EL using "$dr/GE_ENT_GPS_Coordinates_RESTRICTED.dta", keep(1 3) nogen
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
        ** adding variable label to the table **
        local add : var label `v'
        local collabels `"`collabels' "`add'""'


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

        local savevars "*`v'*"

		** 1 First column: total treamtment effect on the treated (eligibles) from the 'optimal' spatial regression **
		*****************************************************************************************************
    if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") { //,  {
      ** for consumption, use overall consumption
          if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
            calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if sample == 1, elig quietly // no bl vars
            local savevars "`savevars' p2_consumption_wins_PPP*"
          }
        ** for assets, use total assets
        else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
          calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if sample == 1, elig blvars("`blvars'") quietly // no bl vars
          local savevars "`savevars' p1_assets_wins_PPP*"
        }
        ** for hours or salary by ag/non-ag, use overall
      else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
        local vrb = subinstr("`v'","_agri","",.)
        local vrb = subinstr("`v'","_nag","",.)
        calculate_optimal_radii `vrb' [aweight=weight] if sample == 1, elig quietly // no baseline vars for individual obs
        local savevars "`savevars' `vrb'"
      }
      ** for all others -- use variable
      else {
        calculate_optimal_radii `v' [aweight=weight] if sample == 1, elig blvars("`blvars'") quietly
      }
    }
    ** village- level **
    else if inlist("`source'","$da/GE_VillageLevel_ECMA.dta") {
        calculate_optimal_radii `v' [aweight=weight] if sample == 1, vill blvars("`blvars'") quietly
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

      if $runGPS == 1 {
        iv_spatial_HAC `v' cons `blvars' [aweight=weight] if sample == 1, en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
			if $runGPS == 0 {
        ivreg2 `v' `blvars' (`endregs' = `exregs') [aweight=weight] if sample == 1, cluster(sublocation_code)
      }

      ** Get mean total effect on treated eligibles - loop through endogenous regressors **
      local ATEstring_tot = "0"
      foreach var of local endregs {
        sum `var' [weight=weight]  if (sample == 1 & treat == 1)
  			local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`var'"
      }

			disp "`ATEstring_tot'"
			lincom "`ATEstring_tot'"

			loc total_t = abs(`r(estimate)' / `r(se)')
      local total_est = `r(estimate)'
      local total_se = `r(se)'
      local radii_total = `r'

        pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col1
			estadd local thisstat`countse' = "`r(sestar)'": col1


		** 2. Add spillover effects **
		*******************************
    *** Calculating optimal radii for non-recipient households***
    if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") { //,  {
      ** for consumption, use overall consumption
          if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
            calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec quietly // no bl vars
          }
        ** for assets, use total assets
        else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
          calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'") quietly
        }
        ** for hours or salary by ag/non-ag, use overall
      else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
        local vrb = subinstr("`v'","_agri","",.)
        local vrb = subinstr("`v'","_nag","",.)
        calculate_optimal_radii `vrb' [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec quietly // no baseline vars for individual obs
      }
      ** for all others -- use variable
      else {
        calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'") quietly
      }
    }
    ** village-level
    else if inlist("`source'","$da/GE_VillageLevel_ECMA.dta") {
        calculate_optimal_radii `v' [aweight=weight] if sample == 1, vill blvars("`blvars'") quietly
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

        local endregs = "`endregs'" + " pp_actamt_`r2'to`r'km_eligible" + " pp_actamt_`r2'to`r'km_ineligible"
        local exregs = "`exregs'" + " share_ge_elig_treat_`r2'to`r'km_el"  + " share_ge_elig_treat_`r2'to`r'km_in"

        local amount_list = "`amount_list' pp_actamt_`r2'to`rad'km"
      }

      if $runGPS == 1 {
        iv_spatial_HAC `v' cons eligible `blvars_untreat' [aweight=weight] if (eligible == 0 | treat == 0), en(`endregs') in(`exregs') lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar
      }
      if $runGPS == 0 {
        ivreg2 `v' eligible `blvars_untreat' (`endregs' = `exregs') [aweight=weight] if (eligible == 0 | treat == 0), cluster(sublocation_code)
      }

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
      di "`ATEstring_spillover'"
			lincom "`ATEstring_spillover'"

      loc spill_t = abs(`r(estimate)' / `r(se)')
      local spill_est = `r(estimate)'
      local spill_se = `r(se)'
      local radii_spill = `r'

      pstar, b(`r(estimate)') se(`r(se)')
			estadd local thisstat`count' = "`r(bstar)'": col3
			estadd local thisstat`countse' = "`r(sestar)'": col3


      * posting original results
      post hh_ris ("`v'") (0) (`radii_total') (`radii_spill') (`total_est') (`total_se') (`spill_est') (`spill_se')


      ** only keeping variables needed for RI part **
      keep `savevars' cons eligible ineligible weight sample village_code `timvar' `panvar'


		tempfile sourcedata
		save `sourcedata'

		//}

		** NOW: start RI
		****************************************

		loc total_count = 0
		loc spill_count = 0

		di ""
		_dots 0, title(Spatial RI running for `v') reps(`reps')

		forvalues rep = 1/`reps'{

		quietly{

			use `sourcedata', clear

			capture confirm file "$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta"

			if `drawnew' == 1 | _rc == 601{ // if we specified we'd draw a new one or the current draw does not exist, draw a new one
        di "Drawing allocation `rep'"
        set seed 20191031
        set sortseed 20191031
				draw_alloc, outdir("$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta") rep(`rep')
			}

      ** Bringing in new treatment statuses
      			merge n:1 village_code using "$dt/spatial_ri_draws/ri_allocation_draw`rep'.dta", nogen

      ren ri_pp_actamt_ownvill      pp_actamt_ownvill
      ren ri_pp_actamt_ov_*to*km    pp_actamt_ov_*to*km
      ren ri_pp_actamt_*to*km       pp_actamt_*to*km
      ren ri_treat                  treat
      ren ri_share_treat_ov_*to*km  share_ge_elig_treat_ov_*to*km
      ren ri_share_treat_*to*km     share_ge_elig_treat_*to*km

			**************
			* Total
			**************
      ** calculate optimal radii - for subcomponents of an index, we use the overall index
      ** household-level **
      if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") { //,  {
        ** for consumption, use overall consumption
            if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
              calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if sample == 1, elig quietly // no bl vars
            }
          ** for assets, use total assets
          else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
            calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if sample == 1, elig blvars("`blvars'") quietly // no bl vars
          }
          ** for hours or salary by ag/non-ag, use overall
        else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
          local vrb = subinstr("`v'","_agri","",.)
          local vrb = subinstr("`v'","_nag","",.)
          calculate_optimal_radii `vrb' [aweight=weight] if sample == 1, elig quietly // no baseline vars for individual obs
        }
        ** for all others -- use variable
        else {
          calculate_optimal_radii `v' [aweight=weight] if sample == 1, elig blvars("`blvars'") quietly
        }
      }
      ** village- level **
      else if inlist("`source'","$da/GE_VillageLevel_ECMA.dta") {
          calculate_optimal_radii `v' [aweight=weight] if sample == 1, vill blvars("`blvars'") quietly
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

        ivreg2 `v' (`endregs' = `exregs') `blvars' [aweight=weight] if sample == 1

        ** Get mean total effect on treated eligibles - loop through endogenous regressors **
        local ATEstring_tot = "0"
        foreach var of local endregs {
          sum `var' [weight=weight]  if (sample == 1 & treat == 1)
          local ATEstring_tot = "`ATEstring_tot'" + "+" + "`r(mean)'" + "*" + "`var'"
        }

        disp "`ATEstring_tot'"
        lincom "`ATEstring_tot'"

        local ATE_total = `r(estimate)'

      * point estimate version
      if abs(`r(estimate)') > abs(`total_est') loc ++total_count
      * if using t-test
      //if abs(`r(estimate)' / `r(se)') > `total_t' loc total_count = `total_count' + 1

      macro drop r

			**************
			* Spillover
			**************
      *** Calculating optimal radii for non-recipient households***
      if inlist("`source'", "$da/GE_HHLevel_ECMA.dta", "$da/GE_HHIndividualWageProfits_ECMA.dta") { //,  {
        ** for consumption, use overall consumption
            if inlist("`v'", "nondurables_exp_wins_PPP", "h2_1_foodcons_12mth_wins_PPP", "h2_3_temptgoods_12_wins_PPP", "durables_exp_wins_PPP") {
              calculate_optimal_radii p2_consumption_wins_PPP [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec quietly // no bl vars
            }
          ** for assets, use total assets
          else if inlist("`v'", "assets_agtools_wins_PPP", "assets_pot_prod_wins_PPP", "assets_livestock_wins_PPP", "assets_prod_nonag_wins_PPP", "assets_nonprod_wins_PPP") {
            calculate_optimal_radii p1_assets_wins_PPP [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'") quietly
          }
          ** for hours or salary by ag/non-ag, use overall
        else if inlist("`v'","emp_hrs_agri", "emp_hrs_nag", "emp_cshsal_perh_agri_winP", "emp_cshsal_perh_nag_winP") {
          local vrb = subinstr("`v'","_agri","",.)
          local vrb = subinstr("`v'","_nag","",.)
          calculate_optimal_radii `vrb' [aweight=weight] if (eligible == 0 | treat == 0), hhnonrec quietly // no baseline vars for individual obs
        }
        ** for all others -- use variable
        else {
          calculate_optimal_radii `v' [aweight=weight] if  (eligible == 0 | treat == 0), hhnonrec  blvars("`blvars_untreat'") quietly
        }
      }
      ** village-level
      else if inlist("`source'","$da/GE_VillageLevel_ECMA.dta") {
          calculate_optimal_radii `v' [aweight=weight] if sample == 1, vill blvars("`blvars'") quietly
        }
        else {
          di "Error: not a valid source"
          stop
        }

        local r=r(r_max)

      local radii_spill = `r'

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

      ivreg2 `v' (`endregs' = `exregs') eligible [aweight=weight] if (eligible == 0 | treat == 0)


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

			lincom "`ATEstring_spillover'"
      local ATE_spill = `r(estimate)'

      * point estimate version
      if abs(`r(estimate)') > abs(`spill_est') loc ++spill_count
      * t-stat version
			//if abs(`r(estimate)' / `r(se)') > `spill_t' loc spill_count = `spill_count' + 1

			//}

      * adding to post file -- not reporting SEs since not from conley
      post hh_ris ("`v'") (`rep') (`radii_total') (`radii_spill') (`ATE_total') (.) (`ATE_spill') (.)

    }
    // end quietly
        	_dots `rep' 0

	}
    // end loop over reps

    loc total_p = `total_count' / `reps'
		loc spill_p = `spill_count' / `reps'

		 pstar, p(`total_p') pstar pbrackets
			estadd local thisstat`count' = "`r(pstar)'": col2

		 pstar, p(`spill_p') pstar pbrackets
			estadd local thisstat`count' = "`r(pstar)'": col4


		** looping variables for tex table **
		local thisvarlabel: variable label `v'

		local varlabels `"`varlabels' "`thisvarlabel'" " " " " "'
		local statnames "`statnames' thisstat`count' thisstat`countse' thisstat`countspace'"


		local count = `count' + 3
		local countse = `count' + 1
		local countspace = `count' + 2




		local ++varcount

	}
    // end loop over outcomes


postclose hh_ris

    // end loop through outcomes
    di "End outcome loop"


    *** exporting tex table ***
    ** dropping column 2 **
	loc prehead "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{l*{6}{S}}\toprule"
	loc postfoot "\bottomrule\end{tabular}}"

  if $runGPS == 0 {
    local note "SEs NOT calculated as in the paper. In table, clustering at the sublocation level rather than using spatial SEs (as in paper)."
  }


  di "Exporting tex file"
	esttab col1 col2 col3 col4 `using', cells(none) booktabs extracols(3) nonotes compress replace ///
	mlabels("\multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Recipient Households}}} & & \multicolumn{2}{c}{\shortstack{ \vspace{.2cm} \\ \textbf{Non-recipient Households}}} & \\   \cline{2-3}\cline{5-6} \\ & \multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Spatial RI \\ \vspace{.1cm} \\ \emph{p}-value}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Total Effect \\ \vspace{.1cm} \\ IV}}" "\multicolumn{1}{c}{\shortstack{$\phantom{(}$ Spatial RI \\ \vspace{.1cm} \\ \emph{p}-value}}") ///
	stats(`statnames', labels(`varlabels')) note("`note'") prehead(`prehead') postfoot(`postfoot')

end
