library(tidyverse)
library(ckanr)
library(lubridate)

results_dir <- "results"

quiet <- function(x) {
  sink(tempfile())
  on.exit(sink())
  invisible(force(x))
}


ckanr_setup(url="https://data.ca.gov")
ckan <- quiet(ckanr::src_ckan("https://data.ca.gov"))

# get resources
resources <- rbind(resource_search("name:covid-19", as = "table")$results,
                   resource_search("name:hospitals by county", as = "table")$results)


wastewater_url <- resources %>% 
                  filter(name == "COVID-19 Wastewater Surveillance Data. California") %>% 
                  pull(url)
ww_dat <-
  read_csv(wastewater_url)

issues <- problems(ww_dat)

# we should filter out anything with quality control problems 
# this is anythign with a positive response for 
# qc_ignore, quality_flag, dashboard_ignore, analysis_ignore
# also for pcr_target_below_lod
# %>%
#   mutate(date = lubridate::ymd(date),
#          deaths = as.integer(deaths),
#          reported_cases = as.integer(reported_cases),
#          cases = as.integer(cases),
#          positive_tests = as.integer(positive_tests),
#          total_tests = as.integer(total_tests)) %>%
#   select(date,
#          cases = cases,
#          tests = total_tests,
#          deaths,
#          county = area) %>%
#   arrange(date, county)



# counties ----------------------------------------------------------------
fips_crosswalk <- read_csv(here::here("data", "state_and_county_fips_master.csv")) %>% dplyr::select(fips, name)

fips_crosswalk$real_fips <- as.character(fips_crosswalk$fips)

combo_fips <- c("06075, 06081", "06037, 06111", "06001, 06013")
combo_names <- c("San Francisco County and San Mateo County", 
                 "Los Angeles County and Ventura County", 
                 "Alameda County and Contra Costa County")

combo_frame <- data.frame(fips = NA, name = combo_names, real_fips = combo_fips)

fips_crosswalk <- bind_rows(fips_crosswalk, combo_frame) %>% 
                  rename(actual_name = name) %>% 
                  dplyr::select(real_fips, actual_name)

ww_dat <- ww_dat %>% 
          mutate(real_fips = ifelse(nchar(county_names) == 5, sub('.', '', county_names), county_names))

ww_dat <- ww_dat %>% 
          left_join(fips_crosswalk, by = "real_fips")
           
check <- ww_dat %>% dplyr::select(real_fips, county_names, actual_name)

county_pop <- read_csv(here::here("data", "county_pop.csv")) %>% 
              mutate(actual_name = paste0(County, " County")) %>%
              rename(total_pop = Population)

ww_dat <- ww_dat %>% 
          left_join(county_pop, by = "actual_name")

check <- ww_dat %>% dplyr::select(actual_name, total_pop) %>% distinct()

county_looksee = ww_dat %>% dplyr::select(actual_name, wwtp_name, population_served, total_pop) %>% 
                 distinct() %>%
                 mutate(percent_pop = population_served/total_pop) %>% 
                 group_by(actual_name) %>% 
                 mutate(total_percent_served = sum(percent_pop))

#LASAN_Hyp is the joint with ventura, do not count it for LA

#example of Yolo county
yolo = ww_dat %>% filter(actual_name == "Yolo County") %>% dplyr::select(wwtp_name, sample_collect_date, pcr_target_avg_conc) %>% 
  mutate(date = lubridate::mdy(sample_collect_date))


alameda = ww_dat %>% filter(actual_name == "Alameda County") %>% dplyr::select(wwtp_name, sample_collect_date, pcr_target_avg_conc) %>% 
  mutate(date = lubridate::mdy(sample_collect_date))
