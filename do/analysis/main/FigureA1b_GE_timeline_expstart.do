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


/*** Figure on GE timeline relative to experimental start ***/

project, original("$da/GE_Survey_and_Transfer_Dates.dta")
use "$da/GE_Survey_and_Transfer_Dates.dta", clear


** Categories for organizing graph **
gen gphcat = .

replace gphcat = 1 if ~mi(census_mon)
replace calmonth = census_mon  if gphcat == 1
replace expmonth = exptocensus if gphcat == 1

replace gphcat = 2 if ~mi(baseline_mon)
replace calmonth = baseline_mon if gphcat == 2
replace expmonth = exptobase    if gphcat == 2

replace gphcat = 3 if transnum  == 1
replace gphcat = 4 if transnum == 2
replace gphcat = 5 if transnum == 3

replace gphcat = 6 if ~mi(mkt_mon)
replace calmonth = mkt_mon   if gphcat == 6
replace expmonth = exptomkt     if gphcat == 6

replace gphcat = 7 if ~mi(endline_mon)
replace calmonth = endline_mon   if gphcat == 7
replace expmonth = exptoend     if gphcat == 7

replace gphcat = 8 if ~mi(entcend_mon)
replace calmonth = entcend_mon  if gphcat == 8
replace expmonth = exptoentc     if gphcat == 8

replace gphcat = 9 if ~mi(entsend_mon)
replace calmonth = entsend_mon  if gphcat == 9
replace expmonth = exptoents     if gphcat == 9


la define gphlabel2 1 "Baseline census (hh & ent)" 2 "Baseline survey (hh & ent)" 3 "First GD transfer" 4 "Second GD transfer" 5 "Third GD transfer" 6 "Market price survey" 7 "Household endline survey" 8 "Enterprise endline census" 9 "Enterprise endline survey"

la val gphcat gphlabel2

foreach num of numlist 5 25 50 75 95 {
    egen p`num'_exp = pctile(expmonth), p(`num') by(gphcat)
}



egen tag2 = tag(gphcat)

    local cond1 "(gphcat == 2 | gphcat == 7)"
    local cond2 "(gphcat == 6 | gphcat == 9)"
    local cond3 "(gphcat >= 3 & gphcat <=5)"
    local cond4 "(gphcat == 1 | gphcat == 8)"

    twoway rbar p50_exp p75_exp gphcat if tag2 & `cond1', horiz pstyle(1) blc(black) bfc(white) barw(0.35) ///
        || rbar p50_exp p25_exp gphcat if tag2 & `cond1', horiz pstyle(1) blc(black) bfc(white) barw(0.35) ///
        || rspike p75_exp p95_exp gphcat if tag2 & `cond1', horiz pstyle(p1) ///
    	|| rspike p25_exp p5_exp  gphcat if tag2 & `cond1', horiz pstyle(p1) ///
    	|| rcap p50_exp p50_exp gphcat if tag2 & `cond1', horiz pstyle(p1) msize(*`capsizemed') lcolor(black) lwidth(medthick) ///
    	|| rcap p95_exp p95_exp gphcat if tag2 & `cond1', horiz pstyle(p1) msize(*`capsize') ///
    	|| rcap p5_exp p5_exp gphcat if tag2 & `cond1', horiz pstyle(p1) msize(*`capsize') ///
        || rbar p50_exp p75_exp gphcat if tag2 & `cond2', horiz pstyle(1) blc(black) bfc(gs13) barw(0.35) ///
        || rbar p50_exp p25_exp gphcat if tag2 & `cond2', horiz pstyle(1) blc(black) bfc(gs13) barw(0.35) ///
        || rspike p75_exp p95_exp gphcat if tag2 & `cond2', horiz pstyle(p1) ///
    	|| rspike p25_exp p5_exp  gphcat if tag2 & `cond2', horiz pstyle(p1) ///
    	|| rcap p50_exp p50_exp gphcat if tag2 & `cond2', horiz pstyle(p1) msize(*`capsizemed') lcolor(black) lwidth(medthick) ///
    	|| rcap p95_exp p95_exp gphcat if tag2 & `cond2', horiz pstyle(p1) msize(*`capsize') ///
    	|| rcap p5_exp p5_exp gphcat if tag2 & `cond2', horiz pstyle(p1) msize(*`capsize') ///
        || rbar p50_exp p75_exp gphcat if tag2 & `cond3', horiz pstyle(1) blc(black) bfc(gs8) barw(0.35) ///
        || rbar p50_exp p25_exp gphcat if tag2 & `cond3', horiz pstyle(1) blc(black) bfc(gs8) barw(0.35) ///
        || rspike p75_exp p95_exp gphcat if tag2 & `cond3', horiz pstyle(p1) ///
    	|| rspike p25_exp p5_exp  gphcat if tag2 & `cond3', horiz pstyle(p1) ///
    	|| rcap p50_exp p50_exp gphcat if tag2 & `cond3', horiz pstyle(p1) msize(*`capsizemed') lcolor(black) lwidth(medthick) ///
    	|| rcap p95_exp p95_exp gphcat if tag2 & `cond3', horiz pstyle(p1) msize(*`capsize') ///
    	|| rcap p5_exp p5_exp gphcat if tag2 & `cond3', horiz pstyle(p1) msize(*`capsize') ///
        || rbar p50_exp p75_exp gphcat if tag2 & `cond4', horiz pstyle(1) blc(black) bfc(gs15) barw(0.35) ///
        || rbar p50_exp p25_exp gphcat if tag2 & `cond4', horiz pstyle(1) blc(black) bfc(gs15) barw(0.35) ///
        || rspike p75_exp p95_exp gphcat if tag2 & `cond4', horiz pstyle(p1) ///
        || rspike p25_exp p5_exp  gphcat if tag2 & `cond4', horiz pstyle(p1) ///
        || rcap p50_exp p50_exp gphcat if tag2 & `cond4', horiz pstyle(p1) msize(*`capsizemed') lcolor(black) lwidth(medthick) ///
        || rcap p95_exp p95_exp gphcat if tag2 & `cond4', horiz pstyle(p1) msize(*`capsize') ///
        || rcap p5_exp p5_exp gphcat if tag2 & `cond4', horiz pstyle(p1) msize(*`capsize') ///
    	legend(off) xlabel(0(6)30) ysca(reverse) ylab(1(1)9, val angle(h) nogrid notick) ytitle("")  graphregion(margin(l+1 r+1)) aspectratio(0.5) ///
			xtitle("Months since experimental start")

* version for presentation *
graph export "$dfig/FigureA1b_GE_timeline.pdf", replace
project, creates("$dfig/FigureA1b_GE_timeline.pdf")
