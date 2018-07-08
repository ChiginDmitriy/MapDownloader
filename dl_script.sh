#!/bin/bash

#########################################
# INPUT PARAMS (possible combinations): #
#########################################
# 1. Output dir only. Algorithm params are set by default.
# 2. Output dir, algorithm params file. Algorithm params will be taken from this file.
#    Some params in the file may be missing - their values will be set by default values.

#########################
# Checking input params #
#########################
# Checking args count
if [[ ( "$#" -ne 1 ) && ( "$#" -ne 2 ) ]]; then
  echo "Possible variants of input params:"
  echo "1. Output dir."
  echo "2. Output dir, algorithm params file."
  exit
fi

# Checking output dir
if [ ! -d "$1" ]; then
  if [ -e "$1" ]; then
    # $1 is a regular file, not dir
    echo "Can't create dir due to file existing!"
    exit
  else
    mkdir "$1"
    if [ ! -d "$1" ]; then
      echo "Couldn't create dir. Exiting..."
      exit
    fi
  fi
fi

# Checking algorithm params file
if [[ ( "$#" -eq 2 ) && ( ! -f "$2" ) ]]; then
  echo "I did not find settings regular file."
  exit
fi

# If settings file is presented, let's try to read settings from it.
if [[ "$#" -eq 2 ]]; then
  # Deleting comments
  noComments=$(sed -r 's/[ \t]*[#].*//; /^[ \t]*$/d' "$2")

  # Checking if every parameter is set only once
  # Also check if ini file has no rubbish
  allParamsString=""
  for paramName in x_zone_count \
                   y_zone_count \
                   whole_beg_x  \
                   whole_end_x  \
                   whole_beg_y  \
                   whole_end_y  \
                   max_resolution
  do
    timeCount=$(echo "$noComments" | egrep -i -c "$paramName")
    if [[ "$timeCount" -gt 1 ]]; then
      echo "$paramName set too many times !"
      exit
    fi
    if [[ -z "$allParamsString" ]]; then
      allParamsString="($paramName)"
    else
      allParamsString="$allParamsString|($paramName)"
    fi
  done
  rubbishStringCount=$(echo "$noComments" | egrep -i -c -v "$allParamsString" )
  if [[ $rubbishStringCount -ne 0 ]]; then
    echo "I found some rubbish in the ini file."
    exit
  fi

  # Reading X_ZONE_COUNT
  readXZoneCount=$(                                                                         \
    echo "$noComments" |                                                                    \
    egrep -i "^[[:space:]]*x_zone_count[[:space:]]*=[[:space:]]*[0-9]+[[:space:]]*$" "$2" | \
    egrep -o "[0-9]+"                                                                       \
  )
  if [[ ( -z "$readXZoneCount" ) || ( "$readXZoneCount" -lt 1 ) ]]; then
    echo "Could not get correct X_Zone_Count, will take default value."
    readXZoneCount=""
  fi
  
  # Reading WHOLE_BEG_X
  readWholeBegX=$(                                                                                       \
    echo "$noComments" |                                                                                 \
    egrep -i -e '^[[:space:]]*whole_beg_x[[:space:]]*=[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]*$' "$2" | \
    egrep -o "[0-9.]+"                                                                                   \
  )
  if [[ -z "$readWholeBegX" ]]; then
    echo "Could not get correct whole_beg_x, will take default value."
    readWholeBegX=""
  fi

  # Reading WHOLE_END_X
  readWholeEndX=$(                                                                                       \
    echo "$noComments" |                                                                                 \
    egrep -i -e '^[[:space:]]*whole_end_x[[:space:]]*=[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]*$' "$2" | \
    egrep -o "[0-9.]+"                                                                                   \
  )
  if [[ -z "$readWholeEndX" ]]; then
    echo "Could not get correct whole_end_x, will take default value."
    readWholeEndX=""
  fi

  # Reading Y_ZONE_COUNT
  readYZoneCount=$(                                                                         \
    echo "$noComments" |                                                                    \
    egrep -i "^[[:space:]]*y_zone_count[[:space:]]*=[[:space:]]*[0-9]+[[:space:]]*$" "$2" | \
    egrep -o "[0-9]+"                                                                       \
  )
  if [[ ( -z "$readYZoneCount" ) || ( "$readYZoneCount" -lt 1 ) ]]; then
    echo "Could not get correct Y_Zone_Count, will take default value."
    readYZoneCount=""
  fi

  # Reading WHOLE_BEG_Y
  readWholeBegY=$(                                                                                       \
    echo "$noComments" |                                                                                 \
    egrep -i -e '^[[:space:]]*whole_beg_y[[:space:]]*=[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]*$' "$2" | \
    egrep -o "[0-9.]+"                                                                                   \
  )
  if [[ -z "$readWholeBegY" ]]; then
    echo "Could not get correct whole_beg_y, will take default value."
    readWholeBegY=""
  fi

  # Reading WHOLE_END_Y
  readWholeEndY=$(                                                                                       \
    echo "$noComments" |                                                                                 \
    egrep -i -e '^[[:space:]]*whole_end_y[[:space:]]*=[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]*$' "$2" | \
    egrep -o "[0-9.]+"                                                                                   \
  )
  if [[ -z "$readWholeEndY" ]]; then
    echo "Could not get correct whole_end_y, will take default value."
    readWholeEndY=""
  fi

  # Reading MAX_RESOLUTION
  readMaxResolution=$(                                                                        \
    echo "$noComments" |                                                                      \
    egrep -i "^[[:space:]]*max_resolution[[:space:]]*=[[:space:]]*[0-9]+[[:space:]]*$" "$2" | \
    egrep -o "[0-9]+"                                                                         \
  )
  if [[ ( -z "$readMaxResolution" ) || ( "$readMaxResolution" -lt 1 ) ]]; then
    echo "Could not get correct max_resolution, will take default value."
    readMaxResolution=""
  fi

  # TODO add < check for coordinates

  unset noComments paramName timeCount allParamsString rubbishStringCount
