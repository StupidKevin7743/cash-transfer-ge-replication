/*
 * Filename: importshare_table
 * Description: This .do file calculates the upper bounds for intermediate input shares for each
 * non-durable and durable consumption good
 * Date created: 14 December 2020
 *
 */

/* Preliminaries */
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

* load commands
project, original("$do/programs/run_ge_build_programs.do")
include "$do/programs/run_ge_build_programs.do"


**************************************************************
** Step 1 - Get Intermediate Goods Share by enterprise type **
**************************************************************

project, original("$da/GE_Enterprise_ECMA.dta")
use "$da/GE_Enterprise_ECMA.dta", clear

** Define fine business categories **
decode bizcat, gen(bizcat_str)

** Fix non-food producers and vendors **
decode bizcat_nonfood, gen(bizcat_nonfood_str)
replace bizcat_str = "Non-food - " + bizcat_nonfood_str if inlist(bizcat_str,"Non-Food Producer","Non-Food Vendor")

tab bizcat_str

** Generate revenue shares for each enterprise type **
******************************************************
gen tot_revenue = .
levelsof bizcat_str, loc(bizcats)
foreach cat in `bizcats' {
	sum ent_revenue2_wins_PPP [aweight=entweight_EL] if bizcat_str == "`cat'"
	replace tot_revenue = `r(mean)' * `r(sum_w)' if bizcat_str == "`cat'"
}
bys bizcat_str: gen b = tot_revenue if _n == 1
egen c = sum(b)
gen share_revenue = tot_revenue / c
drop b c

** Now generate intermediate goods shares **
********************************************
gen int_share = 1 - (ent_profit2 + ent_totcost)/ent_revenue2
winsor2 int_share, cuts(1 99) suffix(_wins) by(bizcat_str)

** Now take revenue-weighted share in each business category **
gen entweight_rev_EL = entweight_EL * ent_revenue2_wins_PPP

cap log close
log using "$dtab/../intermediate_shares_by_sector", replace
qui: levelsof sector, local(secs)

disp "Intermediate goods shares by sector: "
foreach s in `secs' {
	qui: sum int_share_wins [aweight = entweight_rev_EL] if sector == `s'
	local sec : label (sector)`s'
	local m: di %3.0f 100*`r(mean)'
	disp "`sec' Intermediate Share: `m'%"
}
log close

bys bizcat_str: egen a_int_share_wins = wtmean(int_share_wins), weight(entweight_rev_EL)
collapse a_int_share_wins share_revenue tot_revenue, by(bizcat_str)
ren a_* *
gen int_share_wins_clean = max(int_share_wins,0)

** Add local and import categories **
drop if bizcat_str == ""
insobs 2
replace bizcat_str = "Import" if _n == _N-1
replace bizcat_str = "Local" if _n == _N


**********************************************************
** Step 2 - Assume Share of Intermediate Goods Imported **
**********************************************************
project, original("$dr/IntermediateImportAssumptions_intimports.dta") preserve
merge 1:1 bizcat_str using "$dr/IntermediateImportAssumptions_intimports.dta"
tab bizcat_str if _merge == 2
drop if _merge == 2
drop _merge

ren intermediate_import_share int_import_share
gen import_share = int_share_wins_clean * int_import_share

tempfile intshares
save `intshares', replace


***************************************************************
** Step 3 - Match expenditure items to enterprise categories **
***************************************************************

** A - Non-durable expenditure **
*********************************
project, original("$da/GE_HHLevel_ECMA.dta")
use "$da/GE_HHLevel_ECMA.dta", clear

drop share_*

foreach v of var s12_q1_cerealsamt_12mth s12_q1_rootsamt_12mth s12_q1_pulsesamt_12mth s12_q1_vegamt_12mth s12_q1_meatamt_12mth s12_q1_fishamt_12mth s12_q1_dairyeggsamt_12mth s12_q1_othanimalamt_12mth s12_q1_oilamt_12mth s12_q1_fruitsamt_12mth s12_q1_sugaramt_12mth s12_q1_sweetsamt_12mth s12_q1_softdrinksamt_12mth s12_q1_spicesamt_12mth s12_q1_foodoutamt_12mth s12_q1_foodothamt_12mth h2_3_temptgoods_12 ///
s12_q19_airtimeamt_12mth s12_q20_internetamt_12mth s12_q21_travelamt_12mth s12_q22_gamblingamt_12mth s12_q25_personalamt_12mth s12_q23_clothesamt_12mth s12_q26_hhitemsamt_12mth s12_q27_firewoodamt_12mth s12_q28_electamt_12mth s12_q29_wateramt_12mth ///
s12_q24_recamt_12mth s12_q33_religiousamt s12_q34_charityamt s12_q35_weddingamt s12_q38_dowryamt ///
h2_5_educexp s12_q30_rentamt h2_6_medicalexp s12_q39_othexpensesamt { // these are all the components of nondurables_exp that goes into the multiplier / MPC
	local name = subinstr("`v'", "amt_12mth","",.)
	local name = substr("`name'",strpos("`name'","_")+1,100)
	local name = substr("`name'",strpos("`name'","_")+1,100)
	gen share_`name' = `v' / nondurables_exp
}

