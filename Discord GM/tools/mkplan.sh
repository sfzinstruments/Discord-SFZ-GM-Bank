#!/usr/bin/bash

# Make initial GM-plan.txt file

# Melodic |   1 |  0   | 001-Acoustic Grand Piano     | Acoustic Grand Piano     | Salamander Grand

for F in Melodic/*.sfz Drums/*.sfz ; do
    DIR=`dirname "$F"`
    SFZ=`basename -s .sfz "$F"`
    PROG=${SFZ:0:3}
    PROG=$((10#$PROG))  # convert decimal with leading digits to decimal
    INST=${SFZ:4}

    printf "%-7s | %3d |  0   | %-28s | %-24s | unknown\n" \
        "$DIR" \
        "$PROG" \
        "$SFZ" \
        "$INST" 
done