fi


#############
# ALGORITHM #
#############

# Explanation:
# Split whole square
#
#              ____________________
# WHOLE_END_Y -|                  |
#              |                  |
#              |                  |
#              |                  |
# WHOLE_BEG_Y -|__________________|
#               |                |
#          WHOLE_BEG_X       WHOLE_END_X
#
# into X_ZONE_COUNT x Y_ZONE_COUNT parts.
# Every part is downloaded separately.
# Resolution of one part is as high as possible but no more than
# MAX_RESOLUTION.

# Some words about default algorithm params:
# Whole Karjala square has borders:
# (4408485.33955125, 6648645.6859148545) -> (4651309.208426337, 6911112.210849579)
# Do not set max res more than 81 MPx. Server may fail.
# 7x6, 81 MPx is max size when OpenCV does not fail. More is dangerous.
DEF_X_ZONE_COUNT=7
DEF_WHOLE_BEG_X="4408485.33955125"
DEF_WHOLE_END_X="4651309.208426337"
DEF_Y_ZONE_COUNT=6
DEF_WHOLE_BEG_Y="6648645.6859148545"
DEF_WHOLE_END_Y="6911112.210849579"
DEF_MAX_RESOLUTION=81000000

# Algorithm params
if [[ -n "$readXZoneCount" ]]; then
  X_ZONE_COUNT="$readXZoneCount"
else
  X_ZONE_COUNT="$DEF_X_ZONE_COUNT"
fi
if [[ -n "$readWholeBegX" ]]; then
  WHOLE_BEG_X="$readWholeBegX"
else
  WHOLE_BEG_X="$DEF_WHOLE_BEG_X"
fi
if [[ -n "$readWholeEndX" ]]; then
  WHOLE_END_X="$readWholeEndX"
else
  WHOLE_END_X="$DEF_WHOLE_END_X"
fi

if [[ -n "$readYZoneCount" ]]; then
  Y_ZONE_COUNT="$readYZoneCount"
else
  Y_ZONE_COUNT="$DEF_Y_ZONE_COUNT"
fi
if [[ -n "$readWholeBegY" ]]; then
  WHOLE_BEG_Y="$readWholeBegY"
else
  WHOLE_BEG_Y="$DEF_WHOLE_BEG_Y"
fi
if [[ -n "$readWholeEndY" ]]; then
  WHOLE_END_Y="$readWholeEndY"
else
  WHOLE_END_Y="$DEF_WHOLE_END_Y"
fi

if [[ -n "$readMaxResolution" ]]; then
  MAX_RESOLUTION="$readMaxResolution"
else
  MAX_RESOLUTION="$DEF_MAX_RESOLUTION"
fi

###################
# OTHER CONSTANTS #
###################

# Used in bc computations. Number of digits after decimal point.
SCALE=10 

# Used in URL.
FORMAT=jpeg
TILED='true'

#################################
# PRINTING ALGORITHM PARAMETERS #
#################################