keep hhid_key eligible hhweight_EL share_* nondurables_exp nondurables_exp_wins
cap drop share_flat

** Average across households **
*winsor2 share_*, by(eligible) cut(1 99) suffix(_wins)
gen weight = hhweight_EL * nondurables_exp_wins // household weight in terms of overall expenditure

foreach v of var share_* {
	egen a_`v' = wtmean(`v'), weight(weight)
}

collapse a_share*
ren a_* *

** reshape and rename **
gen product = ""
gen exp_share = .
foreach v of var share_* {
	local name = substr("`v'",strpos("`v'","_")+1,100)
	insobs 1
	replace product = "`name'" if _n == _N
	replace exp_share = `v'[1] if _n == _N
}

drop if _n == 1
keep product exp_share
egen share_tot = sum(exp_share)
replace exp_share = exp_share/share_tot
drop share_tot

** Clean product names **
*************************
replace product = "Cereals" if product == "cereals"
replace product = "Roots and tubers" if product == "roots"
replace product = "Pulses" if product == "pulses"
replace product = "Vegetables" if product == "veg"
replace product = "Meat" if product == "meat"
replace product = "Fish" if product == "fish"
replace product = "Dairy and eggs" if product == "dairyeggs"
replace product = "Other animal products" if product == "othanimal"
replace product = "Cooking fat" if product == "oil"
replace product = "Fruits" if product == "fruits"
replace product = "Sugar products" if product == "sugar"
replace product = "Jam, honey, sweets, candies" if product == "sweets"
replace product = "Tea, coffee" if product == "softdrinks"
replace product = "Salt, pepper, condiments, etc." if product == "spices"
replace product = "Food eaten outside the house" if product == "foodout"
replace product = "Other foods" if product == "foodoth"
replace product = "Airtime and phone expenses" if product == "airtime"
replace product = "Internet" if product == "internet"
replace product = "Transport, travel" if product == "travel"
replace product = "Lottery tickets and gambling" if product == "gambling"
replace product = "Personal items" if product == "personal"
replace product = "Clothing and shoes" if product == "clothes"
replace product = "Household items" if product == "hhitems"
replace product = "Firewood, charcoal, kerosene" if product == "firewood"
replace product = "Electricity" if product == "elect"
replace product = "Water" if product == "water"
replace product = "Recreation" if product == "rec"
replace product = "Religious expenses" if product == "religiousamt"
replace product = "Charitable expenses" if product == "charityamt"
replace product = "Weddings, funerals" if product == "weddingamt"
replace product = "Dowry / bride price" if product == "dowryamt"
replace product = "School expenses" if product == "educexp"
replace product = "House rent / mortgage" if product == "rentamt"
replace product = "Medical expenses" if product == "medicalexp"
replace product = "Other expenses" if product == "othexpensesamt"
replace product = "Alcohol, tobacco" if product == "temptgoods_12"

tempfile nondurables_expshare
save `nondurables_expshare', replace


** B - Durable assets **
************************
use "$da/GE_HHLevel_ECMA.dta", clear

drop share_*

gen totval_hhassets_h = totval_hhassets + h1_10_housevalue
wins_top1 totval_hhassets_h

foreach v of var s6_q13a_bicyclevalue s6_q13b_motorcyclevalue s6_q13c_carvalue s6_q13d_kerosenevalue s6_q13e_radiovalue s6_q13f_sewingvalue ///
s6_q13g_lanternvalue s6_q13h_bedvalue s6_q13hh_generatorvalue s6_q13i_mattressvalue s6_q13j_bednetvalue s6_q13k_tablevalue s6_q13l_sofavalue s6_q13m_chairvalue s6_q13n_cupboardsvalue ///
s6_q13o_clockvalue s6_q13p_elecironvalue s6_q13q_televisionvalue s6_q13r_computervalue s6_q13s_mobilevalue s6_q13t_carbatteryvalue s6_q13u_boatvalue ///
s6_q13v_sheetsvalue s6_q13w_farmtoolsvalue s6_q13x_handcartvalue s6_q13y_wbarrowvalue s6_q13z_oxplowvalue s6_q13aa_cattlevalue s6_q13bb_goatvalue ///
s6_q13cc_sheepvalue s6_q13dd_chickenvalue s6_q13ee_othbirdvalue s6_q13ff_pigvalue s6_q13gg_solarvalue h1_10_housevalue { // these are all the components of totval_hhassets_h that goes into the multiplier / MPC
	local name = substr("`v'",strpos("`name'","_")+1,100)
	local name = substr("`name'",strpos("`name'","_")+1,100)
	local name = substr("`name'",strpos("`name'","_")+1,100)
	gen share_`name' = `v' / totval_hhassets_h
}

keep hhid_key eligible hhweight_EL share_* totval_hhassets_h totval_hhassets_h_wins
cap drop share_flat

* Average across households **
*winsor2 share_*, by(eligible) cut(1 99) suffix(_wins)
gen weight = hhweight_EL * totval_hhassets_h_wins // household weight in terms of overall asset ownership

foreach v of var share_* {
	egen a_`v' = wtmean(`v'), weight(weight)
}

collapse a_share*
ren a_* *

** reshape and rename **
gen product = ""
gen exp_share = .
foreach v of var share_* {
	local name = subinstr(substr("`v'",strpos("`v'","_")+1,100),"value","",.)
	insobs 1
	replace product = "`name'" if _n == _N
	replace exp_share = `v'[1] if _n == _N
}

drop if _n == 1
keep product exp_share
egen share_tot = sum(exp_share)
replace exp_share = exp_share/share_tot
drop share_tot

** Clean product names **
*************************
replace product = proper(product)
replace product = "Sewing machine" if product == "Sewing"
replace product = "Cupboard" if product == "Cupboards"
replace product = "Electric Iron" if product == "Eleciron"
replace product = "Mobile phone" if product == "Mobile"
replace product = "Car battery" if product == "Carbattery"
replace product = "Iron sheets" if product == "Sheets"
replace product = "Farm tools" if product == "Farmtools"
replace product = "Hand cart" if product == "Handcart"
replace product = "Wheel barrow" if product == "Wbarrow"
replace product = "Ox plow" if product == "Oxplow"
replace product = "Other birds" if product == "Othbird"
replace product = "Pigs" if product == "Pigs"
replace product = "Solar energy system" if product == "Solar"
replace product = "House value (maintenance, improvement)" if product == "House"

tempfile durables_expshare
save `durables_expshare', replace


**********************************************************
** Step 4 - Import product to enterprise type crosswalk **
**********************************************************

** A - Nondurables **
*********************
project, original("$dr/IntermediateImportAssumptions_nondurables_entmatch.dta") preserve
use "$dr/IntermediateImportAssumptions_nondurables_entmatch.dta", clear
tempfile nondurables_entmatch
save `nondurables_entmatch'

** B - Durable assets **
************************
project, original("$dr/IntermediateImportAssumptions_durables_entmatch.dta") preserve
use "$dr/IntermediateImportAssumptions_durables_entmatch.dta", clear
tempfile durables_entmatch
save `durables_entmatch'



***************************************************************
** Step 5 - Generate final table, create final import shares **
***************************************************************

** A - Nondurables **
*********************
use `nondurables_expshare', clear
merge 1:m product using `nondurables_entmatch' // all merge
drop _merge

sort product
merge m:1 bizcat_str using `intshares' //
drop if _merge == 2 // these are enterprises that don't sell non-durables
drop _merge // all merge

** Generate final variables **
replace exp_share = exp_share * share_spent
egen a = sum(exp_share)
sum a // sums up to 1!
drop a

replace import_share = 0 if bizcat_str == "Local"
replace import_share = 1 if bizcat_str == "Import"

order product exp_share bizcat_str int_share_wins_clean int_import_share import_share
keep product exp_share bizcat_str int_share_wins_clean int_import_share import_share

** Generate total **
insobs 1
replace product = "Total" if _n == _N
sum exp_share
replace exp_share = `r(sum)' if _n == _N
gen a = exp_share * import_share
sum a
replace import_share = `r(sum)' if _n == _N
drop a

global share_import_nondurables = import_share[_N] // store for later use

gen a = exp_share * int_share_wins_clean // this is the weight as a share of all intermediate inputs
egen b = wtmean(int_import_share), weight(a)
sum b
global share_int_import_nondurables = `r(mean)' // store for later use
drop a b


** Now export tex table for Appendix **
***************************************
replace bizcat_str = subinstr(bizcat_str,"Non-food - ","",.)
replace bizcat_str = "Homemade alcohol / liquor" if bizcat_str == "Sale or brewing of homemade alcohol / liquor"

cap erase "$dtab/TableD1_Importshares_Nondurables.tex"
texdoc init "$dtab/TableD1_Importshares_Nondurables.tex", replace force

tex {\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{ll*{4}{S}}\toprule
tex & &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\
tex \multicolumn{1}{l}{Item}&\multicolumn{1}{l}{Bought atenterprise type}&\multicolumn{1}{c}{\shortstack{Expenditure\\share\\(data)}}&\multicolumn{1}{c}{\shortstack{Intermediate\\input share\\(data)}}&\multicolumn{1}{c}{\shortstack{Intermediate\\import share\\(assumed)}}&\multicolumn{1}{c}{\shortstack{Overall\\import share}}\\
tex \hline
tex \addlinespace

local prods `" "Cereals" "Roots and tubers" "Pulses" "Vegetables" "Fruits" "Meat" "Fish" "Dairy and eggs" "Other animal products" "Cooking fat" "Sugar products" "Jam, honey, sweets, candies" "Tea, coffee" "Salt, pepper, condiments, etc." "Food eaten outside the house" "Alcohol, tobacco" "Other foods" "Clothing and shoes" "Personal items" "Household items" "Transport, travel"  "Airtime and phone expenses" "Internet" "Firewood, charcoal, kerosene" "Electricity" "Water" "Recreation" "Lottery tickets and gambling" "Religious expenses" "Weddings, funerals" "Charitable expenses"  "Dowry/bride price" "House rent / mortgage"  "School expenses" "Medical expenses"  "Other expenses" "'

foreach p in `prods' {
	disp "`p'"
	preserve
	keep if product == "`p'"
	local max = _N
	disp "`max'"
	forval i = 1/`max' {
		if `i' == 1 local prod = "`p'"
		else local prod = ""
		local expshare : di %3.1f 100*exp_share[`i']
		local ent = bizcat_str[`i']
		if (int_share_wins_clean[`i'] != .) local intshare : di %3.0f 100*int_share_wins_clean[`i']
		else local intshare = ""
		local intimpshare : di %3.0f 100*int_import_share[`i']
		local impshare : di %3.0f 100*import_share[`i']
		if (int_share_wins_clean[`i'] != .) tex `prod' & `ent' & `expshare'\% & `intshare'\% & `intimpshare'\% & `impshare'\% \\
		else tex `prod' & `ent' & `expshare'\% & & `intimpshare'\% & `impshare'\% \\
   }
   restore
}
tex \hline
keep if product == "Total"
local impshare : di %3.0f 100*$share_import_nondurables
tex \addlinespace \bf{Total} & \bf{100.0}\% & & & & \bf{`impshare'\%} \\
tex \bottomrule\end{tabular}}
texdoc close
cap: project, creates("$dtab/TableD1_Importshares_Nondurables.tex") preserve


** A - Durables **
******************
use `durables_expshare', clear
merge 1:m product using `durables_entmatch' // all merge
drop _merge

sort product
merge m:1 bizcat_str using `intshares' //
drop if _merge == 2 // these are enterprises that don't sell durables
drop _merge // all merge

** Generate final variables **
replace exp_share = exp_share * share_spent
egen a = sum(exp_share)
sum a // sums up to 1!
drop a

replace import_share = 0 if bizcat_str == "Local"
replace import_share = 1 if bizcat_str == "Import"

order product exp_share bizcat_str int_share_wins_clean int_import_share import_share
keep product exp_share bizcat_str int_share_wins_clean int_import_share import_share

** Generate total **
insobs 1
replace product = "Total" if _n == _N
sum exp_share
replace exp_share = `r(sum)' if _n == _N
gen a = exp_share * import_share
sum a
replace import_share = `r(sum)' if _n == _N
drop a

global share_import_durables = import_share[_N]

gen a = exp_share * int_share_wins_clean // this is the weight as a share of all intermediate inputs
egen b = wtmean(int_import_share), weight(a)
sum b
global share_int_import_durables = `r(mean)' // store for later use
drop a b

** Now export tex table for Appendix **
***************************************
replace bizcat_str = subinstr(bizcat_str,"Non-food - ","",.)
replace bizcat_str = "Homemade alcohol / liquor" if bizcat_str == "Sale or brewing of homemade alcohol / liquor"
sort product exp_share

cap erase "$dtab/TableD2_Importshares_Durables.tex"
texdoc init "$dtab/TableD2_Importshares_Durables.tex", replace force

tex {\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\begin{tabular}{ll*{4}{S}}\toprule
tex & &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\
tex \multicolumn{1}{l}{Item}&\multicolumn{1}{l}{Bought at enterprise type}&\multicolumn{1}{c}{\shortstack{Asset\\share\\(data)}}&\multicolumn{1}{c}{\shortstack{Intermediate\\input share\\(data)}}&\multicolumn{1}{c}{\shortstack{Intermediate\\import share\\(assumed)}}&\multicolumn{1}{c}{\shortstack{Overall\\import share}}\\
tex \hline
tex \addlinespace

local prods `" "Bicycle" "Motorcycle" "Car" "Boat" "Bed" "Chair" "Table" "Cupboard" "Sofa" "Mattress" "Bednet" "Solar energy system" "Generator" "Car battery" "Kerosene" "Lantern" "Clock" "Radio" "Sewing machine" "Electric Iron" "Mobile phone" "Television" "Computer" "Cattle" "Pig" "Sheep"  "Goat" "Chicken" "Other birds" "Farm tools" "Ox plow" "Wheel barrow" "Hand cart" "Iron sheets"  "House value (maintenance, improvement)" "'

foreach p in `prods' {
	disp "`p'"
	preserve
	keep if product == "`p'"
	local max = _N
	disp "`max'"
	forval i = 1/`max' {
		if `i' == 1 local prod = "`p'"
		else local prod = ""
		local expshare : di %3.1f 100*exp_share[`i']
		local ent = bizcat_str[`i']
		if (int_share_wins_clean[`i'] != .) local intshare : di %3.0f 100*int_share_wins_clean[`i']
		else local intshare = ""
		local intimpshare : di %3.0f 100*int_import_share[`i']
		local impshare : di %3.0f 100*import_share[`i']
		if (int_share_wins_clean[`i'] != .) tex `prod' & `ent' & `expshare'\% & `intshare'\% & `intimpshare'\% & `impshare'\% \\
		else tex `prod' & `ent' & `expshare'\% & & `intimpshare'\% & `impshare'\% \\
   }
   restore
}
tex \hline
keep if product == "Total"
local impshare : di %3.0f 100*$share_import_durables
tex \addlinespace \bf{Total} & \bf{100.0}\% & & & & \bf{`impshare'\%} \\
tex \bottomrule\end{tabular}}
texdoc close
cap: project, creates("$dtab/TableD2_Importshares_Durables.tex") preserve



**************************************************************************
** Step 6 - Get correlation between revenue share and expenditure share **
**************************************************************************
use `nondurables_expshare', clear
merge 1:m product using `nondurables_entmatch' // all merge
drop _merge

** Add in asset expenditure **
** Assume 10% of assets are replaced each year **
preserve
project, original("$da/GE_HHLevel_ECMA.dta")
use "$da/GE_HHLevel_ECMA.dta", clear

sum nondurables_exp_wins_PPP [aweight=hhweight_EL]
local totexp_nondur = `r(mean)' * `r(sum_w)'

gen totval_hhassets_h = totval_hhassets + h1_10_housevalue
wins_top1 totval_hhassets_h
gen totval_hhassets_h_wins_PPP = totval_hhassets_h_wins*$ppprate

sum totval_hhassets_h_wins_PPP [aweight=hhweight_EL]
local totexp_dur = 0.1*`r(mean)' * `r(sum_w)'
restore

preserve
use `durables_expshare', clear
merge 1:m product using `durables_entmatch' // all merge
drop _merge

replace exp_share  = exp_share * `totexp_dur' / `totexp_nondur'
tempfile temp1
save `temp1'
restore

append using `temp1'

gen exp_share_biz = exp_share * share_spent
collapse (sum) exp_share_biz, by(bizcat_str)
merge 1:1 bizcat_str using `intshares'

** Calculate correlation between assigned expenditure and revenue shares **
corr exp_share_biz share_revenue
