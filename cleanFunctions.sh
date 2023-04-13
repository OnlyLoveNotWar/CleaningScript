
# Load the config file
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

# The formatBytes function will trans the n Bytes to the ( xx GB xx MB xx KB xx B ) format
# Usage: formatBytes() $bytes
function formatBytes() {
    local bytes=$1
    local kb=1024
    local mb=$((1024 * kb))
    local gb=$((1024 * mb))

    local gbs=$((bytes / gb))
    bytes=$((bytes % gb))
    
    local mbs=$((bytes / mb))
    bytes=$((bytes % mb))
    
    local kbs=$((bytes / kb))
    bytes=$((bytes % kb))

    echo "${gbs} GB ${mbs} MB ${kbs} KB ${bytes} B"
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

# Move files to backup directory
# Usage: moveInBatch ${array[@]}
function moveInBatch () {
    if [[ $# -ne 0 ]]; then
        moveInBatchArray=($@)
        createPath ${moveInBatchArray[@]}

        if [[ $(checkPath ${moveInBatchArray[0]}) -ne 0 ]]; then
            local total_files_size=$(find ${moveInBatchArray[0]} -maxdepth 1 -type f -exec du -c -b {} + | tail -n 1 | awk '{print $1}')
            local backup_folder_free_space=$(df -B1 --output=avail "${moveInBatchArray[1]}" | tail -n 1)
            echo "moveInBatch (): files size ( $(formatBytes $total_files_size) ) path ${moveInBatchArray[0]} mounted on \" $( df ${moveInBatchArray[0]} |tail -n -1 | awk '{print $6}') \""
            echo "moveInBatch (): free space ( $(formatBytes $backup_folder_free_space) ) path ${moveInBatchArray[1]} mounted on \" $( df ${moveInBatchArray[1]} |tail -n -1 | awk '{print $6}') \""

            if (( total_files_size <= backup_folder_free_space )); then
                if [[ $( find ${moveInBatchArray[0]} -maxdepth 1 -type f -exec ls -lrt {} \; | wc -l ) -ne 0 ]]; then
                    find ${moveInBatchArray[0]} -maxdepth 1 -type f -exec mv -t ${moveInBatchArray[1]}/${SDATE} {} +
					find "${moveInBatchArray[1]}/${SDATE}" -type f -exec touch {} +
                    echo "moveInBatch (): move files from ${moveInBatchArray[0]}  to ${moveInBatchArray[1]}/${SDATE}"
                    echo "moveInBatch (): from: mounted on \" $( df ${moveInBatchArray[0]} |tail -n -1 | awk '{print $6}') \" (- $(formatBytes $total_files_size) ), to: mounted on \" $( df ${moveInBatchArray[1]}/${SDATE} |tail -n -1 | awk '{print $6}') \" (+ $(formatBytes $total_files_size) )"
                else
                    echo "moveInBatch (): no file to move in ${moveInBatchArray[0]}"
                fi
            else
                echo "moveInBatch (): not enough space in the backup folder (${moveInBatchArray[1]}/${SDATE})"
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
		    local total_files_size=$(find ${compressInBatchArray[1]} -maxdepth 2 -type f -mmin ${compressInBatchArray[3]} -exec du -c -b {} + | tail -n 1 | awk '{print $1}')
            local GZ_folder_free_space=$(df -B1 --output=avail "${moveInBatchArray[2]}" | tail -n 1)
			local predicted_compressed_size=$(echo "$total_files_size * $COMPRESS_RATE" | bc)
			local predicted_compressed_size_int=$(echo $predicted_compressed_size | awk '{printf "%d\n", int($1+0.999)}')
			echo "compressInBatch (): files size ( $(formatBytes $total_files_size) ) path ${compressInBatchArray[1]} mounted on \" $( df ${moveInBatchArray[1]} |tail -n -1 | awk '{print $6}') \""
			echo "compressInBatch (): predicted compressed files size ( $(formatBytes $predicted_compressed_size_int) )"
			echo "compressInBatch (): free space ( $(formatBytes $GZ_folder_free_space) ) path ${moveInBatchArray[2]} mounted on \" $( df ${moveInBatchArray[2]} |tail -n -1 | awk '{print $6}') \""
			if (( predicted_compressed_size_int <= GZ_folder_free_space )); then
				local total_tar_gz_size=0
				while [ $( find ${compressInBatchArray[1]} -maxdepth 2 -type f -mmin ${compressInBatchArray[3]} -printf '%h/%f\n' | wc -l ) -ne 0 ]; do
					find ${compressInBatchArray[1]} -maxdepth 2 -type f -mmin ${compressInBatchArray[3]} -printf '%h/%f\n' | head -n ${LIMIT} | tar --remove-files -czvf ${compressInBatchArray[2]}/${SDATE}/tar_${SDATE}_${ITER}.tar.gz -T -
					ITER=$((ITER+1))
				done
				total_tar_gz_size=$(find ${compressInBatchArray[2]}/${SDATE} -type f -name '*.tar.gz' -exec du -cb {} + | tail -n 1 | awk '{print $1}')
				echo "compressInBatch (): compress files which are older than ${compressInBatchArray[3]} mins from ${compressInBatchArray[1]} to ${compressInBatchArray[2]}/${SDATE}"
				echo "compressInBatch (): from: mounted on \" $( df ${compressInBatchArray[1]} |tail -n -1 | awk '{print $6}') \" (- $(formatBytes $total_files_size) ), to: mounted on \" $( df ${compressInBatchArray[2]}/${SDATE} |tail -n -1 | awk '{print $6}') \" (+ $(formatBytes $total_tar_gz_size) )"
			else
				echo "compressInBatch (): not enough space in the GZ folder ${compressInBatchArray[2]}"
			fi
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
        local total_space_freed=0
        if [[ $( find ${removeBatchArray[0]} -maxdepth 2 -type f -mmin ${removeBatchArray[1]} -exec ls -lrt {} \; | wc -l ) -ne 0 ]]; then
            while [ $( find ${removeBatchArray[0]} -maxdepth 2 -type f -mmin ${removeBatchArray[1]} -printf '%h/%f\n' | wc -l ) -ne 0 ]; do
                # Save the list of files to be removed in a variable
                files_to_remove=$(find ${removeBatchArray[0]} -maxdepth 2 -type f -mmin ${removeBatchArray[1]} -printf '%h/%f\n' | head -n ${LIMIT})
                
                # Calculate the total size of the files to be removed
                space_freed=$(du -c -b $files_to_remove | tail -1 | awk '{print $1}')
                total_space_freed=$((total_space_freed + space_freed))
                
                # Remove the files
                echo "$files_to_remove" | xargs rm
            done
            echo "removeInBatch (): removed files older than ${removeBatchArray[1]} mins from ${removeBatchArray[0]}"
            echo "removeInBatch (): freed space (- $(formatBytes $total_space_freed) ) path ${removeBatchArray[0]} mounted on \" $( df ${checkErrorArray[i]} |tail -n -1 | awk '{print $6}') \""
        else
            echo "removeInBatch (): no file is older than ${removeBatchArray[1]} mins from ${removeBatchArray[0]} "
        fi
    fi
}

# Check for partitions with error level
# Usage: checkError ${array[@]}
function checkError () {
	if [[ $# -ne 0 ]]; then
		checkErrorArray=($@)
		for (( i=0; i < ${#checkErrorArray[@]}; )); do
			#check if the path exists
			if [[ $(checkPath ${checkErrorArray[i]}) -ne 0 ]]; then
				local tempUsage=$( df ${checkErrorArray[i]} |tail -n -1 | awk '{print $5}'|sed 's/.$//' )
				# Check usage with lower threshold
				if [ $tempUsage -gt ${checkErrorArray[${i+1}]} ]; then
					# Check usage with upper threshold
					if  [ $tempUsage -lt ${checkErrorArray[${i+2}]} ]; then
						eval tmparr=\( \${${checkErrorArray[${i+3}]}[@]} \)
						for j in ${tmparr[@]}; do
							eval clearArr=\( \${${j}[@]} \)
							# Check the input is for backup and compress or only remove
							if [[ ${#clearArr[@]} -ne 2 ]]; then
								moveInBatch ${clearArr[@]}
								if [[ $(checkPath ${clearArr[1]}) -ne 0 && $(checkPath ${clearArr[2]}) -ne 0 ]]; then
									compressInBatch ${clearArr[@]}
								fi
							else
								removeInBatch ${clearArr[@]}
							fi
						done
					else
						echo "Warning: the disk usage is $tempUsage% (Upper threshold:${checkErrorArray[${i+2}]}%), Plz check it manually!!!"
					fi
				else
					echo "Msg: the disk usage is only $tempUsage % (Lower threshold:${checkErrorArray[${i+1}]}%)"
				fi
			fi
			(( i=i+4 ))
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
	while read -r line && [ "$line" != "quit" ]; do
		printf '%s %s %s\n' "$(date +"%Y-%m-%d %T")" "[LOG]:" "$line"
	done
}