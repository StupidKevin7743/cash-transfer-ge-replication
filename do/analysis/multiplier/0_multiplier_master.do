/*** master file that constructs multiplier data and tables ***/

/* do file header */
return clear
capture project, doinfo
if (_rc==0 & !mi(r(pname))) global dir `r(pdir)'  // using -project-
else {  // running directly
    if ("${ge_dir}"=="") do `"`c(sysdir_personal)'profile.do"'
    do "${ge_dir}/do/set_environment.do"
}

* Import config - running globals
project, original("$dir/do/GE_global_setup.do")
include "$dir/do/GE_global_setup.do"

// end preliminaries

***************************
*** 1. Data Construction **
***************************

** Creates important globals used later on,
* as well as Tables D1 and D2: Durable and Non-Durable Input and Import Shares
project, do("$do/analysis/multiplier/ImportShares_globals_TablesD1_D2.do")


** Construct data for Table 5, with wild bootstrapped standard errors
* also creates IRF values for multiplier figure
project, do("$do/analysis/multiplier/multiplier_wildboot_deflated.do")

** Construct data that includes Rarieda, with wild bootstrapped standard errors
project, do("$do/analysis/multiplier/multiplier_wildboot_deflated_inclRarieda.do")

** Construct data for Table D.6, with wild bootstrapped standard errors
project, do("$do/analysis/multiplier/multiplier_wildboot_nominal.do")

** Construct data that drops Q1-Q3, with wild bootstrapped standard errors
project, do("$do/analysis/multiplier/multiplier_wildboot_deflated_q4-q10.do")


***************************
***  2. Table Creation   **
***************************
** Compiles previously constructed data sets
project, do("$do/analysis/multiplier/multiplier_compiledata.do")

** This file creates the following multiplier tables in the paper:
* Table 5: Transfer Multiplier Estimates
* Table D.3: Transfer Multiplier Estimates - Adjusting for Imported Intermediates
* Table D.4: Transfer Multiplier - Alternative Assumptions for the Initial Spending Impact
* Table D.5: Transfer Multipliers including Rarieda data, adjusting for imported intermediates
* Table D.6: Nominal Transfer Multiplier
project, do("$do/analysis/multiplier/multiplier_tables.do")
