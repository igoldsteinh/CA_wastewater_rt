#!/bin/bash

#SBATCH -p standard   ## run on the standard partition
#SBATCH -A vminin_lab ## account to charge
#SBATCH -N 1          ## run on a single node
#SBATCH -n 4          ## request 4 tasks (4 CPUs)
#SBATCH -t 10:00:00   ## 10 hr run time limit
#SBATCH --mem=4G    ## 4 GB memory limit
#SBATCH --mail-type=begin,end
#SBATCH --mail-user=igoldst1@uci.edu
#SBATCH --array=19

module purge
module load julia
cd //pub/igoldst1/CA_wastewater_rt


julia --project --threads 4 scripts/fit_eirrc_closed.jl $SLURM_ARRAY_TASK_ID

