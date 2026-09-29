 
*! THIS IS TILMAN GRAFF's and DENNIS EGGER's ATTEMPT AT AMENDING OLS_SPATIAL_HAC TO ACCOMMODATE IVS
 
/*-----------------------------------------------------------------------------

 This is almost completely based on Sol Hsiang's (SHSIANG@BERKELEY.EDU) code to compute Conley Errors for OLS
 
 ------------------------------------------------------------------------------

 Syntax:
 
 iv_spatial_HAC Yvar Xvarlist, en(endog_varlist) in(instrument_varlist) lat(latvar) lon(lonvar) Timevar(tvar) Panelvar(pvar) [DISTcutoff(#) LAGcutoff(#) bartlett DISPlay star dropvar]

 Function calculates non-parametric (GMM) spatial and autocorrelation 
 structure using a panel data set.  Spatial correlation is estimated for all
 observations within a given period.  Autocorrelation is estimated for a
 given individual over multiple periods up to some lag length. Var-Covar
 matrix is robust to heteroskedasticity.
 
 A variable equal to 1 is required to estimate a constant term.
 
 Example commands:
 
 iv_spatial_HAC p1_assets cons if sample == 1 [aw = weight], en(pp_actamt_ownvill pp_actamt_ov_0to2km-pp_actamt_ov_0to2km) in(share_elig_ownvill share_ge_elig_ov_0to2km-share_ge_elig_ov_0to2km) lat(latitude) lon(longitude) timevar(`timvar') panelvar(`panvar') dist(10) lag(0) dropvar

 ------------------------------------------------------------------------------
 
 Requred arguments: 
 
 Yvar: dependent variable  
 Xvarlist: independnet variables (INCLUDE constant as column) OR En() and IN()
 latvar: variable containing latitude in DEGREES of each obs
 lonvar: same, but longitude
 tvar: varible containing time variable
 pvar: variable containing panel variable (must be numeric, see "encode")
 
 ------------------------------------------------------------------------------
 
 Optional arguments:
 
 distcutoff(#): {abbrev dist(#)} describes the distance cutoff in KILOMETERS for the spatial kernal (the distance at which spatial correlation is assumed to vanish). Default is 1 KM.
 
 lagcutoff(#): {abbrev lag(#)} describes the maximum number of temporal periods for the linear Bartlett window that weights serial correlation across time periods (the distance at which serial correlation is assumed to vanish). Default is 0 PERIODS (no serial correlation). {Note, Greene recommends at least T^0.25}  
 
 ------------------------------------------------------------------------------
 
 Options:
 
 bartlett: use a linear bartlett window for spatial correlations, instead of a uniform kernal
 
 display: {abbrev disp} display a table with estimated coeff and SE & t-stat using OLS, adjusting for spatial correlation and adjusting for both spatial and serial correlation. Can be used with star option. Ex:
 
 -----------------------------------------------
     Variable |   OLS      spatial    spatHAC   
 -------------+---------------------------------
       indep1 |    0.568      0.568      0.568  
              |    0.198      0.206      0.240  
              |    2.876      2.761      2.369  
        const |    6.415      6.415      6.415  
              |    0.790      1.176      1.340  
              |    8.119      5.454      4.786  
 -----------------------------------------------
                                  legend: b/se/t
 

 star: same as display, but uses stars to denote significance and does not show SE & t-stat. Can be used with display option. Ex:
 
 -----------------------------------------------------
     Variable |    OLS        spatial      spatHAC    
 -------------+---------------------------------------
       indep1 |   0.568***     0.568***     0.568**   
        const |   6.415***     6.415***     6.415***  
 -----------------------------------------------------
                   legend: * p<.1; ** p<.05; *** p<.01
                   
                   
 dropvar: Drops variables that Stata would drop due to collinearity. This requires that an additiona regression is run, so it slows the code down. For large datasets, if this function is called many times, it may be faster to ensure that colinear variables are dropped in advance rather than using the option dropvar. If Stata returns "estimates post: matrix has missing values", than including the option dropvar may solve the problem. (This option written by Kyle Meng).
 
 ------------------------------------------------------------------------------
 
 Implementation:
 
 The default kernal used to weight spatial correlations is a uniform kernal that
 discontinously falls from 1 to zero at length locCutoff in all directions (it is isotropic). This is the kernal recommented by Conley (2008). If the option "bartlett" is selected, a conical kernal that decays linearly with distance in all directions is used instead.
 
 Serial correlation bewteen observations of the same individual over multiple periods seperated by lag L are weighted by 

       w(L) = 1 - L/(lagCutoff+1)
       
 ------------------------------------------------------------------------------

 Notes:

 Location arguments should specify lat-lon units in DEGREES, however
 distcutoff should be specified in KILOMETERS. 

 distcutoff must exceed zero. CAREFUL: do not supply
 coordinate locations in modulo(360) if observations straddle the
 zero-meridian or in modulo(180) if they straddle the date-line. 

 Distances are computed by approximating the planet's surface as a plane
 around each observation.  This allows for large changes in LAT to be
 present in the dataset (it corrects for changes in the length of
 LON-degrees associated with changes in LAT). However, it does not account
 for the local curvature of the surface around a point, so distances will
 be slightly lower than true geodesics. This should not be a concern so
 long as locCutoff is < O(~2000km), probably.

 Each time-series for an individual observation in the panel is treated
 with Heteroskedastic and Autocorrelation Standard Errors. If lagcutoff =
 0, than this estimate is equivelent to White standard errors (with spatial correlations 
 accounted for). If lagcutoff = infinity, than this treatment is
 equivelent to the "cluster" command in Stata at the panel variable level.

 This script stores estimation results in standard Stata formats, so most "ereturn" commands should work properly.  It is also compatible with "outreg2," although I have not tested other programs.

 The R^2 statistics output by this function will differ from analogous R^2 stats
 computed using "reg" since this function omits the constant. 
 ------------------------------------------------------------------------------

 References:

      TG Conley "GMM Estimation with Cross Sectional Dependence" 
      Journal of Econometrics, Vol. 92 Issue 1(September 1999) 1-45
      http://www.elsevier.com/homepage/sae/econworld/econbase/econom/frame.htm
      
      and 

      Conley "Spatial Econometrics" New Palgrave Dictionary of Economics,
      2nd Edition, 2008

      and

      Greene, Econometric Analysis, p. 546

	  and

	  Modified from scripts written by Ruben Lebowski and Wolfram Schlenker and Jean-Pierre Dube and Solomon Hsiang
	  Debugging help provided by Mathias Thoenig.
 
 -----------------------------------------------------------------------------*/
