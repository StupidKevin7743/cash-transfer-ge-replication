/* Install Stata packages that are required but not vendored in ado/. */
version 15.1
set more off

capture program drop ensure_ssc
program define ensure_ssc
    version 15.1
    syntax, Command(name) Package(name)

    capture which `command'
    if _rc {
        di as text "Installing SSC package `package' (provides `command')..."
        quietly ssc install `package'
        capture which `command'
        if _rc {
            di as error "Installation did not provide command `command'."
            exit 499
        }
    }
    else di as text "Found `command'."
end

ensure_ssc, command(project) package(project)
ensure_ssc, command(ivreg2) package(ivreg2)
ensure_ssc, command(ranktest) package(ranktest)
ensure_ssc, command(outreg2) package(outreg2)
ensure_ssc, command(insobs) package(insobs)
ensure_ssc, command(estout) package(estout)
ensure_ssc, command(eststo) package(estout)
ensure_ssc, command(esttab) package(estout)
ensure_ssc, command(estadd) package(estout)
ensure_ssc, command(_gwtmean) package(_gwtmean)
ensure_ssc, command(carryforward) package(carryforward)
ensure_ssc, command(coefplot) package(coefplot)
ensure_ssc, command(ineqdec0) package(ineqdec0)
ensure_ssc, command(mat2txt) package(mat2txt)
ensure_ssc, command(multproc) package(smileplot)
ensure_ssc, command(randtreat) package(randtreat)
ensure_ssc, command(strdist) package(strdist)
ensure_ssc, command(texdoc) package(texdoc)
ensure_ssc, command(tsegen) package(tsegen)
ensure_ssc, command(winsor2) package(winsor2)

capture which grc1leg
if _rc {
    di as text "Installing grc1leg from Stata's official user archive..."
    quietly net install grc1leg, from("https://www.stata.com/users/vwiggins/")
    capture which grc1leg
    if _rc {
        di as error "Installation did not provide command grc1leg."
        exit 499
    }
}
else di as text "Found grc1leg."

capture findfile scheme-tufte.scheme
if _rc {
    di as text "Installing SSC package scheme_tufte..."
    quietly ssc install scheme_tufte
    capture findfile scheme-tufte.scheme
    if _rc {
        di as error "Installation did not provide scheme-tufte.scheme."
        exit 499
    }
}
else di as text "Found scheme-tufte.scheme."

di as result "Stata dependency check completed successfully."
