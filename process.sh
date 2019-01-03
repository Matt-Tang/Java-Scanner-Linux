#!/bin/bash

readarray -t keywords < keywords.txt
declare -a pidArray 
declare -a processArray

### Delete and create temp files
rm -f temp.txt pid.csv
touch temp.txt pid.csv

### Function used to get the running processes 
function Get-Process () {
	
	### Initialize variables
	server=$(hostname)
	date=$(date +%m-%d-%Y"="%H:%M:%S)

	for (( i=0; i<${#keywords[@]}; i++ )) ### For each keyword search the running processes
	do

		### If the keyword is a null or space by accident move on
		if [ -z "${keywords[$i]}" ]; then
			continue
		fi

		pgrep -f ${keywords[$i]} | while read PID ### Returns the PID of the processes who's command line matches the keyword
		do	
			if grep -q "$PID" pid.csv; then ### If PID found already skip to next process
				continue
			else
				processName=($(ps -p $PID -o comm=))
				userName=($(ps -p $PID -o user=))
				path=$(readlink -f /proc/$PID/exe)
				counter=1
				version='NONE'
				commandLine=$(xargs -0 < /proc/$PID/cmdline | tr -d '[:space:]') 
				FirstDiscovered="$date"
				LastDiscovered="$date"
		
				if [ -z "$path" ]; then # If path is empty try another command to get path
					path=$(ls -alF /proc/$PID/exe | awk '{print $NF}')
				fi

				IFS='/' read -r -a pathArray <<< "$path"

				if [ -z "$processName" ] || [ -z "$userName" ] || [ -z "$path" ] || [ -z "$commandLine" ]; then
					printf '%s\n' "$server,$processName,$user,$path,$commandLine,$date" >> error.txt
					continue
				fi

				if [[ -f $path ]] && [[ ${#pathArray[${#pathArray[@]}-1]} -eq 4 ]] && (echo ${pathArray[-1]} | grep -q '\<java\>'); then
					version=$("$path" -version 2>&1 | head -1 | cut -d '"' -f 2)
				
					if echo "$version" | egrep -q "(No|Error|Such|File|Directory|bash|Unknown)" || [ -z "$version" ]; then
						version='NONE'
					fi
				fi

		
				#### If the command line is found, increment the counter
				if grep -q "$commandLine" temp.txt; then
					echo "$(awk -v commandLine="$commandLine" 'BEGIN{FS=OFS=";"}{if($NF==commandLine) $6+=1}1' temp.txt)" > temp.txt
				else
					printf "%s\n" $server $processName $userName $path $version $counter $FirstDiscovered $LastDiscovered $commandLine | paste -sd ";"  >> temp.txt ### Store line in temp file
				fi

				printf '%s\n' "$PID" >> pid.csv	## record down the PID in case another search finds the same process
			fi
		done
	done

	readarray -t processArray < temp.txt ### Put all the contents of temp file into processArray
}

#### Function used to create report file if not created
function Create-File () {
	### FIll in headers + Data
	printf '%s\n' Server Name User Path Version Counter FirstDiscovered LastDiscovered CommandLine | paste -sd ';' > java_process.txt
	printf '%s\n' "${processArray[@]}" >> java_process.txt
}

### Function used to modify file if it exists
function Modify-File () {
	for (( j=0; j<${#processArray[@]}; j++ ))
	do
		checkCommand=($(printf "%s\n" "${processArray[$j]}" | awk 'BEGIN{FS=";"} {print $NF}'))
	
		if grep -q "$checkCommand" java_process.txt; then ### Check to see if current command is found in existing file, if yes -> update counter + date, if no -> add to file
			runningCounter=$(awk -v commandLine="$checkCommand" 'BEGIN{FS=OFS=";"}{if($NF==commandLine) {print $6}}' temp.txt)
			echo "$(awk -v commandLine="$checkCommand" -v rCounter="$runningCounter" -v discovered="$date" 'BEGIN{FS=OFS=";"}{if($NF==commandLine){$6+=rCounter ;$8=discovered}}1' java_process.txt)" > java_process.txt
		else
			printf "%s\n" "${processArray[$j]}" >> java_process.txt
		fi	
	done
}

##################################### MAIN PROGRAM ###############################
####### Matthew Tang              ###
####### Java Discovery Project    ###
####### Find java processes       ###
####### October 28th, 2018        ###
##################################### 

Get-Process ### Function to get the processes
if [ ! -f java_process.txt ]; then ### If file is not created
	echo 'Creating file'
	Create-File
elif [ -f java_process.txt ]; then ### If file already ecists
	echo 'File exists'
	Modify-File
fi

rm temp.txt pid.csv  ## Delete temp files