program define iv_spatial_HAC, eclass byable(recall)
version 11
	
syntax varlist(ts fv min=1) [if] [in] [fw iw pw aw/], ///
				ENdogeneous(varlist fv) INstruments(varlist fv) ///
				lat(varname numeric) lon(varname numeric) ///
				[Timevar(varname numeric)] Panelvar(varname numeric) [LAGcutoff(integer 0) DISTcutoff(real 1) ///
				DISPlay star bartlett dropvar]				
				
/*--------PARSING COMMANDS AND SETUP-------*/

capture drop touse
marksample touse				// indicator for inclusion in the sample
gen touse = `touse'

*****************
* Expand and Name all Varlists
*****************

****
* Y
****

loc Y = word("`varlist'",1)	


****
* X
****

fvrevar `varlist'
loc listing = "`r(varlist)'"
foreach i of loc listing {
	if "`i'" ~= "`Y'"{
		loc X "`X' `i'"	
	}
}

fvexpand `varlist'
loc listing_n = "`r(varlist)'"
foreach i of loc listing_n {
	if "`i'" ~= "`Y'"{
		loc X_n "`X_n' `i'"	
	}
}


****
* Endogeneous regressors
****

fvrevar `endogeneous'
loc endog = "`r(varlist)'"
fvexpand `endogeneous'
loc endog_n = "`r(varlist)'"


****
* Instruments
****

fvrevar `instruments'
loc exog = "`r(varlist)'"
fvexpand `instruments'
loc exog_n = "`r(varlist)'"	


*****************
* Drop Multicollinear Variables
*****************

