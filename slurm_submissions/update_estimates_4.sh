#!/bin/bash

#SBATCH -p standard   ## run on the standard partition
#SBATCH -A vminin_lab ## account to charge
#SBATCH -N 1          ## run on a single node
#SBATCH -n 1          ## request 4 tasks (4 CPUs)
#SBATCH -t 4:00:00   ## 4 hr run time limit
#SBATCH --mail-type=begin,end
#SBATCH --mail-user=igoldst1@uci.edu
#SBATCH --array=1-5

module purge
module load R
cd //pub/igoldst1/CA_wastewater_rt

if [ $SLURM_ARRAY_TASK_ID == 1 ]; then
sbatch --depend=afterany:$SLURM_JOB_ID slurm_submissions/update_estimates_5.sh
fi

Rscript scripts/process_results_eirrc_closed.R  $SLURM_ARRAY_TASK_ID
