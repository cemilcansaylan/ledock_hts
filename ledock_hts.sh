#!/bin/bash

function usage(){
   cat << EOF

  Usage: $name [-h, --help] [--config arg] [--workdir folder] [--task_number int] [--receptor arg] [--ligands_folder folder] 
               [--center_coord center_x center_y center_z (float)] [--box_size size_x size_y size_z (float)] 
               [--account arg] [-p, --partition arg] [--cpu int] [--ledock_path folder] [--gnu_parallel folder]
                

  Descrition of command:
    -h,   --help          show this help message and exit

  Inputs (require)

    --workdir folder      WORKDIR in which ligand folder and inputs should be present
    --task_number int     # of task, must be integer
    --receptor arg        Must be given full path of receptor file (pdb)
    --ligands_folder      folder The folder containing all ligands (mol2)
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


EOF
}

name=$(basename $0)
export -f usage

no_args=true

function ledock_config(){
  while read line; do
    option=`echo $line | cut -d" " -f1`
    var=`echo $line | cut -d" " -f2`
    var2=`echo $line | cut -d" " -f3`
    var3=`echo $line | cut -d" " -f4`
    [[ -z "$option" ]] && continue;
    case $option in
      "--workdir") WORKDIR=$var ;;
      "--task_number") TASKNUM=$var ;;
      "--receptor") receptor="$var" ;;
      "--ligands_folder") ligands_folder=$var ;;
      "--center_coord") center_x=$var; center_y=$var2; center_z=$var3 ;;
      "--box_size") size_x=$var; size_y=$var2; size_z=$var3 ;;
      "--account") account=$var ;;
      "--partition") partition=$var ;;
      "--cpu") cpu=$var ;;
      "--mail_address") mail_name=$var ;;
      "--ledock_path") LEDOCK_PATH=$var ;;
      "--gnu_parallel_path") PARALLEL_PATH=$var ;;
      *) echo "Unknown parameter passed: $option"; exit 1 ;;
    esac
  done < $1
}

export -f ledock_config

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage ; exit 1;;
        --workdir) WORKDIR=$2; shift;;
        --task_number) TASKNUM=$2; shift;;
        --receptor) receptor="$2"; shift ;;
        --ligands_folder) ligands_folder=$2; shift;;
        --center_coord) center_x=$2; center_y=$3; center_z=$4; shift 3 ;;
        --box_size) size_x=$2; size_y=$3; size_z=$4; shift 3 ;;
        --account) account=$2; shift ;;
        --partition) partition=$2;  shift ;;
        --cpu) cpu=$2; shift;;
        --mail_address) mail_name=$2; shift;;
        --ledock_path) LEDOCK_PATH=$2; shift;;
        --gnu_parallel_path) PARALLEL_PATH=$2; shift ;;
        --config) ledock_config $2; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
    no_args="false"
done

[[ "$no_args" == "true" ]] && { usage; exit 1; }

[[ -z "$WORKDIR" ]] && { echo "Error: WORKDIR cannot be empty" ; exit 1; }
[[ -z "$TASKNUM" ]] && { echo "Error: task_number cannot be empty" ; exit 1; }
[[ -z "$receptor" ]] && { echo "Error: receptor cannot be empty" ; exit 1; }
[[ -z "$ligands_folder" ]] && { echo "Error: ligands_folder cannot be empty" ; exit 1; }
[[ -z "$account" ]] && { echo "Error: account cannot be empty" ; exit 1; }
[[ -z "$partition" ]] && { echo "Error: partition cannot be empty" ; exit 1; }
[[ -z "$cpu" ]] && { echo "Error: cpu cannot be empty" ; exit 1; }
[[ -z "$LEDOCK_PATH" ]] && { echo "Error: LEDOCK_PATH cannot be empty"; exit 1; }
[[ -z "$PARALLEL_PATH" ]] && { echo "Error: PARALLEL_PATH cannot be empty"; exit 1; }

xmin=`echo "scale=3; $center_x - ($size_x/2)" | bc`
xmax=`echo "scale=3; $center_x + ($size_x/2)" | bc`
ymin=`echo "scale=3; $center_y - ($size_y/2)" | bc`
ymax=`echo "scale=3; $center_y + ($size_y/2)" | bc`
zmin=`echo "scale=3; $center_z - ($size_z/2)" | bc`
zmax=`echo "scale=3; $center_z + ($size_z/2)" | bc`

function ledock_config(){
    cat <<EOF > $WORKDIR/docking_output/task_$1/ledock_config/dock_$2.in
Receptor
$WORKDIR/inputs/pro.pdb
 
RMSD
1.0
 
Binding pocket
${xmin} ${xmax}
${ymin} ${ymax}
${zmin} ${zmax}
 
Number of binding poses
10
 
Ligands list
$WORKDIR/docking_output/task_$1/ligand_inputs/liglist_$2

EOF
}

function sbatch_conf(){
    cat <<EOF > $WORKDIR/docking_output/task_$1/sbatch_job_$1.in
#!/bin/bash
#SBATCH -J task_$1
#SBATCH -p $partition
#SBATCH -A $account
#SBATCH -N 1
#SBATCH -n $cpu
#SBATCH --time=7-00:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=$mail_name
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

echo "SLURM_NODELIST $SLURM_NODELIST"
echo "NUMBER OF CORES $SLURM_NTASKS"

cd $WORKDIR

$PARALLEL_PATH/src/parallel -j $cpu $LEDOCK_PATH/ledock_linux_x86 $WORKDIR/docking_output/task_$1/ledock_config/dock_{}.in ::: {01..$cpu} 

EOF
}

export -f ledock_config
export -f sbatch_conf

cd $WORKDIR

echo "Making folders"
for i in $(seq -w 01 $TASKNUM);do 
  mkdir -p $WORKDIR/docking_output/task_$i/ligand_inputs
  mkdir -p $WORKDIR/docking_output/task_$i/ledock_config
done

mkdir -p $WORKDIR/inputs
cd $WORKDIR/inputs
echo "LePro processing"
$LEDOCK_PATH/lepro_linux_x86 $receptor

echo "Spliting ligands"
ls -d "$ligands_folder/"* > ligand_list.txt
split --numeric=1 -n l/$TASKNUM ligand_list.txt liglist_task_

echo "Generation Ledock configurations"
for i in $(seq -w 01 $TASKNUM);do 
  cd $WORKDIR/docking_output/task_$i/ligand_inputs
  split --numeric=1 -n l/$cpu $WORKDIR/inputs/liglist_task_$i liglist_
  sbatch_conf $i
  for j in $(seq -w 01 $cpu);do
    ledock_config $i $j
  done
done

echo "Writing submit file"
function print_submit(){
    cat <<EOF > $WORKDIR/sbatch_submit.job
for i in \$(seq -w 01 0$TASKNUM);do
  sbatch $WORKDIR/docking_output/task_\$i/sbatch_job_\$i.in
done
EOF
}

export -f print_submit

print_submit

chmod +x $WORKDIR/sbatch_submit.job
echo "DONE"
