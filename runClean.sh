#!/bin/bash

source ./cleanScriptCFG.cfg

timeout ${TIME_LIMIT} ./automationScript.sh

# Check the exit status of the timeout command
if [ $? -eq 124 ]; then
    echo "The script was terminated after reaching the time limit of ${TIME_LIMIT}"
fi