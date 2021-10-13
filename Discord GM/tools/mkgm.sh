#!/usr/bin/bash
#
# Create GM sfz from control file
#
# Usage: mkgm.sh [-f flac] [-t] [-d] [-m] [plan-file]
#
# where
#   -f flac = build flac-format (including converting .wav samples) [NYI]
#   -t = build test format (using sequential program numbers rather than GM bank numbers)
#   -m = build melodic only
#   -d = build drums only
#   -c = build combined only
#   Default is to build all three.
#
# RUN THIS FROM 'Discord GM' DIRECTORY!

# Script license: Creative Commons CC0 - Jeff Learman

# Collate all instrumings into a single GM sfz file.
# Create six versions:
#   melodic only
#   drums only
#   combined
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

# soundfont name prefix (before -drums, -melodic, etc.)
SETNAME="Discord GM Bank"

BUILD_MELODIC=false
BUILD_DRUMS=false
BUILD_COMBINED=false
BUILD_ALL=true
TEST=false
SUFFIX=
FMT=wav

# parse option switches

while [[ ${1:0:1} = "-" ]] ; do
    if [[ $1 = -f ]] ; then
        FMT=$2
        shift 2
    fi

    # Test mode: use sequential program numbers rather than GM bank numbers,
    # to make it easier to scroll through a sparse set.
    if [[ $1 = -t ]] ; then
        TEST=true
        SUFFIX=-test
        shift
        echo "... making test version(s)"
    elif [[ $1 = -d ]] ; then
        BUILD_DRUMS=true
        BUILD_ALL=false
        shift
    elif [[ $1 = -m ]] ; then
        BUILD_MELODIC=true
        BUILD_ALL=false
        shift
    elif [[ $1 = -c ]] ; then
        BUILD_COMBINED=true
        BUILD_ALL=false
        shift
    else
        echo "unrecognized option: $1"
        exit 1
    fi
done

if $BUILD_ALL ; then
    BUILD_MELODIC=true
    BUILD_DRUMS=true
    BUILD_COMBINED=true
fi

# 1st argument: plan file
PLANFILE=${1:-$TOOLS/GM-plan.txt}

GLOBAL_NAME="Discord GM"

buildsfz()
{
    BUILD_TYPE=$1; shift
    OUTFILE="$1$SUFFIX.sfz"; shift
    TMPFILE=tmp.sfz

    echo > $TMPFILE
    # put global stuff here

    echo >> $TMPFILE

    let "SFZPROG = -1"
    LASTTYPE=none
    SPACE=$'x'
    grep -v "^#" $PLANFILE | tr -d '\r' | while IFS="|" read TYPE PROG VOL SFZ GMNAME SFNAME ; do
        BANK=1

        # strip leading & trailing spaces
        TYPE=`echo $TYPE`
        let "PROG = $PROG"
        VOL=`echo $VOL`
        SFZ=`echo $SFZ`
        GMNAME=`echo $GMNAME`
        SFNAME=`echo $SFNAME`

        # skip blank lines -- yeah there's a better way
        if [[ $TYPE == "" ]] ; then
            continue
        fi

        if [[ $BUILD_TYPE != combined ]] && [[ $BUILD_TYPE != $TYPE ]] ; then
            continue
        fi

        if [[ $LASTTYPE != $TYPE ]] && [[ -f $TOOLS/header-$TYPE.txt ]] ; then
            cat $TOOLS/header-$TYPE.txt
            echo
            echo "// $TYPE instruments"
            echo
            if [[ $BUILD_TYPE = all ]] ; then
                if [[ $TYPE = Drums ]] ; then
                    echo
                    echo "locc0=0 hicc0=120 locc0=120 hicc0=120"
                    echo
                elif [[ $TYPE = Melodic ]] ; then
                    echo
                    echo "locc0=121 hicc0=127 locc32=0 hicc32=0"
                    echo
                fi
            fi
        fi

        SFZFILE=$TYPE/$SFZ.sfz
        SAMPFLDR=$TYPE/$SFZ

        if [[ "$SFNAME" = "OMIT" ]] ; then
            echo "NOTE: $SFZ explicitly omitted in $PLANFILE" >&2
            LASTTYPE=$TYPE
            continue
        fi

        if [[ "$SFNAME" = "none" ]] ; then
            if [[ ! -d $SAMPFLDR ]] ; then
                LASTTYPE=$TYPE
                continue
            fi
            echo "NOTE: PLEASE edit $PLANFILE and replace '$SFNAME' with a name for $SFZ, showing the original source." >&2
            SFNAME=""
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
        printf "%-14s  " "TYPE=\"$TYPE\""
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
}

if $BUILD_MELODIC ; then
    echo "... building melodic sfz"
    buildsfz Melodic "$SETNAME - Melodic"
fi

if $BUILD_DRUMS ; then
    echo "... building drums sfz"
    buildsfz Drums "$SETNAME - Drums"
fi

if $BUILD_COMBINED ; then
    echo "... building combined sfz"
    buildsfz combined "$SETNAME"
fi