if "`dropvar'" == "dropvar"{
	
	** run huge pseudo-reg to find multicollinears **
	quietly reg `Y' `X' `endog' `exog'  if `touse', nocons
	
	mat omittedMat=e(b)
	local newVarList=""
	local i=1
	
	
	** identify multicollinears and note the tempvar names of clean ones
	foreach var of varlist `X' `endog' `exog'{
		if omittedMat[1,`i']!=0{
			loc newVarList "`newVarList' `var'"
		}
		local i=`i'+1
	}
	

	
	********
	* One by one, go through different varlists and drop those that are not clean
	* Do the same for the variable names
	********
	
	**** Clean X and X_n
	loc X_clean = ""
	loc X_n_clean = ""
	scalar k = 0 //replace the old k if this option is selected
	
	if "`X'" != ""{
	
		loc i = 1
		foreach var of varlist `X'{
			if strpos( "`newVarList'", "`var'")>0{
				loc here =  word("`X'",`i')
				loc here_n =  word("`X_n'",`i')
				
				loc X_clean = "`X_clean' `here'"
				loc X_n_clean = "`X_n_clean' `here_n'"
				
				scalar k = k + 1
			}
			loc i = `i' + 1
			
		}
	}
	
	
	**** Clean exog and exog_n
	loc exog_clean = ""
	loc exog_n_clean = ""
	
	if "`exog'" != ""{
	
		loc i = 1
		foreach var of varlist `exog'{
			if strpos( "`newVarList'", "`var'")>0{
				loc here =  word("`exog'",`i')
				loc here_n =  word("`exog_n'",`i')
				
				loc exog_clean = "`exog_clean' `here'"
				loc exog_n_clean = "`exog_n_clean' `here_n'"
				
				
			}
			loc i = `i' + 1
			
		}
	}	
	
	
	
	**** Clean endog and endog_n
	loc endog_clean = ""
	loc endog_n_clean = ""
	
	if "`endog'" != ""{
	
		loc i = 1
		foreach var of varlist `endog'{
			if strpos( "`newVarList'", "`var'")>0{
				loc here =  word("`endog'",`i')
				loc here_n =  word("`endog_n'",`i')
				
				loc endog_clean = "`endog_clean' `here'"
				loc endog_n_clean = "`endog_n_clean' `here_n'"
				scalar k = k + 1
				
			}
			loc i = `i' + 1
			
		}
	}	
		
	
}



*****************
* Rename and Create Variable Collations
*****************

loc X = "`X_clean'"
loc endog = "`endog_clean'"
loc exog = "`exog_clean'"

loc X_and_endog = "`endog' `X'"
loc X_and_exog = "`exog' `X'"


loc X_n = "`X_n_clean'"
loc endog_n = "`endog_n_clean'"
loc exog_n = "`exog_n_clean'"

loc X_and_endog_n = " `endog_n' `X_n'"
loc X_and_exog_n = "`exog_n ' `X_n'"



