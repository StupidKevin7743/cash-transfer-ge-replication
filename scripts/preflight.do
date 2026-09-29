/* Validate the code environment without opening or inspecting any data. */
version 15.1
set more off

if "${REPO_ROOT}" == "" global REPO_ROOT "`c(pwd)'"

adopath ++ "$REPO_ROOT/ado"

local required_files ///
    "config.do" ///
    "do/GE_global_setup.do" ///
    "do/global_runGPS.do" ///
    "scripts/run_eq1_eq2_outputs.do" ///
    "scripts/run_eq3_outputs.do" ///
    "scripts/run_eq4_eq6_price_outputs.do" ///
    "scripts/run_eq7_multiplier_outputs.do" ///
    "scripts/run_eq8_eq9_enterprise_outputs.do"

foreach f of local required_files {
    capture confirm file "$REPO_ROOT/`f'"
    if _rc {
        di as error "Repository preflight failed; missing file: `f'"
        exit 601
    }
}

local missing_commands ""
foreach cmd in project ivreg2 ranktest outreg2 insobs eststo esttab estadd ///
    carryforward coefplot _gwtmean grc1leg ineqdec0 mat2txt multproc ///
    randtreat strdist texdoc tsegen winsor2 estout ///
    ols_spatial_HAC iv_spatial_HAC minq pstar _gweightave calculate_optimal_radii {
    capture which `cmd'
    if _rc local missing_commands "`missing_commands' `cmd'"
}

if strtrim("`missing_commands'") != "" {
    di as error "Missing Stata command(s):`missing_commands'"
    di as error "Run: do \"$REPO_ROOT/scripts/install_stata_dependencies.do\""
    exit 499
}

capture findfile scheme-tufte.scheme
if _rc {
    di as error "Missing required Stata graph scheme: scheme-tufte.scheme"
    di as error "Run: do \"$REPO_ROOT/scripts/install_stata_dependencies.do\""
    exit 499
}

capture mkdir "$REPO_ROOT/outputs"
di as result "Code and dependency preflight completed successfully."
