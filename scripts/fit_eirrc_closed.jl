using Logging
using testpackage
using DrWatson
using JLD2
using CSV
using DataFrames
using Random

county_id =
if length(ARGS) == 0
   25
else
  parse(Int64, ARGS[1])
end

seed = 1
Logging.disable_logging(Logging.Warn)

## Control Parameters
n_samples = 250
n_chains = 4
priors_only = false


## Load Data
dat = CSV.read("data/wwtp_fitting_data.csv", DataFrame)
dat = filter(:id => id -> id == county_id, dat)


## load initial conditions 
init_conds = CSV.read("data/county_init_conds.csv", DataFrame)
init_conds = filter(:id => id -> id == county_id, init_conds)
## Define Priors
const gamma_sd = 0.01
const gamma_mean =log(1/4)
const nu_sd = 0.2
const nu_mean = log(1/7)
const eta_sd = 0.2
const eta_mean = log(1/10)
const tau_sd = 1.0
const tau_mean = log(1)
const I_init_sd = 0.05
const I_init_mean = init_conds[1,:I]
const R1_init_sd = 0.05
const R1_init_mean = convert(Float64, init_conds[1,:R1])
const E_init_sd = 0.05
const E_init_mean = init_conds[1,:E]
const df_shape = 2.0
const df_scale = 10.0
const sigma_rt_sd = 0.2
const sigma_rt_mean = log(0.1)
const rt_init_sd = 0.15
const rt_init_mean = log(1)
const lambda_mean = 5.685528
const lambda_sd = 2.178852
const rho_gene_mean = 0.0
const rho_gene_sd = 1.0
data_log_copies = dat[:, :log_conc]



obstimes = dat[:, :new_time]
obstimes = convert(Vector{Float64}, obstimes)

  # trying to avoid the stupid situation where we're telling to change at the end of the solver which doesn't make sense
  if maximum(obstimes) % 7 == 0
    param_change_max = maximum(obstimes) - 7
  else
    param_change_max = maximum(obstimes)
  end
  param_change_times = collect(7:7.0:param_change_max)

# Sample Posterior

Random.seed!(seed)
posterior_samples = fit_eirrc_closed(data_log_copies,
                                    obstimes,
                                    priors_only,
                                    n_samples,
                                    n_chains,
                                    seed,
                                    gamma_sd,
                                    gamma_mean,
                                    nu_sd,
                                    nu_mean,
                                    eta_sd,
                                    eta_mean,
                                    rho_gene_sd,
                                    rho_gene_mean,
                                    tau_sd,
                                    tau_mean,
                                    I_init_sd,
                                    I_init_mean,
                                    R1_init_sd,
                                    R1_init_mean,
                                    E_init_sd,
                                    E_init_mean,
                                    lambda_mean,
                                    lambda_sd,
                                    df_shape,
                                    df_scale,
                                    sigma_rt_sd,
                                    sigma_rt_mean,
                                    rt_init_sd,
                                    rt_init_mean)
wsave(projectdir("results", "posterior_samples", string("posterior_samples_county", county_id, "_seed", seed, ".jld2")), @dict posterior_samples)

# Sample Prior 

# Random.seed!(seed)
# prior_samples = fit_eirrc_closed(data_log_copies,
#                                     obstimes,
#                                     true,
#                                     n_samples,
#                                     n_chains,
#                                     seed,
#                                     gamma_sd,
#                                     gamma_mean,
#                                     nu_sd,
#                                     nu_mean,
#                                     eta_sd,
#                                     eta_mean,
#                                     rho_gene_sd,
#                                     rho_gene_mean,
#                                     tau_sd,
#                                     tau_mean,
#                                     I_init_sd,
#                                     I_init_mean,
#                                     R1_init_sd,
#                                     R1_init_mean,
#                                     E_init_sd,
#                                     E_init_mean,
#                                     lambda_mean,
#                                     lambda_sd,
#                                     df_shape,
#                                     df_scale,
#                                     sigma_rt_sd,
#                                     sigma_rt_mean,
#                                     rt_init_sd,
#                                     rt_init_mean)
# wsave(projectdir("results", string("prior_samples_county", county_id, "_seed", seed, ".jld2")), @dict prior_samples)

# we are type stable
#   @code_warntype my_model.f(
#     my_model,
#     Turing.VarInfo(my_model),
#     Turing.SamplingContext(
#         Random.GLOBAL_RNG, Turing.SampleFromPrior(), Turing.DefaultContext(),
#     ),
#     my_model.args...,
# )



