/**************************************************************************
* Author: KWEKE NGAHANE Stephane & Salma El AAZDOUDI
* Project: Innovation and Climate Change in U.S. Agriculture
* STATA version: 14
*
* PROJECT SYNOPSIS
* This do-file analyzes the relationship between extreme heat exposure,
* agricultural innovation, and climate change adaptation in U.S. agriculture.
* The project is inspired by and extends the framework of Moscona and Sastry
* (Quarterly Journal of Economics, 2023), "Does Directed Innovation Mitigate
* Climate Damage? Evidence from U.S. Agriculture".
* 
* HOW TO RUN
*   1) Set $root below to your project folder (parent of /data, /do, /output).
*   2) Ensure the folder structure exists.
*   3) Include a data folder outside of the root
*   4) Execute this do-file in Stata.
*   5) Output tables, figures will be saved under /output.
******************************************************************************/

* 0) setting Work directory and check dependencies

clear all

***************************** Question 1 : Heat exposure and crop yields ******************

// edit : project root (folder containing /data /do and /output)
global root "C:\Users\steph\Documents\ENSAE\3A\Environmental Econ\Innovation-and-climate-change"
cd "${root}"



*importing panel data
use "../data/us_panel_short_burkeemmerick.dta", clear


* building county identifiers
//fips = state*1000 + county
gen state_fips = floor(fips/1000)
gen cnty_fips  = mod(fips,1000)

label var state_fips "State FIPS"
label var cnty_fips  "County FIPS"

*creating decade
gen decade = floor(year/10)*10
label var decade "Decade"

tempfile yields_raw
save `yields_raw', replace


* importaing county*crop

import delimited "../data/crop_x_county_shocks.csv", clear varnames(1)

//dealing variables names starting with numbers
foreach v of varlist _all {
    local lab : variable label `v'
    
    
    if "`lab'" != "" {
        
        local newname = lower("`lab'")
        local newname = subinstr("`newname'","-","_",.)
        local newname = subinstr("`newname'"," ","_",.)
        
        if regexm("`newname'","^[0-9]") {
            local newname = "c`newname'"
        }
        
        local newname = substr("`newname'",1,32)
        
        capture rename `v' `newname'
    }
}
tempfile shocks_wide
save `shocks_wide', replace

use `shocks_wide', clear

// selecting interesting crops
keep state_fips cnty_fips ///
     c115_gddhot_1950 c115_gddhot_1960 c115_gddhot_1970 c115_gddhot_1980 c115_gddhot_1990 c115_gddhot_2000 c115_gddhot_2010 ///
     c130_gddhot_1950 c130_gddhot_1960 c130_gddhot_1970 c130_gddhot_1980 c130_gddhot_1990 c130_gddhot_2000 c130_gddhot_2010 ///
     c139_gddhot_1950 c139_gddhot_1960 c139_gddhot_1970 c139_gddhot_1980 c139_gddhot_1990 c139_gddhot_2000 c139_gddhot_2010

reshape long c115_gddhot_ c130_gddhot_ c139_gddhot_, i(state_fips cnty_fips) j(decade)
rename c115_gddhot_ corn_gddhot
rename c130_gddhot_ soy_gddhot
rename c139_gddhot_ cotton_gddhot

