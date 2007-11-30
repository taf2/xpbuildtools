#!/bin/bash

# setup environment to compile mozilla
export CVSROOT=:pserver:anonymous@cvs-mirror.mozilla.org:/cvsroot
export CVS_RSH=ssh

# settings for building and working in mozilla source
export MOZILLA_OFFICIAL=1
export BUILD_OFFICIAL=1
export MOZ_BUILD=debug # release
export MOZ_MODE=1.8 # trunk or 1.7
export MOZ_OBJDIR=$HOME/projects/moz$MOZ_MODE/$MOZ_BUILD
export MOZ_SRCDIR=$HOME/projects/moz$MOZ_MODE/mozilla
export MOZCONFIG=$HOME/projects/moz$MOZ_MODE/mozconfig.$MOZ_BUILD

# shell tools for mozilla
alias cdm='cd $MOZ_SRCDIR'
cdb() {
  if [ "X$MOZ_OBJDIR" = "X" ]; then
    cd $MOZ_SRCDIR/dist/bin
  else
    cd $MOZ_OBJDIR/dist/bin
  fi
}

alias cdp="cd $HOME/projects/"
alias cdd="cd $HOME/Desktop/"

replace()
{
	echo $1 | sed -e "s/$2/$3/g"
}

plen()
{
	p1=(`replace $1 '\/' ' '`)
	echo ${#p1[*]}
}

# flip between objdir and srcdir
# relative paths
flip() {
	cwd=`pwd`

	# get the base common parts of each path
	srcbase=`bpath $cwd $MOZ_SRCDIR`
	objbase=`bpath $cwd $MOZ_OBJDIR`
	basebase=`bpath $MOZ_OBJDIR $MOZ_SRCDIR`
	# get the length of the common parts
	baselen=`plen $basebase`
	srclen=`plen $srcbase`
	objlen=`plen $objbase`

	# we're in source if our length is longer then baselen
	if [ $srclen -gt $baselen ]; then
		diff=`dpath $MOZ_SRCDIR $cwd`
		cd $MOZ_OBJDIR/$diff
		return 0
	elif [ $objlen -gt $baselen ]; then
		diff=`dpath $MOZ_OBJDIR $cwd`
		cd $MOZ_SRCDIR/$diff
		return 0
	else
		#echo "not in either '$MOZ_SRCDIR' or '$MOZ_OBJDIR'?"
		return 1
	fi

  #dir=$(_flip.helper)
  #if [ "x$dir" != "x" ]; then
  #  cd $dir
  #fi
}

# FIXME: Warning this will be totally broken if you have spaces in your
# path names need to figure out how to create a bash array not delimated
# by spaces but by directory separaters '/'
#
# Return the first part of two paths that is common
bpath()
{
	p1=(`replace $1 '\/' ' '`)
	p2=(`replace $2 '\/' ' '`)
	
	i=0
	j=0
	len=${#p1[*]}
	jlen=${#p2[*]}
	result=""

	# walking the array of directories
	while ([ $i -lt $len ]  && [ $j -lt $jlen ]); do
		vp1="${p1[$i]}"
		vp2="${p2[$j]}"
		if [ $vp1 != $vp2 ]; then
			break;
		fi
		result="$result/$vp1"
		let i++
		let j++
	done
	echo $result
}
# Return the trailing difference of two paths
# starts with the longest path and echos each component
# until it reaches the tail of the first one
# e.g. dpath /home/foo /home/ 
# returns foo/
dpath()
{
	p1=(`replace $1 '\/' ' '`)
	p2=(`replace $2 '\/' ' '`)
	
	len=${#p1[*]}
	jlen=${#p2[*]}
	result=""

	if [ $len -gt $jlen ]; then
		i=$len
		while [ $i -gt $jlen ]; do
			let i--
			vp="${p1[$i]}"
			result="${vp}/$result"
		done
	else
		i=$jlen
		while [ $i -gt $len ]; do
			let i--
			vp="${p2[$i]}"
			result="${vp}/$result"
		done
	fi
	echo $result
}

mk() {
  flipback=0
  if [ ! -f Makefile ]; then
    flip
    flipback=1
  fi
  make -s $*
  if [ $flipback = 1 ]; then
    flip
  fi
}
set_mozbuilddir() {
	dir=`readlink -f $1`
	export MOZ_OBJDIR=$dir/$MOZ_BUILD
	export MOZ_SRCDIR=$dir/mozilla
	export MOZCONFIG=$dir/mozconfig.$MOZ_BUILD
}
set_objdir() {
  dir=$1
  if [ x"$dir" = x ]; then
    dir=`pwd`
  fi
  export MOZ_OBJDIR=$dir
  echo 'MOZ_OBJDIR='$MOZ_OBJDIR
}
set_srcdir() {
  dir=$1
  if [ x"$dir" = x ]; then
    dir=`pwd`
  fi
  export MOZ_SRCDIR=$dir
  echo 'MOZ_SRCDIR='$MOZ_SRCDIR
}
set_mozconfig() {
  if [ x"$1" = x ]; then
    export MOZCONFIG="$MOZ_OBJDIR/.mozconfig"
  else
    export MOZCONFIG=$1
  fi
  echo 'MOZCONFIG='$MOZCONFIG
}

select_moz_tree() {
  set_srcdir "$1/mozilla"
  set_objdir "$1/$2-build"
  set_mozconfig "$1/$2.mozconfig"
}

work_sea_trunk_debug() {
  select_moz_tree "/cygdrive/c/builds/moz-trunk" "sea-debug"
}
