# wasterwater functions
# library(stemr)
library(tidyverse)
library(lubridate)
library(patchwork)
library(viridis)
library(EpiEstim)
library(zoo)
library(sdprisk)
library(brms)
library(rstan)
library(truncnorm)
library(tidybayes)
set.seed(1234)
# source(here::here("src", "huisman_functions.R"))



# make fixed posterior samples --------------------------------------------

make_fixed_posterior_samples <- function(posterior_gq) {
  posterior_gq_samples <- posterior_gq %>%
  filter(str_detect(name, "\\[\\d+\\]", negate = T))
  
  return(posterior_gq_samples)
}


# make time varying posterior quantiles -----------------------------------
make_timevarying_posterior_quantiles <- function(posterior_gq) {
    timevarying_posterior_quantiles <-
    posterior_gq %>%
    filter(str_detect(name, "\\[\\d+\\]")) %>%
    mutate(time = name %>%
             str_extract("(?<=\\[)\\d+(?=\\])") %>%
             as.numeric(),
           name = name %>%
             str_extract("^.+(?=\\[)") %>%
             str_remove("data_")) %>%
    group_by(name, time) %>%
    median_qi(.width = c(0.5, 0.8, 0.95)) %>%
    left_join(.,tibble(time = 0:max(.$time)))
    
    return(timevarying_posterior_quantiles)
  
}



# make posterior predictive intervals -------------------------------------
# posterior_predictive = eirr_post_pred
# sim_data = simdata
# cases = FALSE
# ten_sim = ten_sim_val
# three_mean = three_mean_val
make_post_pred_intervals <- function(posterior_predictive, sim_data ){
    obs_time <- sim_data %>%
    mutate(obs_index = row_number()) %>%
    dplyr::select(obs_index, new_time)
  
  posterior_predictive_samples <- posterior_predictive %>%
    pivot_longer(-c(iteration, chain)) %>%
    mutate(obs_index = name %>%
             str_extract("(?<=\\[)\\d+(?=\\])") %>%
             as.numeric(),
           name = name %>%
             str_extract("^.+(?=\\[)") %>%
             str_remove("data_")) %>%
    bind_rows(., group_by(., chain, iteration, obs_index, name) %>%
                summarize(value = sum(value),
                          .groups = "drop"))  %>%
    left_join(obs_time, by = "obs_index")
  
  posterior_predictive_intervals <- posterior_predictive_samples %>%
    select(new_time, name, value) %>%
    group_by(new_time, name) %>%
    median_qi(.width = c(0.5, 0.8, 0.95)) %>%
    select(new_time, name, value, starts_with("."))
  return(posterior_predictive_intervals)
}