tempfile shocks_long
save `shocks_long', replace

* merging datasets

use `yields_raw', clear
merge m:1 state_fips cnty_fips decade using `shocks_long'

tab _merge
drop if _merge!=3 // 3900  unmatched over 164391 matched
drop _merge

* rearanging stuffs

rename cornyield   yield1
rename soyyield    yield2
rename cottonyield yield3

rename corn_gddhot   exposure1
rename soy_gddhot    exposure2
rename cotton_gddhot exposure3

reshape long yield exposure, i(fips state_fips cnty_fips year decade) j(crop_id)

gen crop_type = ""
replace crop_type = "corn"   if crop_id==1
replace crop_type = "soy"    if crop_id==2
replace crop_type = "cotton" if crop_id==3

gen lnyield = log(yield) if !missing(yield)

label var lnyield   "Log yield"
label var exposure  "Extreme heat exposure"
label var crop_type "Crop"

replace exposure = exposure/1000


preserve

************************************************************
* TABLE 1: END-OF-DECADE YIELDS
************************************************************

* End-of-decade years only
keep if inlist(year,1959,1969,1979,1989,1999,2009)

eststo clear

* Column 1: Corn
reghdfe lnyield exposure if crop_type=="corn" & !missing(lnyield, exposure), ///
    absorb(fips decade) vce(cluster cnty_fips)
eststo col1
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "No"

* Column 2: Soy
reghdfe lnyield exposure if crop_type=="soy" & !missing(lnyield, exposure), ///
    absorb(fips decade) vce(cluster cnty_fips)
eststo col2
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "No"

* Column 3: Cotton
reghdfe lnyield exposure if crop_type=="cotton" & !missing(lnyield, exposure), ///
    absorb(fips decade) vce(cluster cnty_fips)
eststo col3
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "No"

* Column 4: pooled
reghdfe lnyield exposure if !missing(lnyield, exposure), ///
    absorb(fips crop_type decade) vce(cluster cnty_fips)
eststo col4
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "Yes"

esttab col1 col2 col3 col4 using "outputs\tables\Table1_end_of_decade.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.4f) se(%9.4f) ///
    mtitles("Corn" "Soy" "Cotton" "Pooled") ///
    title("Table 1. End-of-decade yields and extreme heat exposure") ///
    stats(N r2, fmt(%9.0g %9.3f) labels("Observations" "R-squared"))

esttab col1 col2 col3 col4 using "outputs/tables/Table1_end_of_decade.tex", replace ///
    booktabs label ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Corn" "Soy" "Cotton" "Pooled") ///
    title("End-of-decade Yields and Extreme Heat Exposure") ///
    varlabels(exposure "Extreme heat exposure/1000") ///
    coeflabels(exposure "Extreme heat exposure") ///
    stats(county_fe decade_fe crop_fe N r2, ///
          labels("County fixed effects" "Decade fixed effects" "Crop fixed effects" "Observations" "$R^2$") ///
          fmt(0 0 0 %9.0fc %9.3f)) ///
    drop(_cons) ///
    nonotes ///
    addnotes("Standard errors clustered at the county level in parentheses.", ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

restore


preserve
************************************************************
* TABLE 2: DECADE-AVERAGE YIELDS
************************************************************

* Collapse annual yields to county x decade x crop
collapse (mean) yield exposure, by(fips cnty_fips decade crop_type)

gen lnyield = log(yield) if yield>0

eststo clear

* Column 1: Corn
reghdfe lnyield exposure if crop_type=="corn" & !missing(lnyield, exposure), ///
    absorb(fips decade) vce(cluster cnty_fips)
eststo col1
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "No"

* Column 2: Soy
reghdfe lnyield exposure if crop_type=="soy" & !missing(lnyield, exposure), ///
    absorb(fips decade) vce(cluster cnty_fips)
eststo col2
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "No"

* Column 3: Cotton
reghdfe lnyield exposure if crop_type=="cotton" & !missing(lnyield, exposure), ///
    absorb(fips decade) vce(cluster cnty_fips)
eststo col3
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "No"

* Column 4: pooled
reghdfe lnyield exposure if !missing(lnyield, exposure), ///
    absorb(fips crop_type decade) vce(cluster cnty_fips)
eststo col4
estadd local county_fe "Yes"
estadd local decade_fe "Yes"
estadd local crop_fe   "Yes"

esttab col1 col2 col3 col4 using "outputs\tables\Table2_decade_average.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.4f) se(%9.4f) ///
    mtitles("Corn" "Soy" "Cotton" "Pooled") ///
    title("Table 2. Decade-average yields and extreme heat exposure") ///
    stats(N r2, fmt(%9.0g %9.3f) labels("Observations" "R-squared"))


esttab col1 col2 col3 col4 using "outputs/tables/Table2_decade_average.tex", replace ///
    booktabs label ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Corn" "Soy" "Cotton" "Pooled") ///
    title("Decade-Average Yields and Extreme Heat Exposure") ///
    varlabels(exposure "Extreme heat exposure/1000") ///
    coeflabels(exposure "Extreme heat exposure") ///
    stats(county_fe decade_fe crop_fe N r2, ///
          labels("County fixed effects" "Decade fixed effects" "Crop fixed effects" "Observations" "$R^2$") ///
          fmt(0 0 0 %9.0fc %9.3f)) ///
    drop(_cons) ///
    nonotes ///
    addnotes("Standard errors clustered at the county level in parentheses.", ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

restore 

************************************************************
* TABLE 3: HETEROGENEITY
************************************************************


preserve

collapse (mean) yield exposure, by(fips cnty_fips decade crop_id)

gen lnyield = log(yield) if yield>0

reghdfe lnyield c.exposure##i.crop_id if !missing(lnyield, exposure), ///
    absorb(fips decade) vce(cluster fips)

eststo hetero_eod

* 2. Add FE indicators
estadd local countycrop_fe "Yes"
estadd local decade_fe     "Yes"

* 3. Joint test of equal slopes across crops
testparm 2.crop_id#c.exposure 3.crop_id#c.exposure
estadd scalar p_joint = r(p)

* 4. Pairwise tests
test 2.crop_id#c.exposure = 0
estadd scalar p_soy_vs_corn = r(p)

test 3.crop_id#c.exposure = 0
estadd scalar p_cotton_vs_corn = r(p)

test 2.crop_id#c.exposure = 3.crop_id#c.exposure
estadd scalar p_soy_vs_cotton = r(p)

* 5. Implied slopes by crop
lincom c.exposure
estadd scalar slope_corn = r(estimate)

lincom c.exposure + 2.crop_id#c.exposure
estadd scalar slope_soy = r(estimate)

lincom c.exposure + 3.crop_id#c.exposure
estadd scalar slope_cotton = r(estimate)

* 6. Export LaTeX table
esttab hetero_eod using "outputs/tables/Table_heterogeneity_end_of_decade.tex", replace ///
    booktabs label ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    mtitle("Interaction model") ///
    keep(exposure 2.crop_id#exposure 3.crop_id#exposure) ///
    order(exposure 2.crop_id#exposure 3.crop_id#exposure) ///
    coeflabels( ///
        exposure              "Extreme heat exposure (Corn)" ///
        2.crop_id#c.exposure    "Additional effect for Soy $\times$ exposure" ///
        3.crop_id#c.exposure    "Additional effect for Cotton $\times$ exposure" ///
    ) ///
    stats(slope_corn slope_soy slope_cotton ///
          p_joint p_soy_vs_corn p_cotton_vs_corn p_soy_vs_cotton ///
          countycrop_fe decade_fe N r2, ///
          labels( ///
            "Implied slope: Corn" ///
            "Implied slope: Soy" ///
            "Implied slope: Cotton" ///
            "p-value: equal slopes (joint test)" ///
            "p-value: Soy = Corn" ///
            "p-value: Cotton = Corn" ///
            "p-value: Soy = Cotton" ///
            "County $\times$ crop fixed effects" ///
            "Decade fixed effects" ///
            "Observations" ///
            "$R^2$" ///
          ) ///
          fmt(3 3 3 3 3 3 3 0 0 %9.0fc 3)) ///
    nonotes ///
    addnotes( ///
        "Dependent variable: log yield.", ///
        "Base category is Corn.", ///
        "The coefficient on extreme heat exposure reports the slope for Corn.", ///
        "The interaction coefficients report how the Soy and Cotton slopes differ from the Corn slope.", ///
        "Standard errors clustered at the county level in parentheses.", ///
        "* p$<$0.10, ** p$<$0.05, *** p$<$0.01." ///
    )

restore


***************************** Question 2 : Heat exposure and introduction of new varieties ******************

use "../data/crop_level_data.dta", clear

* Keep only the years needed to build the 1970–2000 long difference
keep if inlist(year, 1970, 2000)

* We only need the variables relevant for the new long-difference exercise
keep id crop_censusname year ///
     ncrop hot_gdd_panel ///
     log_total_area pre_precip pre_avgtemp ///
     max_temp max_temp_2


reshape wide ncrop hot_gdd_panel, i(id crop_censusname log_total_area pre_precip pre_avgtemp max_temp max_temp_2) j(year)

* constructing variables of interest

// number of new varieties developed during the period 1970–2000
gen ld_variety_70 = ncrop2000 - ncrop1970
label var ld_variety_70 "New varieties, 1970--2000"

//change in crop-level extreme heat exposure between 1970 and 2000
gen ld_hot_gdd_70 = (hot_gdd_panel2000 - hot_gdd_panel1970)/10
label var ld_hot_gdd_70 "Change in extreme exposure, 1970--2000"

//Baseline innovation control, specific to our period
gen asinh_ncrop_1970 = asinh(ncrop1970)
label var asinh_ncrop_1970 "asinh(initial varieties, 1970)"

//Keep estimation sample
drop if missing(ld_variety_70, ld_hot_gdd_70)

//Quick checks
summ ld_variety_70 ld_hot_gdd_70 asinh_ncrop_1970
count

*==========================================================*
* TABLE 1: Poisson specifications
*==========================================================*
eststo clear

* (1) Market size only
poisson ld_variety_70 ld_hot_gdd_70 log_total_area, vce(robust)
eststo p1
estadd local preclim "No"
estadd local initinnov "No"
estadd local threshold "No"

* (2) + pre-period climate
poisson ld_variety_70 ld_hot_gdd_70 log_total_area pre_precip pre_avgtemp, vce(robust)
eststo p2
estadd local preclim "Yes"
estadd local initinnov "No"
estadd local threshold "No"

* (3) + initial innovation in 1970
poisson ld_variety_70 ld_hot_gdd_70 log_total_area pre_precip pre_avgtemp asinh_ncrop_1970, vce(robust)
eststo p3
estadd local preclim "Yes"
estadd local initinnov "Yes"
estadd local threshold "No"

* (4) + crop heat-threshold controls
poisson ld_variety_70 ld_hot_gdd_70 log_total_area pre_precip pre_avgtemp ///
       asinh_ncrop_1970 max_temp max_temp_2, vce(robust)
eststo p4
estadd local preclim "Yes"
estadd local initinnov "Yes"
estadd local threshold "Yes"

* exporting in rtf

esttab p1 p2 p3 p4 using "outputs\tables\Table_RQ2_Poisson_1970_2000.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) se(%9.3f) ///
	mtitles("(1)" "(2)" "(3)" "(4)") ///
	nonumbers  ///
    title("Table RQ2. Heat Exposure and New Varieties, 1970--2000 (Poisson)") ///
    keep(ld_hot_gdd_70) ///
    order(ld_hot_gdd_70) ///
    coeflabels(ld_hot_gdd_70 "Change in extreme exposure") ///
    stats(preclim initinnov threshold N, ///
          labels("Pre-period climate controls" "Initial innovation control" "Heat-threshold controls" "Observations") ///
          fmt(0 0 0 %9.0fc)) ///
    addnotes("Dependent variable: number of new varieties developed between 1970 and 2000.", ///
             "Robust standard errors in parentheses.", ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

* exporting in Latex 

esttab p1 p2 p3 p4 using "outputs\tables\Table_RQ2_Poisson_1970_2000.tex", replace ///
    booktabs label ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) se(%9.3f) ///
    mtitles("(1)" "(2)" "(3)" "(4)") ///
	nonumbers  ///
    title("Heat Exposure and New Varieties, 1970--2000 (Poisson)") ///
    keep(ld_hot_gdd_70) ///
    order(ld_hot_gdd_70) ///
    coeflabels(ld_hot_gdd_70 "Change in extreme exposure") ///
    stats(preclim initinnov threshold N, ///
          labels("Pre-period climate controls" "Initial innovation control" "Heat-threshold controls" "Observations") ///
          fmt(0 0 0 %9.0fc)) ///
    nonotes ///
    addnotes("Dependent variable: number of new varieties developed between 1970 and 2000.", ///
             "Robust standard errors in parentheses.", ///
             "* p$<$0.10, ** p$<$0.05, *** p$<$0.01.")

			 
*==========================================================*
* TABLE 2: Linear specifications (OLS)
*==========================================================*
eststo clear

* (1) Market size only
reg ld_variety_70 ld_hot_gdd_70 log_total_area, vce(robust)
eststo o1
estadd local preclim "No"
estadd local initinnov "No"
estadd local threshold "No"

* (2) + pre-period climate
reg ld_variety_70 ld_hot_gdd_70 log_total_area pre_precip pre_avgtemp, vce(robust)
eststo o2
estadd local preclim "Yes"
estadd local initinnov "No"
estadd local threshold "No"

* (3) + initial innovation in 1970
reg ld_variety_70 ld_hot_gdd_70 log_total_area pre_precip pre_avgtemp asinh_ncrop_1970, vce(robust)
eststo o3
estadd local preclim "Yes"
estadd local initinnov "Yes"
estadd local threshold "No"

* (4) + crop heat-threshold controls
reg ld_variety_70 ld_hot_gdd_70 log_total_area pre_precip pre_avgtemp ///
    asinh_ncrop_1970 max_temp max_temp_2, vce(robust)
eststo o4
estadd local preclim "Yes"
estadd local initinnov "Yes"
estadd local threshold "Yes"


* exporting in rtf

esttab o1 o2 o3 o4 using "outputs\tables\Table_RQ2_OLS_1970_2000.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) se(%9.3f) ///
    mtitles("(1)" "(2)" "(3)" "(4)") ///
	nonumbers ///
    title("Table RQ2. Heat Exposure and New Varieties, 1970--2000 (OLS)") ///
    keep(ld_hot_gdd_70) ///
    order(ld_hot_gdd_70) ///
    coeflabels(ld_hot_gdd_70 "Change in extreme exposure") ///
    stats(preclim initinnov threshold N r2, ///
          labels("Pre-period climate controls" "Initial innovation control" "Heat-threshold controls" "Observations" "$R^2$") ///
          fmt(0 0 0 %9.0fc %9.3f)) ///
    addnotes("Dependent variable: number of new varieties developed between 1970 and 2000.", ///
             "Robust standard errors in parentheses.", ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

* exporting in Latex

esttab o1 o2 o3 o4 using "outputs\tables\Table_RQ2_OLS_1970_2000.tex", replace ///
    booktabs label ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) se(%9.3f) ///
    mtitles("(1)" "(2)" "(3)" "(4)") ///
	nonumbers ///
    title("Heat Exposure and New Varieties, 1970--2000 (OLS)") ///
    keep(ld_hot_gdd_70) ///
    order(ld_hot_gdd_70) ///
    coeflabels(ld_hot_gdd_70 "Change in extreme exposure") ///
    stats(preclim initinnov threshold N r2, ///
          labels("Pre-period climate controls" "Initial innovation control" "Heat-threshold controls" "Observations" "$R^2$") ///
          fmt(0 0 0 %9.0fc %9.3f)) ///
    nonotes ///
    addnotes("Dependent variable: number of new varieties developed between 1970 and 2000.", ///
             "Robust standard errors in parentheses.", ///
             "* p$<$0.10, ** p$<$0.05, *** p$<$0.01.")

display "RQ2 tables successfully created in outputs/tables/"






***************************** Question 3 : Marginal effects of innovation on land values ******************


use "../data/county_level_data.dta", clear
summ lland_value_acre ee loo ee_innov

// keep the same structure as the author to ensure comparability

preserve

keep if year==1950 | year ==2010

reghdfe lland_value_acre ee loo ee_innov, ///
    absorb(id year#state) ///
    vce(cluster id state_year)
	
* computing quantiles values of exposure

quietly summarize ee, detail

local q10 = r(p10)
local q25 = r(p25)
local q50 = r(p50)
local q75 = r(p75)
local q90 = r(p90)

display "p10 ee = `q10'"
display "p25 ee = `q25'"
display "p50 ee = `q50'"
display "p75 ee = `q75'"
display "p90 ee = `q90'"


