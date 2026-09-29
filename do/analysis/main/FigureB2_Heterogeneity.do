/*
 * Filename: FigureB2_Heterogeneity.do
 * Description: This do file produces heterogeneity graphs for pre-specified heterogeneous effects and additional heterogeneous effects for the eligibles, and heterogeneous effects for the ineligibles.
 */
 * still lots of stuff that's commented out here - think it's no longer necessary, cut and reference previous file.

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


** setting up dataset **
project, original("$da/GE_HHLevel_ECMA.dta")
use "$da/GE_HHLevel_ECMA.dta", clear
keep if eligible == 1 // only keeping eligible households for this analysis



set scheme tufte
local graphfont "Palatino"
graph set eps fontface `graphfont'
graph set eps
graph set window fontface `graphfont'
graph set window fontfaceserif `graphfont'
graph set window


*** Generate groups of variables ***
local f_primary "p1_assets_wins_PPP p2_consumption_wins_PPP p3_totincome_wins_PPP p4_totrevenue_wins_PPP p5_psych_index p6_healthstatus p7_eduindex_all p8_femaleempower_index_s18 p9_foodindex p10_hrsworked"
local f_primary_ancova "p1_assets_wins_PPP p3_totincome_wins_PPP p4_totrevenue_wins_PPP p5_psych_index p9_foodindex"


*** Generate interaction terms & labels ***
gen int_female=treat*female_BL
la var int_female "Female Respondent"

gen int_age25up=treat*age25up_BL
la var int_age25up "Age >=25"

gen int_married=treat*married_BL
la var int_married "Married"

gen int_stdsch=treat*stdschool_BL
la var int_stdsch "Completed Primary School"

gen int_children=treat*haschildhh_BL
la var int_children "Child in HH"

gen int_highpsych=treat*highpsych_BL
la var int_highpsych "High Psych Well-Being"

gen int_selfemp=treat*selfemp_BL
la var int_selfemp "Self-Employed"

gen int_emp=treat*emp_BL
la var int_emp "Wage Employment"

loc hetvars "female_BL age25up_BL married_BL stdschool_BL haschildhh_BL highpsych_BL selfemp_BL emp_BL"


*** Generate control means and s.d. ***
loc i = 1
foreach var of local f_primary{
if `i' < 5{
sum `var' if treat ==0 & hi_sat == 0 [aw=hhweight_EL]
			loc m`i' = string(r(mean), "%10.0f")
			loc sd`i' = string(r(sd), "%10.0f")
}
else if `i'==10 {
sum `var' if treat ==0 & hi_sat == 0 [aw=hhweight_EL]
			loc m`i' = string(r(mean), "%10.1f")
			loc sd`i' = string(r(sd), "%10.1f")
}
else {
sum `var' if treat ==0 & hi_sat == 0 [aw=hhweight_EL]
			loc m`i' = string(r(mean), "%10.2f")
			loc sd`i' = string(r(sd), "%10.2f")
}
loc ++i
}


loc i = 1
foreach het of local hetvars{
sum `het'
			loc mhet`i' = string(r(mean), "%10.2f")
loc ++i
}



sum treat
loc mtreat = string(r(mean), "%10.2f")




*** Generate graphs ***

** postfile for fdr corrections across all primary outcomes
cap postclose fdr_p
postfile fdr_p str30 variable double(pval beta se) obs using "$dt/fdr_p.dta", replace


** postfile for fdr corrections for each dimension of heterogeneity **
postfile fdr_h_fem str30 variable double(pval beta se) obs using "$dt/fdr_h_fem.dta", replace
postfile fdr_h_age str30 variable double(pval beta se) obs using "$dt/fdr_h_age.dta", replace
postfile fdr_h_mar str30 variable double(pval beta se) obs using "$dt/fdr_h_mar.dta", replace
postfile fdr_h_std str30 variable double(pval beta se) obs using "$dt/fdr_h_std.dta", replace
postfile fdr_h_child str30 variable double(pval beta se) obs using "$dt/fdr_h_child.dta", replace
postfile fdr_h_psy str30 variable double(pval beta se) obs using "$dt/fdr_h_psy.dta", replace
postfile fdr_h_self str30 variable double(pval beta se) obs using "$dt/fdr_h_self.dta", replace
postfile fdr_h_emp str30 variable double(pval beta se) obs using "$dt/fdr_h_emp.dta", replace


