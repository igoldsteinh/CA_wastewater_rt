### Process Results eirrc
library(tidyverse)
library(tidybayes)
library(posterior)
library(fs)
source("src/wastewater_functions_texera.R")

args <- commandArgs(trailingOnly=TRUE)


if (length(args) == 0) {
  snum = 1
  seed_val = 1
} else {
  snum <- as.integer(args[1])
  seed_val <- 1
  
}



priors_only = snum == 0




# priors only -------------------------------------------------------------
if(priors_only == TRUE) {
  
  priorname <- paste0("prior_generated_quantities_county", snum, "_seed", seed_val, ".csv")
  prior_gq_samples_all <- read_csv(here::here("results",
                                            
                                              priorname)) %>%
    pivot_longer(-c(iteration, chain)) %>%
    select( name, value)
  
  
  priors <- make_fixed_posterior_samples(prior_gq_samples_all)
  
  
  prior_timevarying_quantiles <- make_timevarying_posterior_quantiles(prior_gq_samples_all)
  
  prior_samp_name <- paste0("prior_samples_county", snum , "_seed", seed_val, ".csv")
  prior_timevarying_name <- paste0("prior_timevaryingquantiles_county", snum, "_seed", seed_val, ".csv")
  write_csv(priors, here::here("results",  prior_samp_name))
  write_csv(prior_timevarying_quantiles, here::here("results",  prior_timevarying_name))
  
  quit()
}


# posterior ---------------------------------------------------------------


# calculate MCMC diagnostics after burnin
gq_address <- paste0("results/generated_quantities/generated_quantities_county", 
                     snum, 
                     "_seed", 
                     seed_val,
                     ".csv")

posterior_samples <- read_csv(gq_address) %>%
  rename(.iteration = iteration,
         .chain = chain) %>%
  as_draws()

max_iteration = max(posterior_samples$.iteration)
min_iteration = round(max_iteration/2)


subset_samples <- subset_draws(posterior_samples)

mcmc_summary <- summarise_draws(subset_samples)

mcmc_summary_address <- paste0("results/mcmc_summaries/mcmc_summary_county", 
                               snum, 
                               "_seed",
                               seed_val,
                               ".csv")
write_csv(mcmc_summary, mcmc_summary_address)


# create long format fixed samples and time-varying quantiles -----------------
posterior_gq_samples_all <- subset_samples  %>%
  pivot_longer(-c(.iteration, .chain)) %>%
  select( name, value)


posterior_fixed_samples <- make_fixed_posterior_samples(posterior_gq_samples_all)

fixed_samples_address <- paste0("results/generated_quantities/posterior_fixed_samples_county",
                                snum, 
                                "_seed",
                                seed_val,
                                ".csv")

write_csv(posterior_fixed_samples, fixed_samples_address)

rm(posterior_fixed_samples)

posterior_timevarying_quantiles <- make_timevarying_posterior_quantiles(posterior_gq_samples_all)


timevarying_quantiles_address <- paste0("results/generated_quantities/posterior_timevarying_quantiles_county",
                                        snum,
                                        "_seed",
                                        seed_val,
                                        ".csv")

write_csv(posterior_timevarying_quantiles, timevarying_quantiles_address)

rm(posterior_timevarying_quantiles)

rm(posterior_gq_samples_all)


# create posterior predictive quantiles -----------------------------------
# preserve if needed, but comment out for now due to possiblity of whacky numerical errors (not our fault)
post_pred_address <- paste0("results/posterior_predictive/posterior_predictive_county",
                            snum,
                            "_seed",
                            seed_val,
                            ".csv")
eirr_post_pred <- read_csv(post_pred_address)

data <- read_csv(here::here("data", "wwtp_fitting_data.csv")) %>% 
        filter(id == snum)
eirr_post_pred_intervals <- make_post_pred_intervals(eirr_post_pred, data)

post_pred_interval_address <- paste0("results/posterior_predictive/posterior_predictive_intervals_county",
                                     snum,
                                     "_seed",
                                     seed_val,
                                     ".csv")

write_csv(eirr_post_pred_intervals, post_pred_interval_address)