gen quantile = _n
replace quantile = . if quantile>100

gen beta_quant = .
gen se_quant   = .

* computing marginal effects

lincom loo + `q10'*ee_innov
replace beta_quant = r(estimate) if quantile==10
replace se_quant   = r(se)       if quantile==10

lincom loo + `q25'*ee_innov
replace beta_quant = r(estimate) if quantile==25
replace se_quant   = r(se)       if quantile==25

lincom loo + `q50'*ee_innov
replace beta_quant = r(estimate) if quantile==50
replace se_quant   = r(se)       if quantile==50

lincom loo + `q75'*ee_innov
replace beta_quant = r(estimate) if quantile==75
replace se_quant   = r(se)       if quantile==75

lincom loo + `q90'*ee_innov
replace beta_quant = r(estimate) if quantile==90
replace se_quant   = r(se)       if quantile==90


* confidence intervals

gen ci_up     = beta_quant + 1.96*se_quant
gen ci_down   = beta_quant - 1.96*se_quant
gen ci_up_90  = beta_quant + 1.645*se_quant
gen ci_down_90= beta_quant - 1.645*se_quant

* Graphs

twoway ///
    (rcap ci_up ci_down quantile, lcolor(gs10) lpattern(shortdash)) ///
    (rcap ci_up_90 ci_down_90 quantile, lcolor(gs6)) ///
    (scatter beta_quant quantile, mcolor(black) msize(medium) mlwidth(medthick)) ///
    , ///
    xtitle("Extreme heat exposure quantile") ///
    ytitle("Marginal effect of innovation exposure") ///
    legend(off) ///
    yline(0, lcolor(black)) ///
    xlabel(0 10 25 50 75 90 100)

graph export "outputs/figures/Figure_RQ3_marginal_effect_innovation_by_heat_quantiles.png", replace

restore

















