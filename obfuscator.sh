#!/bin/bash

echo
echo "This file is not used anymore is it?  -allan"
echo

# arg1: path to tools dir
# arg2: name of the source file to obfuscate
# arg3: name of the file to save to

tooldir=$1
input=$2
output=$3

jsjam=$tooldir/jsjam.pl
linecrunch=$tooldir/linecruncher

$jsjam -a "Copyright (c) 2004-2005, Simo Software Inc." -q -g -n $input  > $output #| $linecrunch > $output
