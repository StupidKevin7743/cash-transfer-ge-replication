/*
 * Filename: ent_sector_stats.do
 * Description: This do file classifies enterprises into sectors (retail, manufacturing, services and ag), then generates tables based on this classification.
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


 /********** CLASSIFYING ENTERPRISES ****************/
project, original("$da/GE_Enterprise_ECMA.dta")
 use "$da/GE_Enterprise_ECMA.dta", clear



** how does it look if we consider tailoring, cobbler as services instead of manufacturing? **
replace sector = 2 if inlist(bizcat, 15) | inlist(bizcat_nonfood, 6)

tab bizcat if sector == .

tab sector

***** DESCRIPTIVE STATS TABLE *****
gen rev_weight_EL = ent_revenue2_wins_PPP * entweight_EL



preserve

* overall
summ entweight_EL
loc totent = `r(sum)'

sum rev_weight_EL
loc totrev = `r(sum)'

* non-ag
summ entweight_EL if sector != 4
loc nonagent = `r(sum)'

sum rev_weight_EL if sector != 4
loc nonagrev = `r(sum)'

***********************************************
*** TABLE: REVENUE SHARES BY Sector         ***
***********************************************

texdoc init "$dtab/TableG1_Ent_SectorStats.tex", replace force
tex \begin{tabular}{lcccc} \toprule \\
tex  & \multicolumn{2}{c}{\textbf{Overall}} & \multicolumn{2}{c}{\textbf{Non-Ag}} \\
tex Sector & Count Share & Revenue Share & Count Share & Revenue Share \\ \hline
forval i = 1 / 4 {
    return clear
    * extract label
    loc lab : label (sector) `i'

    * ent count local
    summ entweight_EL if sector == `i'
    loc secshare_ent = `r(sum)' / `totent'
    if `i' < 4 {
        loc nonagshare_ent = `r(sum)'/ `nonagent'
    }

    * rev share local
    summ rev_weight_EL if sector == `i'
    loc secshare_rev = `r(sum)'/ `totrev'
    if `i' < 4 {
        loc nonagshare_rev = `r(sum)' / `nonagrev'
    }

    loc c1 = proper("`lab'")
    loc c2 = string(`secshare_ent', "%9.2fc")
    loc c3 = string(`secshare_rev', "%9.2fc")
    loc c4 = string(`nonagshare_ent', "%9.2fc")
    loc c5 = string(`nonagshare_rev', "%9.2fc")

    if `i' == 4 {
        loc c4 = ""
        loc c5 = ""
    }
        tex `c1' & `c2' & `c3' & `c4' & `c5' \\

    macro drop c1 c2 c3 c4 c5 secshare_ent secshare_rev nonagshare_ent nonagshare_rev
}
//tex \hline
loc totent = string(`totent', "%9.0fc")
di "`totent'"
loc totrev = string(`totrev', "%9.0fc")

//tex Totals & `totent' & `totrev' \\ \bottomrule
tex \end{tabular}
texdoc close


******************************************************
*** TABLE: DETAILED REVENUE SHARES BY Sector       ***
******************************************************

*** Manufacturing SECTOR ***
tab bizcat if sector == 2
tab bizcat if sector == 2, nol

gen bizcat_present = bizcat
replace bizcat_present = 40 if bizcat_present == 30

tab bizcat_present if sector == 2
la val bizcat_present bizcat


summ entweight_EL if sector == 2
loc totent = `r(sum)'

sum rev_weight_EL if sector == 2
loc totrev = `r(sum)'

levelsof bizcat_present if sector == 2, local(manu_codes)

* Table of Manufacturing Business Summ Stats
/*
texdoc init "$dtab/manu_sectorsummstats.tex", replace force
tex \begin{tabular}{lcc} \toprule \\
tex Type & Count Share & Revenue Share \\ \hline

    local i = 1
    foreach type of local manu_codes {
        summ entweight_EL if sector == 2 & bizcat_present == `type'
        loc typeshare_count`i' = `r(sum)' / `totent'

        summ rev_weight_EL if sector == 2 & bizcat_present == `type'
        loc typeshare_rev`i' = `r(sum)'/ `totrev'


        loc typeshare_lab`i' : label (bizcat_present) `type'

        di "`typeshare_lab`i'' `typeshare_rev`i''"

        loc c1 = proper("`typeshare_lab`i''")
        loc c2 = string(`typeshare_count`i'', "%9.2fc")
        loc c3 = string(`typeshare_rev`i'', "%9.2fc")

        tex `c1' & `c2' & `c3' \\

        macro drop c1 c2 c3 c4 c5 typeshare_lab`i' typeshare_rev`i' typeshare_count`i'

        local ++i
    }


tex \bottomrule \end{tabular}
texdoc close
*/

project, creates("$dtab/TableG1_Ent_SectorStats.tex")