# make posterior predictive plot ------------------------------------------
make_post_pred_plot <- function(posterior_predictive_intervals, 
                                sim_data, 
                                cases = FALSE,
                                ten_sim = FALSE,
                                three_mean = FALSE) {

  if (cases == FALSE & ten_sim == FALSE & three_mean == FALSE) {
    true_data <- sim_data %>%
    dplyr::select(new_time, 
                  log_gene_copies1, 
                  log_gene_copies2, 
                  log_gene_copies3) %>%
    rename("log_copies1" = "log_gene_copies1",
           "log_copies2" = "log_gene_copies2",
           "log_copies3" = "log_gene_copies3") %>%
    pivot_longer(cols = - new_time) %>%
    rename("true_value" = "value") %>%
    filter(true_value > 0)
  
  posterior_predictive_intervals <- posterior_predictive_intervals %>%
    left_join(true_data, by = c("new_time"))
  
  posterior_predictive_plot <- posterior_predictive_intervals %>%
    ggplot() +
    geom_ribbon(aes(x = new_time, y = value, ymin = .lower, ymax = .upper, fill = fct_rev(ordered(.width)))) +
    geom_line(aes(x = new_time, y = value)) + 
    geom_point(mapping = aes(x = new_time, y = true_value), color = "coral1") +
    scale_fill_brewer(name = "Credible Interval Width") +
    # scale_fill_manual(values=c("skyblue1", "skyblue2", "skyblue3"), name="fill") +
    theme_bw() + 
    ggtitle("Posterior Predictive (ODE)")
  } else if (cases == FALSE & ten_sim == TRUE & three_mean == FALSE) {
    true_data <- sim_data %>%
      dplyr::select(new_time, 
                    log_gene_copies1, 
                    log_gene_copies2, 
                    log_gene_copies3,
                    log_gene_copies4,
                    log_gene_copies5,
                    log_gene_copies6,
                    log_gene_copies7,
                    log_gene_copies8,
                    log_gene_copies9,
                    log_gene_copies10,
      ) %>%
      rename("log_copies1" = "log_gene_copies1",
             "log_copies2" = "log_gene_copies2",
             "log_copies3" = "log_gene_copies3",
             "log_copies4" = "log_gene_copies4",
             "log_copies5" = "log_gene_copies5",
             "log_copies6" = "log_gene_copies6",
             "log_copies7" = "log_gene_copies7",
             "log_copies8" = "log_gene_copies8",
             "log_copies9" = "log_gene_copies9",
             "log_copies10" = "log_gene_copies10") %>%
      pivot_longer(cols = - new_time) %>%
      rename("true_value" = "value") %>%
      filter(true_value > 0)
    
    posterior_predictive_intervals <- posterior_predictive_intervals %>%
      left_join(true_data, by = c("new_time"))
    
    posterior_predictive_plot <- posterior_predictive_intervals %>%
      ggplot() +
      geom_ribbon(aes(x = new_time, y = value, ymin = .lower, ymax = .upper, fill = fct_rev(ordered(.width)))) +
      geom_line(aes(x = new_time, y = value)) + 
      geom_point(mapping = aes(x = new_time, y = true_value), color = "coral1") +
      scale_fill_brewer(name = "Credible Interval Width") +
      # scale_fill_manual(values=c("skyblue1", "skyblue2", "skyblue3"), name="fill") +
      theme_bw() + 
      ggtitle("Posterior Predictive (ODE)")
    
  } else if (cases == FALSE & ten_sim == FALSE & three_mean == TRUE) {
    # not sure what is going to happen here, wait until we have a posterior to work with before finishing
    true_data <- sim_data %>%
      dplyr::select(new_time, 
                    log_mean_copiesthree
      ) %>%
      rename("log_mean_copies" = "log_mean_copiesthree") %>%
      pivot_longer(cols = - new_time) %>%
      rename("true_value" = "value") %>%
      filter(true_value > 0)
    
    posterior_predictive_intervals <- posterior_predictive_intervals %>%
      left_join(true_data, by = c("new_time"))
    
    posterior_predictive_plot <- posterior_predictive_intervals %>%
      ggplot() +
      geom_ribbon(aes(x = new_time, y = value, ymin = .lower, ymax = .upper, fill = fct_rev(ordered(.width)))) +
      geom_line(aes(x = new_time, y = value)) + 
      geom_point(mapping = aes(x = new_time, y = true_value), color = "coral1") +
      scale_fill_brewer(name = "Credible Interval Width") +
      # scale_fill_manual(values=c("skyblue1", "skyblue2", "skyblue3"), name="fill") +
      theme_bw() + 
      ggtitle("Posterior Predictive (ODE)")
    
  }
  else {
    true_data <- sim_data %>%
      dplyr::select(new_week, 
                    total_cases) %>%
      rename("true_value" = "total_cases")
    
    posterior_predictive_intervals <- posterior_predictive_intervals %>%
      left_join(true_data, by = c("new_week"))
    
    posterior_predictive_plot <- posterior_predictive_intervals %>%
      ggplot() +
      geom_ribbon(aes(x = new_week, y = value, ymin = .lower, ymax = .upper, fill = fct_rev(ordered(.width)))) +
      geom_line(aes(x = new_week, y = value)) + 
      geom_point(mapping = aes(x = new_week, y = true_value), color = "coral1") +
      scale_fill_brewer(name = "Credible Interval Width") +
      # scale_fill_manual(values=c("skyblue1", "skyblue2", "skyblue3"), name="fill") +
      theme_bw() + 
      ggtitle("Posterior Predictive (ODE)")
    
  }
  
  return(posterior_predictive_plot)
  
}




