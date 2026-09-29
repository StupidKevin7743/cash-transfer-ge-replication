program define pstar, rclass
*syntax anything , [PBRACKETs] [SEBRACKETs] [PNOPAR] [SENOPAR] [SESTAR] [PSTAR] p(real 0) [b(real 0)] [se(real 0)] 
*syntax anything [, PBRACKETs SEBRACKETs PNOPAR SENOPAR SESTAR PSTAR p(real) b(real) se(real) ]
syntax [anything] ,[p(real 0)] [se(real 0)] [b(real 0)] [n(real 1000000)] [PBRACKETs] [SEBRACKETs] [PNOPAR] [SENOPAR] [SESTAR] [PSTAR] [NOTEX] [PRECision(real 2)]
* pbrackets and sebrackets specifies that brackets be used instead of parentheses for p and se. 
* pNopar and senopar specifies that P and SEs are not in parentheses. 
* sestar and pstar specifies that the stars be printed next to the standard error and/or p-value rather than the coefficient.
* NOTEX specifies that the $*$ format be dropped for the stars

quietly { 

if "`precision'"=="" {
	local precision = 2
	}

dis "anything: `anything'. p: `p'. se: `se'"
* BASIC INPUTS: B, SE, P
* check if "anything" specifies a coefficient in a recent model that can be tested 
*capture test `anything'
if "`anything'"=="" {
	dis "cannot test this"
	* If b, p, or se options are specified, "anything" contains a number; use that number
	capture local thisse = `se'
	capture local thisp = `p'
	capture local thisb = `b'
}
*dis "`thisp'"

*dis "`thisp' `n'"
*if "`thisb'"~="0" & "`thisse'"~="0" & "`thisb'"~="" & "`thisse'"~=""  {
if "`thisp'"=="0" & "`thisb'"~="" & "`thisse'"~=""  {
	*di "b and se: `thisb' `thisse'"
	local thist = `thisb'/`thisse'
	local thisp= 2*ttail((e(N)-e(df_m)),abs(`thist'))
	}
* alternatively, if "anything" specifies a coefficient, test it and use the resulting b, p, se values
*else if "`anything'"~="" {
if "`anything'"~="" {
	*dis "can test this"
	local thisb = _b[`anything']
	local thisse = _se[`anything']
	test `anything'
	local thisp = `r( p )'
}

if "`p'"=="0" & "`anything'"=="" & "`thisse'"=="0" {
	local thisp = `p'
	}
	
*dis "b: `thisb'. se: `thisse'. p: `thisp'."

* STAR SIGN: goes onto coefficient by default
if "`notex'"~="" {
	if `thisp' < 0.01 {
		local bstar "***"
		}
	else if `thisp' < 0.05 {
		local bstar "**"
		}
	else if `thisp' < 0.1 {
		local bstar "*"
		}
	else {
		local bstar ""
		}
}
else {
if `thisp' < 0.01 {
		local bstar "$^{***}$"
		}
	else if `thisp' < 0.05 {
		local bstar "$^{**}$"
		}
	else if `thisp' < 0.1 {
		local bstar "$^{*}$"
		}
	else {
		local bstar ""
		}
}

* If SESTAR or PSTAR are specified, change it to se or p: 
if "`sestar'"~="" {
	local sestar "`bstar'"
	}
if "`pstar'"~="" {
	local pstar "`bstar'"
	}
if "`pstar'"~="" | "`sestar'"~="" {
	local bstar ""
}
	
* PARENTHESIS SIGNS
local separL "("
local separR ")"
local pparL "("
local pparR ")"

* if brackets are specified, use those
if "`sebrackets'"~="" {
	local separL "["
	local separR "]"
}
if "`pbrackets'"~="" {
	local pparL "["
	local pparR "]"
}

* Get rid of them if nopar is specified
if "`senopar'"~="" {
	local separL ""
	local separR ""
	}
if "`pnopar'"~="" {
	local pparL  ""
	local pparR  ""
	}

return local bstar = string(`thisb', "%9.`precision'f")+"`bstar'"
return local sestar = "`separL'" + string(`thisse', "%9.`precision'f")+"`separR'" + "`sestar'"
return local pstar = "`pparL'" + string(`thisp', "%9.`precision'f")+"`pparR'" + "`pstar'"

/*
if `thisp' < 0.01 {
	return local pstarb = string(`thisb', "%9.3f")+"$^{***}$"
	}
else if `thisp' < 0.05 {
	return local pstarb = string(`thisb', "%9.3f")+"$^{**}$"
	}
else if `thisp' < 0.1 {
	return local pstarb = string(`thisb', "%9.3f")+"$^{*}$"
	}
else {
	return local pstarb = string(`thisb', "%9.3f") 
	}
*dis "`separ'+string(`thisse', "%9.3f")+"`separ'"
return local pstarse = "`separ'"+string(`thisse', "%9.3f")+"`separ'"
*/

} //quietly
end
exit 
