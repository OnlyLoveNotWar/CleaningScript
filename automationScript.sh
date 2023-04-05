#!/bin/bash
# Version 1.4

# For deploying

# - Create unique function which is using array input which can be called. ea.: Array('function1', 'function2') -> executed as "var=function1 $1; out=function2 $var;"
# - Run functions stored in arrays, eg.: Last element of array is an array to create function
# - Log all output and input of script (every action)
# - Logging should have an on-off switch
# - Variables should be in configuration file, instead of inline
# - Add function to execute "find" function with array inputted parameters, eg.: PART_ZTE_REMOVE_DATE=('/source/path' '-mtime +2')

# Load the config file from the current directory
source ./cleanScriptCFG.cfg

# -------------------- FUNCTIONS --------------------
# The runFunArgArray function will trans the array to cmd(string) and run it with eval
# Usage: runFunArgArray "${FUN_ARG_LIST[@]}"
function runFunArgArray () {
	local my_array=("$@")  
	local len=${#my_array[@]}
	local halfLen=$(( len / 2 ))
		echo "There are ${halfLen} functions to run:"
		for ((ind=0; ind<halfLen; ind++)); do
			fun_temp=${my_array[$ind]}
			arg_temp=${my_array[$(( ind + halfLen ))]}
			echo "Executing function $(( ind + 1 )): ${fun_temp} with arguments: ${arg_temp}"
			cmd="${fun_temp} \"${arg_temp}\""
			eval $cmd
		done
}

# Check if source file exists
# Usage: include $_PATH
include () {
    [[ -f "$1" ]] && source "$1"
}

# Create backup paths if they do not exists
# Usage: createPath ${array[@]}
function createPath () {
	if [[ $# -ne 0 ]]; then
		createPathArray=($@)
		if [[ ! -d ${createPathArray[1]}/${SDATE} || ! -d ${createPathArray[2]}/${SDATE} ]]; then
			mkdir -p ${createPathArray[1]}/${SDATE}
			mkdir -p ${createPathArray[2]}/${SDATE}
			echo " createPath (): created ${createPathArray[1]}/${SDATE} "
			echo " createPath (): created ${createPathArray[2]}/${SDATE} "
		fi
	fi
}

# Check is provided path exists
# Usage: checkPath ${variable}
function checkPath () {
	checkPathVar=$1
	if [[ ! -d ${checkPathVar} ]]; then
		echo 0
	else
		echo 1
	fi
}
#
# Move files to backup directory
# Usage: moveInBatch ${array[@]}
function moveInBatch () {
	if [[ $# -ne 0 ]]; then
		moveInBatchArray=($@)
		createPath ${moveInBatchArray[@]}
		if [[ $(checkPath ${moveInBatchArray[0]}) -ne 0 ]]; then
			if [[ $( find ${moveInBatchArray[0]} -maxdepth 1 -type f -exec ls -lrt {} \; | wc -l ) -ne 0 ]]; then
				find ${moveInBatchArray[0]} -maxdepth 1 -type f -exec mv -t ${moveInBatchArray[1]}/${SDATE} {} +
				echo "moveInBatch (): move files from ${moveInBatchArray[0]} to ${moveInBatchArray[1]}/${SDATE}"
			else
				echo "moveInBatch (): no file to move in ${moveInBatchArray[0]}"
			fi
		else
			echo "moveInBatch (): can not find ${moveInBatchArray[0]}"
		fi
	fi
}

# Compress files from backup to gz
# Usage: compressInBatch ${array[@]}
function compressInBatch () {
	if [[ $# -ne 0 ]]; then
		ITER=0
		compressInBatchArray=($@)
		if [[ $( find ${compressInBatchArray[1]} -maxdepth 2 -type f -mmin ${compressInBatchArray[3]} -exec ls -lrt {} \; | wc -l ) -ne 0 ]]; then
			while [ $( find ${compressInBatchArray[1]} -maxdepth 2 -type f -mmin ${compressInBatchArray[3]} -printf '%h/%f\n' | wc -l ) -ne 0 ]; do
				find ${compressInBatchArray[1]} -maxdepth 2 -type f -mmin ${compressInBatchArray[3]} -printf '%h/%f\n' | head -n ${LIMIT} | tar --remove-files -czvf ${compressInBatchArray[2]}/${SDATE}/tar_${SDATE}_${ITER}.tar.gz -T -
				ITER=$((ITER+1))
				
			done
			echo "compressInBatch (): compress files which are older than ${compressInBatchArray[3]} mins from ${compressInBatchArray[1]} to ${compressInBatchArray[2]}/${SDATE}"
		else
			echo "compressInBatch (): no file is older than ${compressInBatchArray[3]} mins from ${compressInBatchArray[1]}"
		fi
	fi
}
# Remove files that are older than certain time
# Usage: removeInBatch ${array[@]}
function removeInBatch () {
	if [[ $# -ne 0 ]]; then
		removeBatchArray=($@)
		if [[ $( find ${removeBatchArray[0]} -maxdepth 2 -type f -mmin ${removeBatchArray[1]} -exec ls -lrt {} \; | wc -l ) -ne 0 ]]; then
			while [ $( find ${removeBatchArray[0]} -maxdepth 2 -type f -mmin ${removeBatchArray[1]} -printf '%h/%f\n' | wc -l ) -ne 0 ]; do
				find ${removeBatchArray[0]} -maxdepth 2 -type f -mmin ${removeBatchArray[1]} -printf '%h/%f\n' | head -n ${LIMIT} | xargs rm
			done
			echo "removeInBatch (): remove files which are older than ${removeBatchArray[1]} mins from ${removeBatchArray[0]}"
		else
			echo "removeInBatch (): no file is older than ${removeBatchArray[1]} mins from ${removeBatchArray[0]}"
		fi
	fi
}

# Check for partitions with error level
# Usage: checkError ${array[@]}
function checkError () {
	if [[ $# -ne 0 ]]; then
		checkErrorArray=($@)
		for (( i=0; i < ${#checkErrorArray[@]}; )); do
			if [[ $(checkPath ${checkErrorArray[i]}) -ne 0 ]]; then
				if [ $( df ${checkErrorArray[i]} |tail -n -1 | awk '{print $5}'|sed 's/.$//' ) -gt ${checkErrorArray[${i+1}]} ]; then
					eval tmparr=\( \${${checkErrorArray[${i+2}]}[@]} \)
					for j in ${tmparr[@]}; do
						eval clearArr=\( \${${j}[@]} \)
						if [[ ${#clearArr[@]} -ne 2 ]]; then
							moveInBatch ${clearArr[@]}
							if [[ $(checkPath ${clearArr[1]}) -ne 0 && $(checkPath ${clearArr[2]}) -ne 0 ]]; then
								compressInBatch ${clearArr[@]}
							fi
						else
							removeInBatch ${clearArr[@]}
						fi

					done
				fi
			fi
			(( i=i+3 ))
			if [[ $i -eq ${#checkErrorArray[@]} ]]; then
				break
			fi
		done
	fi
}

# Executes the find command with an array of arguments
# Usage: finArrayArgs ${array[@]}
function findArrayArgs () {
	if [[ $# -ne 0 ]]; then
		local array=("$@")
		local len=${#array[@]}
		for (( indA=0; indA < $len; indA+=2 )); do
			local path="${array[$indA]}"
			local opt="${array[$(( indA + 1 ))]}"
			cmd="find ${path} ${opt}"
			eval $cmd
		done
	fi
}

# Create unique function which is using array input which can be called.
# Usage: arrayInput ${array[@]}
function arrayInput () {
    # Iterate over the input array
	output=$1
	funcArray=("$@")
    for func in "${funcArray[@]}"
    do
        # Execute each function and store the output in a variable
		cmdstr="eval $func $output"
        out=$(eval "$func \"$1\"")
        # Print the output of each function
        echo "$func output: $output"
    done
} 

 
#  Adds time stamp to every output line
# Usage: script | addTimeStamp
function addTimeStamp() {
	while read -r line;
	do
		printf '%s %s %s\n' "$(date +"%Y-%m-%d %T")" "[LOG]:" "$line"
	done
}

# -------------------- CALL --------------------
if (( $LOG_SWITCH == 1 )); then
    exec &> >(addTimeStamp | tee -a ${LOG_PATH})
fi
{
# Load in the source configurations
# include ./automationSource.sh
# Execution of compiled script

# show the current time when we run the script

runFunArgArray "${FUN_ARG_LIST[@]}"

}