echo "I gonna work with the next algorithm parameters:"
echo "(X zone count x Y zone count) = ($X_ZONE_COUNT x $Y_ZONE_COUNT)"
echo "Square: (Xbeg, Ybeg) -> (Xend, Yend) = ($WHOLE_BEG_X, $WHOLE_BEG_Y) -> ($WHOLE_END_X, $WHOLE_END_Y)"
echo "One subsquare resolution: $MAX_RESOLUTION"

#############
# COMPUTING #
#############

# Calculating x coords
xCoords[0]=$WHOLE_BEG_X

for zoneNumber in $(seq $X_ZONE_COUNT)
do
  xCoords[$zoneNumber]=$(
    echo "scale=$SCALE;
          zone_end_coord=($WHOLE_BEG_X + (($WHOLE_END_X - $WHOLE_BEG_X) / $X_ZONE_COUNT) * $zoneNumber);
          print zone_end_coord;" \
    | bc -l
  )
done

# Printing x coords
msg="X coords: "
for coordNumber in 0 $(seq $X_ZONE_COUNT) # 0 1 2 ...
do
  msg="$msg ${xCoords[$coordNumber]}"
done 
echo $msg


# Calculating y coords
yCoords[0]=$WHOLE_BEG_Y

for zoneNumber in $(seq $Y_ZONE_COUNT)
do
  yCoords[$zoneNumber]=$(
    echo "scale=$SCALE;
          zone_end_point=($WHOLE_BEG_Y + (($WHOLE_END_Y - $WHOLE_BEG_Y) / $Y_ZONE_COUNT) * $zoneNumber);
          print zone_end_point;" \
    | bc -l
  )
done

# Printing y coords
msg="Y coords: "
for coordNumber in 0 $(seq $Y_ZONE_COUNT) # 0 1 2 ...
do
  msg="$msg ${yCoords[$coordNumber]}"
done
echo $msg

# Calculating image size
## Part 1. Calculating
space='"  "'
imageSizesString=$(
  echo "
    step_x = (($WHOLE_END_X - $WHOLE_BEG_X) / $X_ZONE_COUNT);
    step_y = (($WHOLE_END_Y - $WHOLE_BEG_Y) / $Y_ZONE_COUNT);
    ratio  = (step_y / step_x);
    width  = sqrt($MAX_RESOLUTION / ratio);
    height = width * ratio;
    print width, $space, height;
  " \
  | bc -l 
)
## Part 2. Separating.
#  imageSizesString is the string containing width, height.
#  Operator () splits string into array of strings.
imageSizesArray=($imageSizesString)
## Part 3. Rounding
imageWidth=$(
echo "scale=0;
      rounded_width = (${imageSizesArray[0]} - 1) / 1;
      print rounded_width;" \
| bc -l
)
imageHeight=$(
echo "scale=0;
      rounded_height = (${imageSizesArray[1]} - 1) / 1;
      print rounded_height;" \
| bc -l
)
echo "One tile has resolution $imageWidth x $imageHeight"

# Downloading images

for zoneYNumber in $(seq $Y_ZONE_COUNT)
do
  for zoneXNumber in $(seq $X_ZONE_COUNT)
  do
    begX=${xCoords[$(expr $zoneXNumber - 1)]}
    endX=${xCoords[$zoneXNumber]}
    begY=${yCoords[$(expr $zoneYNumber - 1)]}
    endY=${yCoords[$zoneYNumber]}
    echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvv NEW SQUARE vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
    msg="Gonna ask square ($zoneXNumber, $zoneYNumber)/($X_ZONE_COUNT, $Y_ZONE_COUNT). "
    msg=$msg$(
      echo "scale=2;
            ((($zoneYNumber - 1 ) * $X_ZONE_COUNT + $zoneXNumber - 1) * 100) / ($X_ZONE_COUNT * $Y_ZONE_COUNT)" \
      | bc -l
    )
    msg="$msg % completed."
    echo $msg
    baseUrl="http://www.karjalankartat.fi/wms/8b42201cc218b9cd6c6ef9321e1d40f0?SRS=EPSG%3A2394&LAYERS=karjalankartat%3Atopo20k_group&STYLES=&FORMAT=image%2F$FORMAT&TILED=$TILED&SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&EXCEPTIONS=application%2Fvnd.ogc.se_inimage&BBOX=$begX,$begY,$endX,$endY&WIDTH=$imageWidth&HEIGHT=$imageHeight"
    separator='_'
    point='.'
    fileName="$1/$zoneXNumber$separator$zoneYNumber$point$FORMAT"
    wget -O $fileName $baseUrl
    echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
  done
done
