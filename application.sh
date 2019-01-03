#!/bin/bash

readarray -t keywords < keywords.txt 
declare -a pathArray
rm -f temp.txt 
touch temp.txt 

### Function used to get the running processes 
function Get-Application (){
	
	### Initialize variables
	server=$(hostname)
	date=$(date +%m-%d-%Y"="%H:%M:%S)
	FirstDiscovered="$date"
	LastDiscovered="$date"

	### Used to check to see what commands are found
	if type locate > /dev/null; then
		updatedb
		locateOutput=$(locate -ei --regex '(java|jre|jdk|jvm)' -q) #find all paths that have the keywords
	elif type find > /dev/null; then
		locateOutput=$(find / -name "java" -o -name "jre" -o -name "jdk" -o -name "jvm")
	else
		locateOutput=''
	fi	

	printf "%s\n" "$locateOutput" >> temp.txt # Store output of locate command into text file
	readarray -t pathArray < temp.txt ### Put contents of text file into pathArray
	> temp.txt
	
	for ((  i=0; i<${#pathArray[@]}; i++ ))
	do
		path=${pathArray[$i]}

		if [ -f "$path" ]; then
			IFS='/' read -r -a lineArray <<< "$path"
		
			if [[ ${lineArray[-1]} == *"java"* ]] && [[ ${lineArray[-1]} != *"."* ]]; then
				Add $server $path $FirstDiscovered $LastDiscovered	
			else
				continue
			fi
		else
			Trim $path #Function to trim path
			path=${path%?} #Remove last character (/)
		
			if [[ -n "$path" ]] && !(grep -q "$path" temp.txt); then
				Add $server $path $FirstDiscovered $LastDiscovered
			fi
		fi

	done
	
	readarray -t applicationArray < temp.txt
}

function Add () { 
	IFS='/' read -r -a  fileLine <<< "$path"		

	if [[ -f $path ]] && (ls -l "$path" | egrep -q "x") && [[ ${#fileLine[${#fileLine[@]}-1]} -eq 4 ]] && (echo ${fileLine[-1]} | grep -q '\<java\>'); then
		type='JAVA'
		version=$("$path" -version 2>&1 | head -1 | cut -d '"' -f 2)			
	
		if echo "$version" | egrep -q "(No|Such|Error|ERROR|File|Directory|bash)" || [ -z "$version" ];then
			version='NONE'
			type='EXE'
		fi
	elif [ -f $path ] && (ls -l "$path" | egrep -q "x"); then
		type='EXE'
		version='NONE'
	else
		version='NONE'
		type='FOLDER'	
	fi
	
	LastAccessDate=$(stat -c %y "$path" | awk '{print $1 "=" $2}' )
	line=$(echo "$server,$path,$type,$version,$LastAccessDate,$FirstDiscovered,$LastDiscovered")
	printf "%s\n" "$line" >> temp.txt ### Put line into temp text file
}

function Trim () { #### Function to trim output
	IFS='/' read -r -a line <<< "$path"
	cutNow=0
	
	for (( j= (${#line[@]}-1); j>=1 ; j-- ))
	do
		for item in "${keywords[@]}"; 
		do
			### If path/folder contains a keyword and does not contain a period we cut there 
			if [[ ${line[$j]} == *"$item"* ]] && [[ ! ${line[$j]} == *"."* ]] ; then 
				cutNow=1 
				break 
			fi	
		done		
	
		if [ "$cutNow" -eq 1 ]; then
			break
		fi
	done

	if [ "$j" -ge 1 ]; then ## Trim path based on the position of the keyword 
		j=$((j+1))
		path=$(printf "%s/" "${line[@]:0:$j}")
	else
		path='' #delete path
	fi
}

#### Function used to create report file if not created
function Create-File () {
	### FIll in headers + Data
	printf '%s\n' Server Path Type Version LastAccessDate FirstDiscovered LastDiscovered | paste -sd ',' > java_application.csv
	printf '%s\n' "${applicationArray[@]}" >> java_application.csv
}

### Function used to modify file if it exists
function Modify-File () {
	for (( j=0; j<${#applicationArray[@]}; j++ ))
	do
		checkPath=($(printf "%s\n" "${applicationArray[$j]}" | awk -F, '{print $2}'))
		
		if grep -q "$checkPath" java_application.csv; then ### Update last discovered date if the path was found in file
			echo "$(awk -v path="$checkPath" -v currentTime="$date" 'BEGIN{FS=OFS=","}{if($2==path) $7=currentTime}1' java_application.csv)" > java_application.csv
		else ### Add application information if it was not found
			printf "%s\n" "${applicationArray[$j]}" >> java_application.csv
		fi	

	done
}


##################################### MAIN PROGRAM ###############################
###### Matthew Tang            ######
###### Java Discovery Project  ######
###### Find Java Applications  ######
###### October 30th, 2018      ######
#####################################

Get-Application ### Function to get applications
if [ ! -f java_application.csv ]; then
	echo 'Creating file'
	Create-File
elif [ -f java_application.csv ]; then
	echo 'File exists'
	Modify-File
else
	echo "No installed applications"
fi

rm -f temp.txt  ## Delete temp files
