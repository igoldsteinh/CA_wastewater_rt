### Summarise processed results eirr_closed
library(tidyverse)
library(tidybayes)
library(posterior)
library(fs)
library(gridExtra)
library(ggplot2)
library(scales)
library(cowplot)
source("src/wastewater_functions_texera.R")

args <- commandArgs(trailingOnly=TRUE)

timevarying_suffix <- "posterior_timevarying_quantiles_county"
timevarying_list <- list.files(path = path("results", "generated_quantities"),  pattern = timevarying_suffix)

mcmc_suffix <- "mcmc_summary_county"
mcmc_list <- list.files(path = path("results", "mcmc_summaries"),  pattern = mcmc_suffix)


fitted_data <- read_csv(here::here("data", "wwtp_fitting_data.csv"))
# read in data and results ---------------------------------------------------------
full_stan_diag <- map(mcmc_list, ~read_csv(here::here("results", "mcmc_summaries", .x))) %>%
  bind_rows(.id = "id") %>%
  group_by(id) %>% 
  filter(variable != "R2[1]" & variable != "C[1]") %>%
  summarise(min_rhat = min(rhat),
            max_rhat = max(rhat),
            min_ess_bulk = min(ess_bulk),
            max_ess_bulk = max(ess_bulk),
            min_ess_tail = min(ess_tail),
            max_ess_tail = max(ess_tail))

write_csv(full_stan_diag, here::here("results", "all_counties_stan_diag.csv"))
# create final rt frame ---------------------------------------------------

timevarying_quantiles <- map(timevarying_list, ~read_csv(here::here("results", "generated_quantities", .x))) 

rt_quantiles <- timevarying_quantiles %>%
  map(~.x %>% filter(name == "rt_t_values") %>%
        rename(week = time)) %>%
  bind_rows(.id = "id")

fitted_data$id <- as.character(fitted_data$id)
rt_quantiles <- rt_quantiles %>% 
         right_join(fitted_data, by = c("week" = "new_week", "id")) %>%
        dplyr::select(county, id, week, date, value, .lower, .upper, .width,.point, .interval) 


write_csv(rt_quantiles, here::here("results", "full_country_rt_quantiles.csv"))

cdph_quantiles <- rt_quantiles %>% filter(.width == 0.95)
missing <- rt_quantiles %>% filter(is.na(.width))
# visualize results
# all credit to Damon Bayer for plot functions 
my_theme <- list(
  scale_fill_brewer(name = "Credible Interval Width",
                    labels = ~percent(as.numeric(.))),
  guides(fill = guide_legend(reverse = TRUE)),
  theme_minimal_grid(),
  theme(legend.position = "bottom"))

make_rt_plot <- function(county_name) {
  rt_quantiles %>%
    filter(county == county_name) %>%
    ggplot(aes(date, value, ymin = .lower, ymax = .upper)) +
    geom_lineribbon() +
    scale_y_continuous("Rt", label = comma) +
    scale_x_date(name = "Date") +
    ggtitle(str_c("EIRR Posterior Rt County ", county_name)) +
    my_theme
}

ggsave2(filename = here::here("figures", paste0("county_rt_plots_county.pdf")),
        plot = rt_quantiles %>%
          distinct(county) %>%
          arrange(county) %>%
          pull(county) %>%
          map(make_rt_plot) %>%
          marrangeGrob(ncol = 1, nrow = 1),
        width = 12,
        height = 8)