*****************
* Drop Missings
*****************
foreach name in "Y" "X_and_exog" "X_and_endog"{
	foreach var of varlist ``name''{
		qui replace touse = 0 if `var' == .
	}
}

*****************
* If no weights, make constant weights
*****************
if "`exp'" == "" {
	cap drop pseudoweight
	gen pseudoweight = 1
	loc exp "pseudoweight"
	loc weight = "aw"
}

*****************
* If no timvar, make constant timvar
*****************
if "`timevar'" == "" {
	cap drop pseudotime
	gen pseudotime = 1
	loc timevar "pseudotime"
}

//generating a function of the included obs
quietly count if `touse'		
scalar n = r(N)					// # obs
scalar n_obs = r(N)




***************************************************


/*--------FIRST DO IV, STORE RESULTS-------*/

di as txt "Conley Error Estimation:"
di as txt "regressing `Y' on `X_and_endog_n'"
di as txt "where `endog_n'"
di as txt "are instrumented by `exog_n'"

qui: ivreg2 `Y' `X' (`endog' = `exog') if `touse' [`weight' = `exp'], nocons
estimates store IV


//est tab IV, stats(N r2)

/*--------SECOND, IMPORT ALL VALUES INTO MATA-------*/


mata{

Y_var = st_local("Y") //importing variable assignments to mata
X_var = st_local("X_and_endog")
Z_var = st_local("X_and_exog")
W_var = st_local("exp")
lat_var = st_local("lat")
lon_var = st_local("lon")
time_var = st_local("timevar")
panel_var = st_local("panelvar")

//NOTE: values are all imported as "views" instead of being copied and pasted as Mata data because it is faster, however none of the matrices are changed in any way, so it should not permanently affect the data. 

st_view(Y=.,.,tokens(Y_var),"touse") //importing variables vectors to mata
st_view(X=.,.,tokens(X_var),"touse")
st_view(Z=.,.,tokens(Z_var),"touse")
st_view(W=.,.,tokens(W_var),"touse")
st_view(lat=.,.,tokens(lat_var),"touse")
st_view(lon=.,.,tokens(lon_var),"touse")
st_view(time=.,.,tokens(time_var),"touse")
st_view(panel=.,.,tokens(panel_var),"touse")

k = st_numscalar("k")				//importing other parameters
n = st_numscalar("n")
b = st_matrix("e(b)")				// (estimated coefficients, row vector)
lag_var = st_local("lagcutoff")
lag_cutoff = strtoreal(lag_var)
dist_var = st_local("distcutoff")
dist_cutoff = strtoreal(dist_var)

W_scaled = W * length(W) / sum(W)
W_dia = diag(W_scaled)

*w_sqrt = sqrt(W_scaled)
*w_sqrtdia = diag(w_sqrt)

invZwwZ = luinv(Z' * W_dia * Z)
ZwwX = Z' * W_dia * X

X_hat = Z * invZwwZ  * ZwwX

** save manual standard coefficients and robust SE for comparison with ivreg2 output **
** Dennis: I checked this, and both work out, i.e. give exactly the same result as ivreg, robust **
/*
invXwwX = luinv(X_hat' * W_dia * X_hat)
b_manual = invXwwX * X_hat' * W_dia * Y

u = Y - X*b_manual
XeeX = X_hat' * W_dia * diag(u * u') * W_dia' * X_hat

V_manual = invXwwX * XeeX * invXwwX

st_matrix("errors", u)
st_matrix("b_iv_manual", b_manual)
st_matrix("V_robust_manual", V_manual)
*/

XeeX = J(k, k, 0) 				//set variance-covariance matrix equal to zeros

/*--------THIRD, CORRECT VCE FOR SPATIAL CORR-------*/

timeUnique = uniqrows(time)
Ntime = rows(timeUnique) 		// # of obs. periods

for (ti = 1; ti <= Ntime; ti++){
	
	

	// 1 if in year ti, 0 otherwise:

	rows_ti = time:==timeUnique[ti,1] 	

	//get subsets of variables for time ti (without changing original matrix)
	
	Y1 = select(Y, rows_ti)
	X1 = select(X, rows_ti)
	X_hat1 = select(X_hat, rows_ti)
	w_dia1 = select(select(W_dia, rows_ti), rows_ti')
	*w_sqrtdia1 = select(select(w_sqrtdia, rows_ti), rows_ti')
	lat1 = select(lat, rows_ti)
	lon1 = select(lon, rows_ti)
	**********
	e1 = Y1 - X1*b' // TG: this is the major point: in 2SLS you take the structural equation to compute residuals. Note that this equation is none of the two stages!
	**********
	
	n1 = length(Y1) 			// # obs for period ti
	
	//loop over all observations in period ti

	for (i = 1; i <=n1; i++){
		

		//----------------------------------------------------------------
        // step a: get non-parametric weight
	
	    //This is a Euclidean distance scale IN KILOMETERS specific to i
        
		lon_scale = cos(lat1[i,1]*pi()/180)*111 
		lat_scale = 111
		

		// Distance scales lat and lon degrees differently depending on
        // latitude.  The distance here assumes a distortion of Euclidean
        // space around the location of 'i' that is approximately correct for 
        // displacements around the location of 'i'
        //
        //	Note: 	1 deg lat = 111 km
        // 			1 deg lon = 111 km * cos(lat)
		
		distance_i = ((lat_scale*(lat1[i,1]:-lat1)):^2 + /// 	
					  (lon_scale*(lon1[i,1]:-lon1)):^2):^0.5


		
		// this sets all observations beyon dist_cutoff to zero, and weights all nearby observations equally [this kernal is isotropic]
		
		window_i = distance_i :<= dist_cutoff

		//----------------------------------------------------------------
        // adjustment for the weights if a "bartlett" kernal is selected as an option
  
		if ("`bartlett'"=="bartlett"){
		
			// this weights observations as a linear function of distance
			// that is zero at the cutoff distance
			
			weight_i = 1:- distance_i:/dist_cutoff

			window_i = window_i:*weight_i
		}

 
        //----------------------------------------------------------------
        // step b: construct X'e'eX for the given observation
 
 		XeeXh = ((X_hat1[i,.]'* J(1,n1,1)*e1[i,1]*w_dia1[i,i]):*(J(k,1,1)*e1'*w_dia1:*window_i')) * X_hat1 

		//add each new k x k matrix onto the existing matrix (will be symmetric)
	
		XeeX = XeeX + XeeXh 	
	
	} //i
} // ti


