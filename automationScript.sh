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

# Create unique function which is using array input which can be called.
# Usage: moveInBatch ${array[@]}
arrayInput() {
    # Iterate over the input array
    for func in "$@"
    do
        # Execute each function and store the output in a variable
        output=$(eval "$func \"$1\"")
        # Print the output of each function
        echo "$func output: $output"
    done
} 

# Log switch
log_switch = 1

# -------------------- FUNCTIONS --------------------

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

# Move files to backup directory
# Usage: moveInBatch ${array[@]}
function moveInBatch () {
	if [[ $# -ne 0 ]]; then
		moveInBatchArray=($@)
		createPath ${moveInBatchArray[@]}
		if [[ $(checkPath ${moveInBatchArray[0]}) -ne 0 ]]; then
			if [[ $( find ${moveInBatchArray[0]} -maxdepth 1 -type f -mtime ${moveInBatchArray[3]} -exec ls -lrt {} \; | wc -l ) -ne 0 ]]; then
				find ${moveInBatchArray[0]} -maxdepth 1 -type f -mtime ${moveInBatchArray[3]} -exec mv -t ${moveInBatchArray[1]}/${SDATE} {} +
			fi
		fi
	fi
}

# Compress files from backup to gz
# Usage: compressInBatch ${array[@]}
function compressInBatch () {
	if [[ $# -ne 0 ]]; then
		ITER=0
		compressInBatchArray=($@)
		if [[ $( find ${compressInBatchArray[1]} -maxdepth 2 -type f -mtime ${compressInBatchArray[3]} -exec ls -lrt {} \; | wc -l ) -ne 0 ]]; then
			while [ $( find ${compressInBatchArray[1]} -maxdepth 2 -type f -mtime ${compressInBatchArray[3]} -printf '%h/%f\n' | wc -l ) -ne 0 ]; do
				find ${compressInBatchArray[1]} -maxdepth 2 -type f -mtime ${compressInBatchArray[3]} -printf '%h/%f\n' | head -n ${LIMIT} | tar --remove-files -czvf ${compressInBatchArray[2]}/tar_${SDATE}_${ITER}.tar.gz -T -
				ITER=$((ITER+1))
			done
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
						moveInBatch ${clearArr[@]}
						if [[ $(checkPath ${clearArr[1]}) -ne 0 && $(checkPath ${clearArr[2]}) -ne 0 ]]; then
							compressInBatch ${clearArr[@]}
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
		args = ("$@")
		find "${args[@]}"
		# Alternatively:
		# cmdstr = "find"
		# for arg in "${args[@]}"
		# do
		# 	cmdstr += " $arg"
		# done
		# eval $cmdstr
	fi
}

# Create unique function which is using array input which can be called.
# Usage: moveInBatch ${array[@]}
function arrayInput () {
    # Iterate over the input array
	output = $1
	funcArray = ("$@")
    for func in "${funcArray[@]}"
    do
        # Execute each function and store the output in a variable
		cmdstr = "eval $func $output"
        out=$(eval "$func \"$1\"")
        # Print the output of each function
        echo "$func output: $output"
    done
} 

 
# Adds time stamp to every output line
# Usage: script | addTimeStamp
function addTimeStamp() {
	while IFS = read -r line;
	do
		printf '%s %s %s\n' "$(date)" "\[LOG\]" "$line"
	done
}


# Log all output
# Usage: LogOutput ${array[@]}
log() {
  # Check if logging is enabled - on-off switch
  if [ $LOGGING -eq 1 ]
  then
    # Log the message to the log file
    echo "$(date +"%Y-%m-%d %H:%M:%S"): $1" >> $LOG_PATH
  fi
}

# -------------------- CALL --------------------

# Load in the source configurations
# include ./automationSource.sh
# Execution of compiled script
checkError ${PART_CHECK[@]}