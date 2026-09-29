###################
# Draw Epic Multiplier Figure
# Tilman Graff
# 2019-08-29
###################

required_packages <- c("haven", "scales", "plotrix")
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
irf_root <- file.path(run_root, "temp", "IRF_values")
figure_dir <- file.path(run_root, "results", "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

###################
# Import Data
###################

irfs = list.files(file.path(irf_root, "joint"), full.names = TRUE)
irfnames = basename(irfs)

irfs_treated = list.files(file.path(irf_root, "treated"), full.names = TRUE)
irfs_untreated = list.files(file.path(irf_root, "untreated"), full.names = TRUE)

for(this in c("irfs", "irfnames", "irfs_treated", "irfs_untreated")){
  x = get(this)
  xr = x[grepl("_r.txt", x)]
  assign(this, xr)
}

if (!length(irfs) || !length(irfs_treated) || !length(irfs_untreated)) {
  stop("Multiplier IRF inputs are missing under ", irf_root,
       ". Run the section 3.8 Stata workflow first.")
}

bootstrap_file <- file.path(irf_root, "bootstrap_rawoutput_r.dta")
if (!file.exists(bootstrap_file)) {
  stop("Multiplier bootstrap input is missing: ", bootstrap_file,
       ". Run the section 3.8 Stata workflow first.")
}
bootstrap_raw = haven::read_dta(bootstrap_file)
bootstrap_raw <- as.data.frame(bootstrap_raw)

bootstrap_raw$avg_mult = rowMeans(bootstrap_raw[,c("multiplier_exp", "multiplier_inc")])

jointresponses = data.frame()

for(i in 1:length(irfs)){
  name = gsub("_r_IRF_joint_r.txt", "", irfnames[i])

  df = read.delim(irfs[i])
  df = df[1,grepl("c", names(df))]

  jointresponses[i,"var"] = name
  jointresponses[i,"type"] = ifelse(name %in% c("nondurables_exp_wins", "totval_hhassets_h_wins", "ent_inv_wins", "ent_inventory_wins"), "exp", "inc")
  jointresponses[i,3:12] = df

  df = read.delim(irfs_untreated[grepl(name, irfs_untreated)])
  df = df[1:3,grepl("c", names(df))]
  assign(paste0(name, "_untreated"), df)

  df = read.delim(irfs_treated[grepl(name, irfs_treated)])
  df = df[1:3,grepl("c", names(df))]
  assign(paste0(name, "_treated"), df)

}

jointresponses$rowMin <- apply(jointresponses[,paste0("c", 1:10)], 1, function(x) min(x))
jointresponses$rowSum <- apply(jointresponses[,paste0("c", 1:10)], 1, function(x) sum(x))

jointresponses = jointresponses[order(jointresponses$rowMin),]

jointresponses[jointresponses$var=="nondurables_exp_wins", "nicename"] = "HH Non-Durable Expenditure"
jointresponses[jointresponses$var=="p3_3_wageearnings_wins", "nicename"] = "HH Wage Bill"
jointresponses[jointresponses$var=="ent_profit2_wins", "nicename"] = "ENT Profits"
jointresponses[jointresponses$var=="ent_rentcost_wins", "nicename"] = "ENT Capital Income"
jointresponses[jointresponses$var=="ent_inv_wins", "nicename"] = "ENT Investment"
jointresponses[jointresponses$var=="ent_totaltaxes_wins", "nicename"] = "ENT Taxes Paid"
jointresponses[jointresponses$var=="ent_inventory_wins", "nicename"] = "ENT Inventory"
jointresponses[jointresponses$var=="totval_hhassets_h_wins", "nicename"] = "HH Durable Expenditure"

###################
# Draw Joint Plot
###################

colors_exp = c("goldenrod1", "sandybrown", "firebrick1", "darkorange2")
colors_inc = c("plum", "violetred","royalblue3",  "deepskyblue")

pdf(file.path(figure_dir, "Figure1_Multiplier.pdf"), width = 10, height = 8)

#par(mfrow=c(2,3), oma = c(1,1,1,0) + 0.1, mar = c(1.5,2,0.8,1) + 0.1)

layout(matrix(c(1,1,1,2,2,2,3,3,1,1,1,2,2,2,3,3,4,4,4,5,5,5,6,6,4,4,4,5,5,5,6,6), nrow = 4, ncol = 8, byrow = TRUE))

###################
# Draw CummPlot
###################

for(mult in c("exp", "inc")){

  if(mult == "exp"){
    par(mar = c(.5,3.8,0.5,0) + 0.1)
  }else{
    par(mar = c(.5,2,0.5,0) + 0.1)
  }


  writtenout = ifelse(mult == "exp", "expenditure", "income")
  colors = get(paste0("colors_", mult))


  plot(1,1, xlim = c(1,12.3), ylim = c(-0.2, 3.2), type="n", bty='n', axes=F, xlab="", ylab=paste0("Cummulative multiplier"), main = "")

  title(ifelse(mult == "exp", "Panel A: Expenditure multiplier", "Panel B: Income multiplier"), line=-1)

  points(c(0,10.5), c(0,0), type = "l", lty = 3)
  points(c(0,10.5), c(1,1), type = "l", lty = 3)



  cummult = 0
  se = 0

  for(q in 1:10){
    cummult = c(cummult, cummult[length(cummult)]+ sum(jointresponses[jointresponses$type==mult,paste0("c", q)]))
    if(q == 1){
      se = c(se, sd(bootstrap_raw[,paste0("multiplier_", mult, "_q", q)]))
    }
    if(q > 1){
      se = c(se, sd(rowSums(bootstrap_raw[,paste0("multiplier_", mult, "_q", 1:q)])))
    }
  }

  cummult = cummult[2:11]
  se = se[2:11]

  if(mult == "exp"){
    expmult = cummult[length(cummult)]
  }else{
    incmult = cummult[length(cummult)]
  }

  points(1:10, cummult, type = "l", col = colors[2], lwd = 2)
  #polygon(x = c(1:10, 10:1), y = c(cummult+se, rev(cummult-se)), border = NA, col = alpha(colors[1], .4))


  # draw whiskers

  bars = as.numeric(quantile(bootstrap_raw[,paste0("multiplier_", mult)], probs = c(0.05, 0.1)))
  points(c(10,10), c(cummult[length(cummult)], bars[1]), type = "o", pch = "", col = "black", lwd = 1.5)

  points(c(10,10), bars, pch = "-----", col = "black", cex = 2)
  text(c(10,10), bars, pch = "-----", labels = c("95%", "90%"), pos = 2, col = "black", cex = 1)

  for(hval in 0:1){
    pv = round(sum(bootstrap_raw[,paste0("multiplier_", mult)] < hval) / nrow(bootstrap_raw), 2)
    plotrix::textbox(c(10.2,12.3), hval+0.07, paste0("p = ", pv), justify="l", border= "white", fill="white", col = "black", cex = 1.2)
    #text(10, hval+0.07, labels = paste0("p = ", pv), pos = 4, cex = 1.2)
    #text(10.2, hval+0.07, labels = TeX(paste0("$$H_0: M_{",mult,"} < ",hval,"$$")), pos = 4, cex = 1.2)
    #text(10.2, hval-0.1, labels = paste0("p = ", pv), pos = 4, cex = 1.2)
  }

  points(10, cummult[length(cummult)], pch = 19, col = colors[2], cex = 2)
  text(10.1, cummult[length(cummult)]+0.1, pos = 4, round(cummult[length(cummult)], 2), cex = 1.7)


  axis(2)


}


###################
# Draw awkward additional whiskers
###################

plot(1,1, xlim = c(0.8,2), ylim = c(-0.2, 3.2), type="n", bty='n', axes=F, xlab="", ylab=paste0("Cummulative multiplier"))

title("Panel C: Both multipliers", line = -1)

points(c(0,2.1), c(0,0), type = "l", lty = 3)
points(c(0,2.1), c(1,1), type = "l", lty = 3)

axis(2)


##### average

avg_value = (expmult + cummult[length(cummult)])/2


bars = as.numeric(quantile(bootstrap_raw[,paste0("avg_mult")], probs = c(0.05, 0.1)))
points(c(1,1), c(avg_value, bars[1]), type = "o", pch = "", col = "black", lwd = 1.5)

points(c(1,1), bars, pch = "-----", col = "black", cex = 2)
text(c(1,1), bars, pch = "-----", labels = c("95%", "90%"), pos = 2, col = "black", cex = 1)

for(hval in 0:1){
  pv = round(sum(bootstrap_raw[,paste0("avg_mult")] < hval) / nrow(bootstrap_raw), 2)
  plotrix::textbox(c(1.01,1.35), hval+0.07, paste0("p = ", pv), justify="l", border= "white", fill="white", col = "black", cex = 1.2)
  #text(1, hval, labels = paste0("p = ", pv), pos = 4, cex = 1.2)
  #text(1.03, hval+0.07, labels = TeX(paste0("$$H_0: M_{avg} < ",hval,"$$")), pos = 4, cex = 1.2)
  #text(1.03, hval-0.1, labels = paste0("p = ", pv), pos = 4, cex = 1.2)
}

points(1, avg_value, pch = 19, col = "black", cex = 2)
text(1.02, avg_value+0.1, pos = 4, round(avg_value, 2), cex = 1.8)


##### joint

bars = as.numeric(quantile(pmax(bootstrap_raw[,"multiplier_inc"], bootstrap_raw[,"multiplier_exp"]), probs = c(0.05, 0.1)))
points(c(1.7,1.7), c(avg_value-1, bars[1]), type = "o", pch = "", col = "black", lwd = 1.5)

# this is to fake a fading line
for(stretch in seq(0,1,0.01)) {
  points(c(1.7,1.7), c(avg_value-1+stretch, avg_value-1+stretch+0.01), type = "l", col = scales::alpha("black", 1-stretch), lwd = 1.5, lend = "butt")
}

points(c(1.7,1.7), bars, pch = "-----", col = "black", cex = 2)
text(c(1.7,1.7), bars, pch = "-----", labels = c("95%", "90%"), pos = 2, col = "black", cex = 1)


for(hval in 0:1){
  pv = round(sum(bootstrap_raw[,paste0("multiplier_exp")] < hval & bootstrap_raw[,paste0("multiplier_inc")] < hval) / nrow(bootstrap_raw), 2)
  plotrix::textbox(c(1.71,2.15), hval+0.07, paste0("p = ", pv), justify="l", border= "white", fill="white", col = "black", cex = 1.2)
  #text(1.7, hval+0.2, labels = TeX(paste0("$$H_0: M_{exp} < ",hval,"$$")), pos = 4, cex = 1.2)
  #text(2, hval+0.07, labels = TeX(paste0("& $$M_{inc} < ",hval,"$$")), pos = 4, cex = 1.2)
  #text(1.7, hval-0.1, labels = paste0("p = ", pv), pos = 4, cex = 1.2)
}

text(1, 3, pos = 1, "Average", cex = 1.3)
text(1.7, 3, pos = 1, "Joint\ntest", cex = 1.3)


###################
# Draw component plot
###################

for(mult in c("exp", "inc")){

  if(mult == "exp"){
    par(mar = c(4,3.8,0.8,0) + 0.1)
  }else{
    par(mar = c(4,2,0.8,0) + 0.1)
  }


  plot(1,1, xlim = c(1,12.3), ylim = c(-0.4, 1.2), type="n", bty='n', axes=F, ylab="Quarterly multiplier estimates", xlab = "Months since first transfer                     ")

  agg_series = rep(0, 10)
  agg_series1 = rep(0, 10)

  colors = get(paste0("colors_", mult))

  points(x = c(0.5, 10.5), y = c(0,0), type = "l")

  for(i in 1:4){

    thisseries = jointresponses[which(jointresponses$type==mult)[i],paste0("c", 1:10)]
    agg_series = agg_series + thisseries


    polygon(x = c(1:10, 10:1), y = c(agg_series1, rev(agg_series)), col = scales::alpha(colors[i], .5), border = NA)

    agg_series1 = agg_series

  }

  points(x = 1:10, y = agg_series, type='l', lwd = 3)

  for(q in 1:10){
    se = sd(bootstrap_raw[,paste0("multiplier_", mult, "_q", q)])
    points(x=c(q,q), y=c(agg_series[q]+se, agg_series[q]-se), type = "o", pch="-")
  }

  xtrachars = max(nchar(jointresponses[which(jointresponses$type==mult),"nicename"])) - nchar(jointresponses[which(jointresponses$type==mult),"nicename"])
  blanks = function(x){
    return(paste(rep("", x), collapse = ""))
  }

  a <- jointresponses[which(jointresponses$type==mult),]
  a$order <- seq.int(nrow(a))
  a = a[order(a$rowSum),]
  legcolors = c(colors[a$order[1]],colors[a$order[2]],colors[a$order[3]],colors[a$order[4]])
  jointresponses = jointresponses[order(jointresponses$rowSum),]

  legend(x = 3.5, y = 1.2, legend = rev(paste0(jointresponses[which(jointresponses$type==mult),"nicename"])), col = rev(legcolors), pch = 19, bty="n", cex=1, y.intersp=0.8, x.intersp = 0.8, ncol = 1, title = "Components", title.adj = 0.05)
  #legend(x = 3.5, y = 1.2, legend = rev(paste0(jointresponses[which(jointresponses$type==mult),"nicename"], sapply(xtrachars, "blanks"), " (", round(jointresponses[which(jointresponses$type==mult),"rowSum"], 2), ")")), col = rev(colors), pch = 19, bty="n", cex=1, y.intersp=0.8, x.intersp = 0.8, ncol = 1, title = "Individual components", title.adj = 0.05)

  contributions=rev(format(round(jointresponses[which(jointresponses$type==mult),"rowSum"], 2),nsmall=2))
  par(lheight=.8)
  text(11,1.245,"Total\ncontribution:",pos=1, cex=1)
  text(11,1.105,paste0(contributions[1],"\n",contributions[2],"\n",contributions[3],"\n",contributions[4]),pos=1, cex=1)
  if(mult == "exp"){
    text(11,0.86,round(expmult, 2),pos=1, cex=1.2)
  }else{
    text(11,0.86,round(incmult, 2),pos=1, cex=1.2)
  }
  segments(10.4,0.87,11.6,0.87, lty = 1)


  axis(2)
  axis(1, at = 1:10, labels = seq(0,27,3))

}


dev.off()



###################
# By treatment status
###################

treatedinc_sum = 0
treatedexp_sum = 0

for(i in irfs_treated){
  name = basename(i)
  name = gsub("_r_IRF_treat_r.txt", "", name)
  x = read.delim(i)
  if(name %in% c("p2_exp_mult_wins", "totval_hhassets_wins", "p3_3_wageearnings_wins")){
    weight = 1
  }else{
    weight = 3.005
  }

  if(name %in% c("p2_exp_mult_wins", "totval_hhassets_wins", "ent_inv_wins", "ent_inventory_wins")){
    treatedexp_sum = treatedexp_sum + sum(x[1,2:11]) * weight
  } else{
    treatedinc_sum = treatedinc_sum + sum(x[1,2:11]) * weight
  }
}


untreatedinc_sum = 0
untreatedexp_sum = 0

for(i in irfs_untreated){
  name = basename(i)
  name = gsub("_r_IRF_untreat_r.txt", "", name)
  if(name %in% c("p2_exp_mult_wins", "totval_hhassets_wins", "p3_3_wageearnings_wins")){
    weight = 4.9145313
  }else{
    weight = 2.9089
  }
  x = read.delim(i)

  if(name %in% c("p2_exp_mult_wins", "totval_hhassets_wins", "ent_inv_wins", "ent_inventory_wins")){
    untreatedexp_sum = untreatedexp_sum + sum(x[1,2:11])*weight
  } else{
    untreatedinc_sum = untreatedinc_sum + sum(x[1,2:11])*weight
  }
}




###################
# Draw Individual Plot
###################


#   names = jointresponses[jointresponses$type==mult,"var"]
#
#   # Optional split-treatment figures may be written below figure_dir.
#   par(mfrow = c(1, 2), mar = c(4,4,3,1))
#
#   for(type in c("treated", "untreated")){
#
#     plot(1,1, xlim = c(1,10), ylim = c(-0.4, ifelse(mult=="exp", 0.5, 0.8)), type="n", bty='n', axes=F, xlab="Months since first transfer", ylab="Effect relative to size of transfer", main = ifelse(type == "treated", "Treated", "Untreated"))
#     axis(1, at = 1:10, labels = seq(0,27,3))
#     axis(2)
#
#     abline(a = 0, b= 0)
#
#     colnum = 1
#
#     for(name in names){
#       thiscolor = ifelse(mult=="exp", colors_exp[colnum], colors_inc[colnum])
#       colnum = colnum + 1
#
#
#       df = get(paste(name, type, sep="_"))
#
#       points(1:10, df[1,], type="l", col = thiscolor, lwd = 2)
#
#       polygon(x = c(1:10, 10:1), y = c(df[2,], rev(df[3,])), col = alpha(thiscolor, .5), border = NA)
#
#     }
#   }
#   dev.off()
#
# }