// -----------------------------------------------------------------
// generate the VCE for only cross-sectional spatial correlation, 
// return it for comparison

invXwwX = luinv(X_hat'*W_dia*X_hat) * n

XeeX_spatial = XeeX / n

V = invXwwX * XeeX_spatial * invXwwX / n

// Ensures that the matrix is symmetric 
// in theory, it should be already, but it may not be due to rounding errors for large datasets
V = (V+V')/2 

st_matrix("V_spatial", V)

} // mata


//------------------------------------------------------------------
// storing old statistics about the estimate so postestimation can be used

matrix beta = e(b)
scalar r2_old = e(r2)
scalar df_m_old = e(df_m)
scalar df_r_old = e(df_r)
scalar rmse_old = e(rmse)
scalar mss_old = e(mss)
scalar rss_old = e(rss)
scalar r2_a_old = e(r2_a)

// the row and column names of the new VCE must match the vector b

matrix colnames V_spatial = `X_and_endog'
matrix rownames V_spatial = `X_and_endog'
  
// this sets the new estimates as the most recent model

ereturn post beta V_spatial, esample(`touse')

// then filling back in all the parameters for postestimation

ereturn local cmd = "iv_spatial"

ereturn scalar N = n_obs

ereturn scalar r2 = r2_old
ereturn scalar df_m = df_m_old
ereturn scalar df_r = df_r_old
ereturn scalar rmse = rmse_old
ereturn scalar mss = mss_old
ereturn scalar rss = rss_old
ereturn scalar r2_a = r2_a_old

ereturn local title = "Linear regression"
ereturn local depvar = "`Y'"
ereturn local predict = "regres_p"
ereturn local model = "iv"
ereturn local estat_cmd = "regress_estat"

//storing these estimates for comparison to OLS and the HAC estimates
estimates store spatial



/*--------FOURTH, CORRECT VCE FOR SERIAL CORR-------*/

mata{

panelUnique = uniqrows(panel)
Npanel = rows(panelUnique) 		// # of panels

for (pi = 1; pi <= Npanel; pi++){
	
	// 1 if in panel pi, 0 otherwise:

	rows_pi = panel:==panelUnique[pi,1] 	

	//get subsets of variables for panel pi (without changing original matrix)
	
	Y1 = select(Y, rows_pi)
	X1 = select(X, rows_pi)
	X_hat1 = select(X_hat, rows_pi)
	w_dia1 = select(select(W_dia, rows_pi), rows_pi')
	*w_sqrtdia1 = select(select(w_sqrtdia, rows_pi), rows_pi')
	time1 = select(time, rows_pi)
	*******
	e1 = Y1 - X1*b' // again structural equation used to find residuals
	*******
	
	n1 = length(Y1) 			// # obs for panel pi
	
	//loop over all observations in panel pi

	for (t = 1; t <=n1; t++){

   		// ----------------------------------------------------------------
        // step a: get non-parametric weight
        
        // this is the weight for Newey-West with a Bartlett kernal
        
        //weight = (1:-abs(time1[t,1] :- time1))/(lag_cutoff+1) // correction: need to removing parentheses to compute inter-temporal  (6/10/18)
        weight = 1:-abs(time1[t,1] :- time1)/(lag_cutoff+1)

        
        // obs var far enough apart in time are prescribed to have no estimated
        // correlation (Greene recomments lag_cutoff >= T^0.25 {pg 546})
        
        window_t = (abs(time1[t,1]:- time1) :<= lag_cutoff) :* weight
        
        //this is required so diagonal terms in var-covar matrix are not
        //double counted (since they were counted once above for the spatial
        //correlation estimates:
        
        window_t = window_t :* (time1[t,1] :!= time1)                   
            
  		// ----------------------------------------------------------------
        // step b: construct X'e'eX for given observation
         
		XeeXh = ((X_hat1[t,.]'* J(1,n1,1)*e1[t,1]*w_dia1[t,t]):*(J(k,1,1)*e1'*w_dia1:*window_t')) * X_hat1	

		//add each new k x k matrix onto the existing matrix (will be symmetric)
		        
        XeeX = XeeX + XeeXh

	} // t
} // pi



// -----------------------------------------------------------------
// generate the VCE for x-sectional spatial correlation and serial correlation

XeeX_spatial_HAC = XeeX / n

V = invXwwX * XeeX_spatial_HAC * invXwwX / n

// Ensures that the matrix is symmetric 
// in theory, it should be already, but it may not be due to rounding errors for large datasets
V = (V+V')/2 

st_matrix("V_spatial_HAC", V)

} // mata

//------------------------------------------------------------------
//storing results

matrix beta = e(b)
matrix colnames beta = `X_and_endog_n'
// the row and column names of the new VCE must match the vector b

matrix colnames V_spatial_HAC = `X_and_endog_n'
matrix rownames V_spatial_HAC = `X_and_endog_n'

// this sets the new estimates as the most recent model

marksample touse				// indicator for inclusion in the sample

ereturn post beta V_spatial_HAC, esample(`touse')

// then filling back in all the parameters for postestimation

ereturn local cmd = "iv_spatial_HAC"

ereturn scalar N = n_obs
ereturn scalar r2 = r2_old
ereturn scalar df_m = df_m_old
ereturn scalar df_r = df_r_old
ereturn scalar rmse = rmse_old
ereturn scalar mss = mss_old
ereturn scalar rss = rss_old
ereturn scalar r2_a = r2_a_old

ereturn local title = "IV HAC regression"
ereturn local depvar = "`Y'"
ereturn local predict = "regres_p"
ereturn local model = "iv"
ereturn local estat_cmd = "iv_estat"

//storing these estimates for comparison to OLS and the HAC estimates

estimates store spatHAC

//------------------------------------------------------------------
//displaying results

disp as txt " "
disp as txt "IV REGRESSION"
disp as txt " "
disp as txt "SE CORRECTED FOR CROSS-SECTIONAL SPATIAL DEPENDANCE"
disp as txt "             AND PANEL-SPECIFIC SERIAL CORRELATION"
disp as txt " "
disp as txt "DEPENDANT VARIABLE: `Y'"
disp as txt "INDEPENDANT VARIABLES: `X'"
disp as txt " "
disp as txt "SPATIAL CORRELATION KERNAL CUTOFF: `distcutoff' KM"

if "`bartlett'" == "bartlett" {
	disp as txt "(NOTE: LINEAR BARTLETT WINDOW USED FOR SPATIAL KERNAL)"
}
	
disp as txt "SERIAL CORRELATION KERNAL CUTOFF: `lagcutoff' PERIODS"

ereturn display // standard Stata regression table format

disp as txt "INSTRUMENTING: `endog_n'"
disp as txt "WITH: `exog_n'"


// displaying different SE if option selected

if "`display'" == "display"{
	disp as txt " "
	disp as txt "STANDARD ERRORS UNDER IV, WITH SPATIAL CORRECTION AND WITH SPATIAL AND SERIAL CORRECTION:"
	estimates table IV spatial spatHAC, b(%7.3f) se(%7.3f) t(%7.3f) stats(N r2) 	
}

if "`star'" == "star"{
	disp as txt " "
	disp as txt "STANDARD ERRORS UNDER IV, WITH SPATIAL CORRECTION AND WITH SPATIAL AND SERIAL CORRECTION:"
	estimates table IV spatial spatHAC, b(%7.3f) star(0.10 0.05 0.01)
}

//------------------------------------------------------------------
// cleaning up Mata environment

capture mata mata drop V invXX invXwwX XeeX XeeXh XeeX_spatial_HAC window_t window_i weight t i ti pi X1 Y1 e1 time1 n1 lat lon lat1 lon1 lat_scale lon_scale rows_ti rows_pi timeUnique panelUnique Ntime Npanel X X_var XeeX_spatial Y_var b dist_cutoff dist_var distance_i k lag_cutoff lag_var lat_var lon_var n panel panel_var  time_var weight_i
capture drop pseudoweight
/*
if "`bartlett'" == "bartlett" {
	capture mata mata drop weight_i			
}
*/

end



