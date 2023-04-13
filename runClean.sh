#!/bin/bash

# Load the config file
source ./cleanScriptCFG.cfg

# exec the sh with timeout feature
timeout ${TIME_LIMIT} ./automationScript.sh

# Check the exit status of the timeout command
if [ $? -eq 124 ]; then
    echo "The script was terminated after reaching the time limit of ${TIME_LIMIT}"
fi