loc i = 1
foreach var of local f_primary {
	if strpos("`f_primary_ancova'", "`var'") > 0 {
		local blvars "M`var'_BL `var'_BL"
	}
	else {
		local blvars ""
	}
	if strpos("p8_femaleempower_index_s18", "`var'") > 0 {
	//we've only estimated p8... for females, so no het effect along the gender dimension

	eststo normal`i': reg `var' treat hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	// adding outcomes to primary outcome FDR corrections
	test treat
	local pval = `r(p)'
	local b`i' = string(_b[treat], "%10.2f")
	local se`i' = string(_se[treat], "%10.2f")
	post fdr_p ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo age25up`i': 	reg `var' age25up_BL treat int_age25up hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_age25up
	local pval = `r(p)'
	post fdr_h_age ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo married`i': reg `var' married_BL treat int_married hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_married
	local pval = `r(p)'
	post fdr_h_mar ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

    eststo stdsch`i': reg `var' stdschool_BL treat int_stdsch hi_sat	`blvars' [aw=hhweight_EL], cluster(village_code)
	test int_stdsch
	local pval = `r(p)'
	post fdr_h_std ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo children`i': reg `var' haschildhh_BL treat int_children hi_sat	`blvars' [aw=hhweight_EL], cluster(village_code)
	test int_children
	local pval = `r(p)'
	post fdr_h_child ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

    eststo highpsych`i': reg `var' highpsych_BL treat int_highpsych hi_sat	`blvars' [aw=hhweight_EL], cluster(village_code)
	test int_highpsych
	local pval = `r(p)'
	post fdr_h_psy ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo selfemp`i': 	reg `var' selfemp_BL treat int_selfemp hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_selfemp
	local pval = `r(p)'
	post fdr_h_self ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo emp`i': 	reg `var' emp_BL treat int_emp hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_emp
	local pval = `r(p)'
	post fdr_h_emp ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')
	}

	else{
	eststo normal`i': reg `var' treat hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test treat
	local pval = `r(p)'
	if `i' < 5{
	local b`i' = string(_b[treat], "%10.0f")
	local se`i' = string(_se[treat], "%10.0f")
	}
	else if `i'==10 {
	local b`i' = string(_b[treat], "%10.1f")
	local se`i' = string(_se[treat], "%10.1f")
	}
	else {
	local b`i' = string(_b[treat], "%10.2f")
	local se`i' = string(_se[treat], "%10.2f")
	}
	post fdr_p ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo female`i': reg `var' female_BL treat int_female hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_female
	local pval = `r(p)'
	post fdr_h_fem ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo age25up`i': 	reg `var' age25up_BL treat int_age25up hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_age25up
	local pval = `r(p)'
	post fdr_h_age ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo married`i': reg `var' married_BL treat int_married hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_married
	local pval = `r(p)'
	post fdr_h_mar ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

    eststo stdsch`i': reg `var' stdschool_BL treat int_stdsch hi_sat	`blvars' [aw=hhweight_EL], cluster(village_code)
	test int_stdsch
	local pval = `r(p)'
	post fdr_h_std ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo children`i': reg `var' haschildhh_BL treat int_children hi_sat	`blvars' [aw=hhweight_EL], cluster(village_code)
	test int_children
	local pval = `r(p)'
	post fdr_h_child ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

    eststo highpsych`i': reg `var' highpsych_BL treat int_highpsych hi_sat	`blvars' [aw=hhweight_EL], cluster(village_code)
	test int_highpsych
	local pval = `r(p)'
	post fdr_h_psy ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo selfemp`i': 	reg `var' selfemp_BL treat int_selfemp hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_selfemp
	local pval = `r(p)'
	post fdr_h_self ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')

	eststo emp`i': 	reg `var' emp_BL treat int_emp hi_sat `blvars' [aw=hhweight_EL], cluster(village_code)
	test int_emp
	local pval = `r(p)'
	post fdr_h_emp ("`var'") (`pval') (_b[treat]) (_se[treat]) (`e(N)')
	}

 loc ++i

 }

 *** closing post files ***
 postclose fdr_p
 postclose fdr_h_fem
 postclose fdr_h_age
 postclose fdr_h_mar
 postclose fdr_h_std
 postclose fdr_h_child
 postclose fdr_h_psy
 postclose fdr_h_self
 postclose fdr_h_emp


 **** Adding FDR q-values back into the models
 tempfile maindata
	save `maindata'

		drop _all
		use "$dt/fdr_p.dta"
		mkmat pval, matrix(plist)
    matrix list plist
    minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest normal`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): normal`newcount'
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_fem.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			if `newcount' != 8 {
			est rest female`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): female`newcount'
			}
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_age.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest age25up`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): age25up`newcount'
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_mar.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest married`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): married`newcount'
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_std.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest stdsch`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): stdsch`newcount'
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_child.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest children`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): children`newcount'
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_psy.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest highpsych`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): highpsych`newcount'
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_self.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest selfemp`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): selfemp`newcount'
			local ++qcount

		}

		drop _all
		use "$dt/fdr_h_emp.dta"
		mkmat pval, matrix(plist)
		minq plist, q(qlist) step(0.001)

		** adding back into the table
		estimates dir

		local tabmax = _N // last row with FDR q-values
		local qcount = 1
		forval newcount=1(1)`tabmax' {
			local q = qlist[`qcount',1]
			est rest emp`newcount'
			mat A = e(b)
			local cols = colsof(A)
			estadd matrix qval = J(1, `cols',`q'): emp`newcount'
			local ++qcount

		}



*** COMBINE GRAPHS full version ***
coefplot (normal1, msymbol(O) offset(0) keep(treat)) ///
		(female1, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up1,  msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married1, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch1, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children1, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych1, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp1, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp1, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Assets}" "`m1' (`sd1')") ///
		|| (normal2, msymbol(O) offset(0) keep(treat)) ///
		(female2, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up2, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married2, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch2, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children2, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych2, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp2, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp2, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Expenditure}" "`m2' (`sd2')") ///
		|| (normal3, msymbol(O) offset(0) keep(treat)) ///
		(female3, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up3, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married3, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch3, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children3, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych3, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp3, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp3, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Income}" "`m3' (`sd3')") ///
		|| (normal4, msymbol(O) offset(0) keep(treat)) ///
		(female4, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up4, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married4, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch4, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children4, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych4, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp4, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp4, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Revenue}" "`m4' (`sd4')") ///
		|| (normal5, msymbol(O) offset(0) keep(treat)) ///
		(female5, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up5, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married5, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch5, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children5, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych5, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp5, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp5, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Psych Well-Being}" "{bf:Index}" "`m5' (`sd5')") ///
		|| (normal6, msymbol(O) offset(0) keep(treat)) ///
		(female6, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up6, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married6, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch6, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children6, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych6, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp6, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp6, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Health Index}" "`m6' (`sd6')") ///
		|| (normal7, msymbol(O) offset(0) keep(treat)) ///
		(female7, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up7, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married7, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch7, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children7, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych7, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp7, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp7, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Education Index}" "`m7' (`sd7')") ///
		|| (normal8, msymbol(O) offset(0) keep(treat)) ///
		(age25up8, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married8, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch8, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children8, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych8, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp8, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp8, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Female Empowerment}" "{bf:Index}" "`m8' (`sd8')") ///
		|| (normal9, msymbol(O) offset(0) keep(treat)) ///
		(female9, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up9, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married9, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch9, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children9, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych9, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp9, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp9, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Food Security}" "{bf:Index}" "`m9' (`sd9')") ///
		|| (normal10, msymbol(O) offset(0) keep(treat)) ///
		(female10, msymbol(O) mfcolor(white) offset(0) keep(int_female)) ///
		(age25up10, msymbol(O) mfcolor(white) offset(0) keep(int_age25up)) ///
		(married10, msymbol(O) mfcolor(white) offset(0) keep(int_married)) ///
		(stdsch10, msymbol(O) mfcolor(white) offset(0) keep(int_stdsch)) ///
		(children10, msymbol(O) mfcolor(white) offset(0) keep(int_children)) ///
		(highpsych10, msymbol(O) mfcolor(white) offset(0) keep(int_highpsych)) ///
		(selfemp10, msymbol(O) mfcolor(white) offset(0) keep(int_selfemp)) ///
		(emp10, msymbol(O) mfcolor(white) offset(0) keep(int_emp)), bylabel("{bf:Hours Worked}" "`m10' (`sd10')") ///
		||, vertical byopts(compact cols(1) yrescale legend(off)) ///
		yline(0, lcolor(gs7) lwidth(thin) lpattern(dash)) subtitle(, nobox size(medsmall) pos(9) margin(0 30 0 0) justification(left)) ///
		xtitle("Treatment Interaction with Baseline Covariate", margin(24 0 0 2) size(small)) aux(qval) ///
		coeflabels(treat=`""{bf:Treatment}" "{bf:Village}" " "(`mtreat')"' int_female=`""{bf:Female}" "{bf:Respondent}" " "(`mhet1')"' int_age25up= `""{bf:Age >=25}" " " " "(`mhet2')"' int_married= `""{bf:Married}" " " " " "(`mhet3')""' int_stdsch=`""{bf:Completed}" "{bf:Primary}" "{bf:School}" "(`mhet4')""' int_children=`""{bf:Child}" "{bf:in HH}" " " "(`mhet5')""' int_highpsych=`""{bf:High}" "{bf:Psych}" "{bf:Well-Being}" "(`mhet6')""' int_selfemp=`""{bf:Self}" "{bf:Employed}" " " "(`mhet7')""' int_emp=`""{bf:Wage}" "{bf:Employment}" " "(`mhet8')"', tlcolor(none) labsize(medsmall)) ///
		ylabel(#2, labsize(medsmall)) mlabel(cond(@aux1<.01, "***", cond(@aux1<.05, "**", cond(@aux1<.1, "*", "")))) mlabsize(medlarge) levels(95) name(g_het)
        graph export "$dfig/FigureB2_hetgraph_eligibles_full.pdf", as(pdf) replace
