#!/usr/bin/bash
#
# Create GM sfz from control file
#
# Usage: mkgm.sh [-f flac] [-t] [plan-file]
#
# where
#   -f flac = build flac-format (including converting .wav samples) [NYI]
#   -t = build test/debug format (using sequential program numbers rather than GM bank numbers)

# Script license: Creative Commons CC0 - Jeff Learman

# Collate all instrumings into a single GM sfz file.
# Create six versions:
#   melodic only
#   drums only
#   combined        *** Currently only this one is supported! ***
#   melodic only, simplified
#   drums only, simplified
#   combined, simplified
#
# The simplified versions do not use #include, #define, or default_path
#
# For all .sfz files, the name format is:
#
#   <prog[:bank]>-<name>
#
# where
#   <name> is the instrument name per the GM spec (GM 1 for bank 1)
#   <prog[:<bank>]> is the 3-digit program number (1-based, with leading zeros)
#                 with optional ":<bank>" suffix
#   <bank> is a 1-digit bank number, 2 through 9.  If absent, 1 is assumed.
#
# The samples folder for an instrument must be in the same folder as
# the .sfz for the instrument.
#
# By convention, sample folder names match the instrument name except
# for the ".sfz" extension.
#
# Note that one instrument may use samples from another instrument,
# but only in the same sub-folder (melodic or drums).

# Do not use #include, #define, or `default_path` in the instrument .sfz files.

# NOTE: banks other than 1 are not yet supported, but the convention above will alow it.

# tools dir
TOOLS=tools

FMT=wav
if [[ $1 = -f ]] ; then
    FMT=$2
    shift 2
fi

# Debug mode: use sequential program numbers rather than GM bank numbers,
# to make it easier to scroll through a sparse set.

TEST=false
SUFFIX=
if [[ $1 = -t ]] ; then
    shift
    TEST=true
    SUFFIX=-test
fi

PLANFILE=${1:-$TOOLS/GM-plan.txt}

GLOBAL_NAME="Discord GM"
OUTFILE="Discord GM Bank$SUFFIX.sfz"
TMPFILE=tmp.sfz

echo > $TMPFILE
# put global stuff here

echo >> $TMPFILE

let "SFZPROG = -1"
LASTTYPE=none
grep -v "^#" $PLANFILE | while read LINE ; do
    LINE=`echo "$LINE" | tr -d '\r'`
    BANK=1

    TYPE=`      echo $LINE | cut -d\| -f1 | xargs echo -n`
    PROG=`      echo $LINE | cut -d\| -f2 | xargs echo -n`
    VOL=`       echo $LINE | cut -d\| -f3 | xargs echo -n`
    SFZ=`       echo $LINE | cut -d\| -f4 | xargs echo -n`
    GMNAME=`    echo $LINE | cut -d\| -f5 | xargs echo -n`
    SFNAME=`    echo $LINE | cut -d\| -f6 | xargs echo -n`

    # skip blank lines -- yeah there's a better way
    if [[ $TYPE == "" ]] ; then
        continue
    fi

    if [[ $LASTTYPE != $TYPE ]] && [[ -f $TOOLS/header-$TYPE.txt ]] ; then
        cat $TOOLS/header-$TYPE.txt
        echo
        echo "// $TYPE instruments"
        echo
    fi

    SFZFILE=$TYPE/$SFZ.sfz
    SAMPFLDR=$TYPE/$SFZ

    # DELETEME: quick results during initial debug
    if $TEST && [[ $PROG -gt 26 ]] ; then
        break
    fi

    if [[ "$SFNAME" = "none" ]] ; then
        LASTTYPE=$TYPE
        continue
    fi

    if $TEST ; then
        let "SFZPROG = SFZPROG + 1"
        let "TEST_PROG = SFZPROG + 1"
        let "MENUPROG = $SFZPROG + 1"
        MENUPROG="$PROG($MENUPROG)"
    else
        let "SFZPROG = $PROG - 1"
        let "MENUPROG = $PROG"
    fi

    if [[ ! -f "$SFZFILE" ]] ; then
        echo "Error: Sample file \"$SFZFILE\" does not exist" 1>&2
        exit 1
    fi

    if [[ ! -d "$SAMPFLDR" ]] ; then
        echo "Error: Sample folder \"$SAMPFLDR\" does not exist" 1>&2
        exit 1
    fi

    (
    printf "%-8s  " "TYPE=\"$TYPE\""
    printf "%-12s " "PROG=\"$MENUPROG\""
    printf "%-10s " "VOL=\"$VOL\""
    printf "%-34s " "SFZ=\"$SFZ\""
    printf "%-34s " "GMNAME=\"$GMNAME\""
    printf "%-30s " "SFNAME=\"$SFNAME\""
    echo
    ) 1>&2

    if [[ $BANK != 1 ]] ; then
        echo "Banks other than 1 not yet supported, ignoring."
    fi

    let "SFZBANK = $BANK - 1"

    # // 0 Acoustic Grand Piano
    # <master> loprog=0 hiprog=0 master_label=1 - Acoustic Grand Piano - Salamander Grand
    # #include "SalamanderGrand.sfz"

    if $TEST ; then
        P="$PROG($TEST_PROG)"
    else
        P=$PROG
    fi
    echo "<master> loprog=$SFZPROG hiprog=$SFZPROG master_volume=$VOL master_label=$BANK:$P - $GMNAME - $SFNAME #include \"$SFZFILE\""

    LASTTYPE=$TYPE

done >> $TMPFILE

if [[ $? != 0 ]] ; then
    exit 1
fi

mv $TMPFILE "$OUTFILE"

