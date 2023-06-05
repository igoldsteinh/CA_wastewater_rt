#calculate case data
library(tidyverse)
library(ckanr)
library(lubridate)
library(splines)
library(fs)

results_dir <- "results"



# variants_dat <- read_tsv("https://raw.githubusercontent.com/blab/rt-from-frequency-dynamics/master/data/omicron-us/omicron-us_location-variant-sequence-counts.tsv") %>%
#   filter(location == "California") %>%
#   select(-location) %>%
#   distinct() %>%
#   pivot_wider(names_from = variant, values_from = sequences, values_fill = 0) %>%
#   pivot_longer(-date, names_to = "variant", values_to = "sequences") %>%
#   mutate(sequences = sequences + 1) %>%
#   group_by(date) %>%
#   summarize(variant = variant,
#             prop = sequences / sum(sequences)) %>%
#   filter(variant == "Omicron") %>%
#   select(date, prop_omicron = prop)

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

start_date = as.Date("2022-11-01")
alameda_cases <-cases %>% 
  filter(county == "Alameda") %>%
  mutate(case_date = start_date - days(11),
         recover_date = case_date - days(18),
         current_cases = date >= case_date & date < start_date,
         recovered_cases = date >= recover_date & date < case_date
  ) %>%
  mutate(year = year(date),
         epi_week = epiweek(date)) 

infected <- alameda_cases %>% 
  filter(current_cases == TRUE) %>%
  ungroup() %>%
  summarise(total_cases = sum(cases)) %>%
  pull(total_cases)
recovered <- alameda_cases %>% 
  filter(recovered_cases == TRUE) %>%
  ungroup() %>%
  summarise(total_cases = sum(cases)) %>%
  pull(total_cases)

plantsize = 740000
popsize = 1.649E6
E = sum(infected) * 5 * (4/11) * (plantsize/popsize)
I = sum(infected) * 5 * (7/11) * (plantsize/popsize)
R1 = sum(recovered) * 5 * (plantsize/popsize)
