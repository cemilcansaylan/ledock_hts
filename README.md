### Requirements:

ledock and lepro [link](http://www.lephar.com/download.htm)

gnu parallel [link](https://www.gnu.org/software/parallel/)

```bash

Usage: ledock_hts.sh [-h, --help] [--config arg] [--workdir folder] [--task_number int] [--receptor arg] [--ligands_folder folder] 
             [--center_coord center_x center_y center_z (float)] [--box_size size_x size_y size_z (float)] 
             [--account arg] [-p, --partition arg] [--cpu int] [--ledock_path folder] [--gnu_parallel folder]
              
Descrition of command:
  -h,   --help          show this help message and exit

Inputs (require)

  --workdir folder      WORKDIR in which ligands and inputs should be present
  --task_number int     # of task, must be integer
  --receptor arg        Must be given full path of receptor file (pdb)
  --ligands_folder folder The folder containing all ligands (mol2)
  --center_coord center_x center_y center_z
                        Grid box center, center should be given as shown; center_x center_y center_z 
  --box_size size_x size_y size_z
                        Grid box size, size should be giver as; size_x size_y size_z

UHEM HPC inputs (require)
  --account arg         UHEM slurm file account name
  --partition arg       UHEM partition (default is "core40q")
  --cpu int             # of cpu (default is "40") for one task

Program PATH (require)
  --ledock_path folder  Ledock executable path
  --gnu_parallel folder GNU Parallel executable path

Configuration file (optional):
  --config arg          the above options can be put here 
```
