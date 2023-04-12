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
source ./cleanFunctions.sh


# -------------------- CALL --------------------
if (( $LOG_SWITCH == 1 )); then
    # Use a subshell instead of process substitution
    (
        # Load in the source configurations
        # include ./automationSource.sh
        # Execution of compiled script

        # show the current time when we run the script
        echo "------------------START--------------------------"
        runFunArgArray "${FUN_ARG_LIST[@]}"
        echo "------------------END--------------------------"

    ) | addTimeStamp | tee -a "${LOG_PATH}"
else
	(
        # Load in the source configurations
        # include ./automationSource.sh
        # Execution of compiled script

        # show the current time when we run the script

        echo "------------------START--------------------------"
        runFunArgArray "${FUN_ARG_LIST[@]}"
        echo "------------------END--------------------------"
	) | addTimeStamp
fi