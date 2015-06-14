#!/bin/bash
#  Meraki PartBuilder
#  Used to Generate a Valid Kernel for the Meraki MR18
#  Copyright (C) 2015 Chris Blake <chrisrblake93@gmail.com>
#
#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License version 2 as published
#  by the Free Software Foundation.
#

# Variables
# DO NOT CHANGE UNLESS YOU KNOW WHAT YOU ARE DOING!
FileSize=8388608 # 8 MB
MagicKey="8e73ed8a"
HeaderLength="00000400"
KernelSize=""
SHA1Sum=""
NullFiller="00000000"
SigningSHA1="da39a3ee5e6b4b0d3255bfef95601890afd80709"
MasterTemp=""

PrintHelp() {
	echo "Meraki PartBuilder - Generate Meraki NandLoader Kernel Images"
	PrintUsage
	exit 0
}

PrintUsage() {
	echo "Usage: partbuilder.sh [-h] inputkernel outputfile"
}

ErrorExit() {
	echo "Error: $1"
	PrintUsage
	exit 1
}

WriteHex() {
	# $1 = Hex we are outputting
	# $2 = Output File to Append too
	echo -n -e $1 >> $2
}

GetKernelSize() {
	# $1 = Input File
	KernelSize=`stat --printf="%s" $1 | xargs printf '%x\n'`
	
	# Are we long enough?
	size=${#KernelSize}
	while [ $size -lt 8 ]
	do
		KernelSize=0$KernelSize
		let size=${#KernelSize}
	done
	
	# Return Result
	MasterTemp="$KernelSize"
	return 0
}

ConvertToPrintableHex() {
	# $1 = Hex to convert into printable
	# ex: 4455 = \\x44\\x55
	TempData=""
	counter=0
	for value in $(echo $1 | sed -e 's/\(.\)/\1\n/g') ; do
		if [ $counter -eq 0 ] ; then
			TempData="$TempData\\x"
		fi
		let counter=counter+1
		TempData="$TempData$value"
		if (( $counter % 2 == 0 )) ; then
			let counter=0
		fi
	done
	MasterTemp="$TempData"
	return 0
}

SHA1File() {
	SHA1Sum=`sha1sum $1 | awk '{print $1}'`
	return 0
}

PadHeader() {
	# $1 = File to Pad
	Padding="\\xff"
	CurrentLength=`stat --printf="%s" $1 | xargs printf '%x\n'`
	RequiredPadding=`echo $((0x$HeaderLength - 0x$CurrentLength))`
	COUNTER=0
    while [  $COUNTER -lt $RequiredPadding ]; do
		WriteHex $Padding $1
		let COUNTER=COUNTER+1 
    done
	return 0
}

PadFile() {
	# $1 = File to Pad
	Padding="\\xff"
	CurrentLength=`stat --printf="%s" $1 | xargs printf '%x\n'`
	MaxFileSizeHex=`printf '%x\n' $FileSize`
	RequiredPadding=`echo $((0x$MaxFileSizeHex - 0x$CurrentLength))`
	dd if=/dev/zero bs=1 count=$RequiredPadding status=none | tr '\000' '\377' >> $1
	return 0
}

ApplyKernel() {
	dd if=$1 bs=1 status=none >> $2
}

if [ ! "$1" ]; then
	ErrorExit "missing input kernel!"
elif [ "$1" == '-h' ]; then
	PrintHelp 
elif [ ! "$2" ]; then
	ErrorExit "missing target file!"
else
	if [ -e $2 ]; then
		ErrorExit "target file $2 already exists!"
	fi
	# Start Printing to Output File Header Information
	echo "Writing Magic Key"
	ConvertToPrintableHex $MagicKey
	WriteHex $MasterTemp $2 # Magic Key
	echo "Writing Header Length"
	ConvertToPrintableHex $HeaderLength
	WriteHex $MasterTemp $2 # Header Length
	echo "Writing Data Length"
	GetKernelSize $1
	ConvertToPrintableHex $KernelSize
	WriteHex $MasterTemp $2 # Data Length
	echo "Writing SHA1 Sum"
	SHA1File $1
	ConvertToPrintableHex $SHA1Sum
	WriteHex $MasterTemp $2 # SHA1 Sum
	echo "Writing Magic Key Again"
	ConvertToPrintableHex $MagicKey
	WriteHex $MasterTemp $2 # Magic Key
	echo "Writing Filler"
	ConvertToPrintableHex $NullFiller
	WriteHex $MasterTemp $2 # Filler
	echo "Writing Static Hash"
	ConvertToPrintableHex $SigningSHA1
	WriteHex $MasterTemp $2 # Hash\n
	echo "Padding Header"
	PadHeader $2
	echo "Writing Kernel to File"
	ApplyKernel $1 $2
	echo "Padding Rest of Image"
	PadFile $2
	echo "Done! :)"
fi
