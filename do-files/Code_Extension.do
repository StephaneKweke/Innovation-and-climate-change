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
