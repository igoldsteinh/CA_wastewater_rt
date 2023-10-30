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
  read_csv(wastewater_url)%>% 
  mutate(date = lubridate::mdy(sample_collect_date))

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



# cdph crosswalk ----------------------------------------------------------
cdph_crosswalk <- read_csv(here::here("data", "sewershed_county_address.csv")) %>% 
                  rename(county = County_address) %>%
                  filter(county!="Imperial")


ww_dat <- ww_dat %>% 
          left_join(cdph_crosswalk, by = "wwtp_name") %>% 
          filter(!is.na(county))

start_date <- "2023-04-01"
fitting_dat <- ww_dat %>% dplyr::select(wwtp_name, 
                    sample_collect_date,pcr_target, 
                    pcr_gene_target, 
                    pcr_target_avg_conc, 
                    county, 
                    population_served) %>% 
               mutate(date = parse_date_time(sample_collect_date, c("%d/%m/%Y","%m/%d/%Y", "%Y-%m-%d")))

# problem_plants <- c("Manteca WW Quality Control Facility", 
#                     "Mountain House WWTP", 
#                     "Stockton Regional WW Control Facility", 
#                     "Tracy WWTP", 
#                     "White Slough Water Pollution Control Facility")


# 
# test <- fitting_dat %>% 
#         mutate(date = ifelse(wwtp_name %in% problem_plants, 
#                              lubridate::ymd(sample_collect_date),
#                              lubridate::mdy(sample_collect_date))) %>%
#         filter(is.na(date))
# 
# testing <- fitting_dat %>% 
#            mutate(date = parse_date_time(sample_collect_date, c("%d/%m/%Y","%m/%d/%Y", "%Y-%m-%d"))) %>% 
#            filter(is.na(date))
#check the dates
# date_check <- fitting_dat %>% 
#   dplyr::select(county, date, sample_collect_date)
# 
# alameda_check <- date_check %>% filter(county == "Alameda")
# orange_check <- date_check %>% filter(county == "Orange")
#filter date
fitting_dat <- fitting_dat %>% 
               filter(date >= start_date) %>% 
               filter(pcr_target == "sars-cov-2")

# lets just do it for n1 genes for now
n1_names <- c("N", "n1")
fitting_dat <- fitting_dat %>% 
               filter(pcr_gene_target %in% n1_names)
# group by date, weight an average based on population
fitting_dat <- fitting_dat %>% 
               group_by(county, date) %>% 
               mutate(total_pop = sum(population_served)) %>% 
               ungroup() %>% 
               mutate(pop_weight = population_served/total_pop,
                      weighted_conc = pcr_target_avg_conc * pop_weight) %>% 
               group_by(county, date) %>% 
               summarise(avg_weighted_conc = sum(weighted_conc),
                         log_conc = log(avg_weighted_conc))

id_list <- data.frame(county = unique(fitting_dat$county)) %>% 
           mutate(id = row_number())

fitting_dat <- fitting_dat %>% 
               left_join(id_list, by = "county")

# set up fitting dates and epiweeks 
fitting_dat <- fitting_dat %>% 
               group_by(county) %>% 
               mutate(yearday = yday(date),
                      new_time = yearday - min(yearday) + 1,
                      epiweek = epiweek(date),
                      new_week = ceiling(new_time/7)) %>% 
               filter(avg_weighted_conc > 0)


write_csv(fitting_dat, here::here("data", "wwtp_fitting_data.csv"))
# finding initial conditions ----------------------------------------------

cases_deaths_url <- resources %>% filter(name == "Statewide COVID-19 Cases Deaths Tests") %>% pull(url)
hosp_url <- resources %>% filter(name == "Statewide Covid-19 Hospital County Data") %>% pull(url)

cases <-
  read_csv(cases_deaths_url) %>%
  mutate(date = lubridate::ymd(date),
         deaths = as.integer(deaths),
         #reported_cases = as.integer(reported_cases),
         cases = as.integer(cases),
         positive_tests = as.integer(positive_tests),
         total_tests = as.integer(total_tests)) %>%
  select(date,
         cases = cases,
         tests = total_tests,
         deaths,
         county = area) %>%
  arrange(date, county)

start_date <- fitting_dat %>% 
              group_by(county) %>% 
              filter(date == min(date)) %>% 
              dplyr::select(county, date) %>% 
              rename(start_date = date) %>% 
              distinct()

init_cases <- cases %>% 
         left_join(start_date, by = "county") %>% 
         filter(!is.na(start_date)) %>% 
         group_by(county) %>% 
  mutate(case_date = start_date - days(11),
         recover_date = case_date - days(18),
         current_cases = date >= case_date & date < start_date,
         recovered_cases = date >= recover_date & date < case_date,
         status = ifelse(current_cases, "current_cases", ifelse(recovered_cases, "recovered_cases", "other"))) %>%
  mutate(year = year(date),
         epi_week = epiweek(date)) %>% 
  filter(status == "current_cases" | status == "recovered_cases") %>% 
  group_by(county, status) %>% 
  summarise(total_cases = sum(cases)) %>% 
  pivot_wider(id_cols = county, names_from = status, values_from = total_cases) %>% 
  mutate(E = current_cases * 5 * (4/11),
         I = current_cases * 5 * (7/11),
         R1 = recovered_cases * 5) %>% 
  left_join(id_list, by = "county")

write_csv(init_cases, here::here("data", "county_init_conds.csv"))
