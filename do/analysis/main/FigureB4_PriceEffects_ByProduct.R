#######
# Price Effect Distribution Charts
#######

#######
# Prelims
#######

required_packages <- c("haven", "scales")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing R package(s): ", paste(missing_packages, collapse = ", "),
       ". Run renv::restore() from the repository root.")
}

repo_root <- normalizePath(
  Sys.getenv("REPO_ROOT", unset = getwd()), mustWork = TRUE
)
run_root <- normalizePath(
  Sys.getenv("RUN_ROOT", unset = repo_root), mustWork = FALSE
)
figure_dir <- file.path(run_root, "results", "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

##########
# Import #
##########

price_file <- file.path(
  run_root, "temp", "PriceAnalysis_ProductLevel",
  "ProductLevel_pp_actamt_0to4km_noLag.csv"
)
classification_file <- file.path(repo_root, "rawdata", "expenditure_weights.dta")
rosetta_file <- file.path(repo_root, "rawdata", "expenditure_shares.dta")
missing_inputs <- c(price_file, classification_file, rosetta_file)[
  !file.exists(c(price_file, classification_file, rosetta_file))
]
if (length(missing_inputs)) {
  stop("Price-figure input(s) are missing: ",
       paste(missing_inputs, collapse = ", "),
       ". Run the section 3.7 Stata workflow and provide the authorized auxiliary inputs first.")
}

fx = read.csv(price_file)

classification = haven::read_dta(classification_file)
classification <- as.data.frame(classification)
rosetta = haven::read_dta(rosetta_file)
rosetta <- as.data.frame(rosetta)


coefs = data.frame("prd" = NA, "ATE" = NA, "ATEse" = NA, "AME" = NA, "AMEse" = NA, "optr" = NA, "optlag" = NA)

i = 1

for(col in 2:ncol(fx)){

  if(grepl("med_p", fx[1, col])){

    coefs[i,"prd"] = gsub("=med_p_", "", fx[1, col])
    coefs[i,"ATE"] = as.numeric(gsub("=", "", fx[grepl("=ATE", fx[,1]),col][1]))
    coefs[i,"ATEse"] = as.numeric(gsub("=", "", fx[grepl("=ATE", fx[,1]),col][2]))
    coefs[i,"AME"] = as.numeric(gsub("=", "", fx[grepl("=max", fx[,1]),col][1]))
    coefs[i,"AMEse"] = as.numeric(gsub("=", "", fx[grepl("=max", fx[,1]),col][2]))

    #coefs[i,"optr"] = as.numeric(gsub("=", "", fx[grepl("optr", fx[,1]),col]))
    #coefs[i,"optlag"] = as.numeric(gsub("=", "", fx[grepl("optlag", fx[,1]),col]))

    i = i+1
  }

}


#########################
# Merge Classifications #
#########################

for(p in coefs$prd){

  long_name = paste("med_p_", p, sep="")

  if(long_name %in% rosetta$GE_MS_code){

    coefs[coefs$prd==p, "long"] = rosetta[rosetta$GE_MS_code==long_name, "GE_MS_Name"]

    if(coefs[coefs$prd==p, "long"] %in% classification$product){
      coefs[coefs$prd==p, "trade_status"] = classification[classification$product==coefs[coefs$prd==p, "long"], "trade_status"]
    }
  }
}

# coefs[coefs$prd=="bull", "class"] = "Livestock"
# coefs[coefs$prd=="calf", "class"] = "Livestock"
# coefs[coefs$prd=="goatmeat", "class"] = "Food"
coefs[coefs$prd=="ironsheet", "trade_status"] = 1
# coefs[coefs$prd=="milkferment", "class"] = "Food"
# coefs[coefs$prd=="millet", "class"] = "Food"
coefs[coefs$prd=="papaya", "trade_status"] = 0
coefs[coefs$prd=="cigarettes", "trade_status"] = 1
coefs[coefs$prd=="roofnails", "trade_status"] = 1
# coefs[coefs$prd=="potatoes", "class"] = "Food"
# coefs[coefs$prd=="roofnails", "class"] = "Durables"
# coefs[coefs$prd=="sheep", "class"] = "Livestock"
coefs[coefs$prd=="slippers", "trade_status"] = 1
# coefs[coefs$prd=="sorghum", "class"] = "Food"


#######
# Plot
#######

pdf(file.path(figure_dir, "FigureB4_PriceEffects_ByProduct.pdf"), width = 11, height=8)

maxlim = 0.01

par(mar=c(4, 2, 4, 2))
colors = c("brown2", "goldenrod1", "grey","black")

coefs[coefs$trade_status==1 & !is.na(coefs$trade_status),"col"] = colors[1]
coefs[coefs$trade_status==0 & !is.na(coefs$trade_status),"col"] = colors[2]
coefs[is.na(coefs$trade_status),"col"] = colors[3]

plot(0,0, axes = F, ylab = "", xlab = "", type="n", ylim=c(1,nrow(coefs)), xlim=c(-maxlim*1.3, maxlim*1.3))


abline(v=0.0013, lty=2, lwd=2, col=scales::alpha(colors[4], .4))
text(0.0013, 1, "Aggregate Effect", pos=4, cex=.7)
#abline(v=0.0068, lty=2, lwd=2, col=alpha(colors[3], .4))

abline(v=0)


for(i in 1:nrow(coefs)){
  if(abs(coefs$ATE[order(coefs$ATE)][i])< (maxlim)){

    points(c(coefs$ATE[order(coefs$ATE)][i], 0), type="l", lend="butt", lwd=6, col=coefs$col[order(coefs$ATE)][i], c(i, i))
    text(coefs$ATE[order(coefs$ATE)][i], i,
         #labels=paste0(coefs$prd[order(coefs$ATE)][i], " [", coefs$optr[order(coefs$ATE)][i], ";", coefs$optlag[order(coefs$ATE)][i], "]"),
         labels=paste0(coefs$prd[order(coefs$ATE)][i]),
         pos = ifelse(coefs$ATE[order(coefs$ATE)][i]<0, 2, 4), cex=.7,
         col = ifelse(abs(coefs$ATE[order(coefs$ATE)][i] / coefs$ATEse[order(coefs$ATE)][i]) > 1.96, "black", "grey77"))
  } else{
    points(c(sign(coefs$ATE[order(coefs$ATE)][i])*maxlim, 0), type="l", lend="butt", lwd=6, col=coefs$col[order(coefs$ATE)][i], c(i, i), lty=11)
    text(sign(coefs$ATE[order(coefs$ATE)][i])*maxlim, i,
         #labels=paste0(coefs$prd[order(coefs$ATE)][i], " (", round(coefs$ATE[order(coefs$ATE)][i], 3)*100, "%)", " [", coefs$optr[order(coefs$ATE)][i], ";", coefs$optlag[order(coefs$ATE)][i], "]"),
         labels=paste0(coefs$prd[order(coefs$ATE)][i], " (", round(coefs$ATE[order(coefs$ATE)][i], 3)*100, "%)"),
         pos = ifelse(coefs$ATE[order(coefs$ATE)][i]<0, 2, 4), cex=.7,
         col = ifelse(abs(coefs$ATE[order(coefs$ATE)][i] / coefs$ATEse[order(coefs$ATE)][i]) > 1.96, "black", "grey77"))
  }
}

legend("topleft", pch = c(15, 15, 15), col=colors, legend = c("ATE, more tradable", "ATE, less tradable", "ATE, unclassified"), bty="n")

axis(1, at=seq(-maxlim, maxlim, 0.0025), labels = paste(seq(-maxlim, maxlim,0.0025)*100, "%", sep=""))

dev.off()
