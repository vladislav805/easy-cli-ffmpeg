#!/bin/bash

# Vladislav Veluga <vlad@velu.ga>

# Util
VERSION="0.0.1"

for i in "$@"
do
    case $i in
        --version|-v)
            echo "easy-cli-ffmpeg v${VERSION}"
            exit
            ;;

        --verbose)
            TEST=1
            shift
    esac
done

# Input arguments
INPUT_FILENAME=$1
OUTPUT_FILENAME=$2

#
# Colorize text
#
_TR="\033[0m"       # Text Reset
_TDR="\033[0;31m"   # Text Default Red
_TDG="\033[0;32m"   # Text Default Green
_TDC="\033[0;36m"   # Text Default Cyan
_TBR="\033[1;31m"   # Text Bold Red
_TBG="\033[1;32m"   # Text Bold Green
_TUW="\033[4;37m"   # Text Underline White

_BY="\033[43m"      # Background Yellow
_BB="\033[44m"      # Background Blue
_BW="\033[47m"      # Background White

#
# Log debug
#
function logd {
    if [ ! -z "$TEST" ]; then
        printf "● ${_TUW}$1${_TR}\n"
    fi
}

#
# Log info
#
function logi {
    printf "${_TDC}● $1${_TR}\n"
}

#
# Log error
#
function loge {
    printf "${_TBR}✖ $1${_TR}\n"
}

#
# Draw progressbar
# Example:
#   display_progress 40 75
# Will write "53%" and draw a progress bar
#
function display_progress {
    percent=$(echo "$1 $2" | awk "{print $1/$2*100}" | cut -d "." -f1)

    line_length=$((percent / 2))
    line=$(printf "%${line_length}s${_BW}" | tr " " "#")

    printf " ${_TDG}%3d%%${_TR} ${_BB}%-55s${_TR}\r" "$percent" "$line"
}

#
# Ask answer from user
# Example:
#   input "Enter number"
#
function input {
    local input=""

    while [ -z "$input" ]
    do
        read -p "$1: " input
        input=$(echo "$input" | xargs)
    done

    echo "$input"
}

#
# Ask user only yes/no
#
function confirm {
    local ans=""
    while [ -z "$ans" ]
    do
        ans=$(input "$1 [y/n]")
        if [[ "$ans" -ne "y" && "$ans" -ne "n" ]] ; then
            loge "Type \"y\" or \"n\""
            ans=""
        fi
    done
    echo "$ans"
}

#
# Fetch count of frames from video file
#
function get_total_frames {
    if [ "$#" -ne 1 ]; then
        echo "Illegal number of parameters"
        return 1
    fi
    info=$(ffprobe "$1" 2>&1)
    fps=$(echo "$info" | sed -n "s/.*, \(.*\) tbr.*/\1/p")
    duration=$(echo "$info" | sed -n "s/.* Duration: \([^,]*\), .*/\1/p")
    hours=$(echo $duration | cut -d":" -f1)
    minutes=$(echo $duration | cut -d":" -f2)
    seconds=$(echo $duration | cut -d":" -f3)
    frames=$(echo "($hours*3600+$minutes*60+$seconds)*$fps" | bc | cut -d"." -f1)
    echo "$frames"
    return 0
}

#
# Starting ffmpeg
#
function start_ffmpeg {
    # Get count of frames in file
    frames=$(get_total_frames "$INPUT_FILENAME")

    COMMAND="-i $INPUT_FILENAME $COMMAND $OUTPUT_FILENAME"

    # TODO: remove "-y"

    echo "$COMMAND"

    # Start ffmpeg
    nice -n 15 ffmpeg -hide_banner -y -progress /tmp/ffstats $COMMAND 2>/dev/null &

    # Get pid of ffmpeg process
    PID=$! &&

    # While ffmpeg is running
    while [ -e /proc/$PID ];
    do
        sleep 0.5

        # Get current frame
        frame=$(tail -n 12 /tmp/ffstats | awk 'BEGIN{FS="\n"; RS=""} {print $1}' | awk 'BEGIN{FS="="; RS=""} {print $2}')

        if [ -z "$frame" ]; then
            frame="0"
        fi

        # Draw progressbar
        display_progress "$frame" "$frames"
    done

    display_progress 1 1
    printf "\n${_TBG}Successfully saved in ${OUTPUT_FILENAME}${_TR}\n"
}

#
# Help
#
function show_help {
    logi "${_TBR}Help${_TR}
\t${_TBG}help${_TR}\tShow this help
\t${_TBG}ok|start${_TR}\tStop set actions and start ffmpeg
\t${_TBG}cancel${_TR}\tDiscard all actions and exit
\t${_TBG}trim${_TR}\tTrim video/audio by start and end timeline
\t${_TBG}no_audio${_TR}\tDisable audio in video
\t${_TBG}dl_hls${_TR}\tDownload HLS file into video file\n"
}

#
# Confirm exit dialog
#
function confirm_exit {
    local ex=$(confirm "Are you sure?")
    if [ "$ex" = "y" ]; then
        exit
    fi
}

#
# Resize logic dialog
#
function resize_dialog {
    local w=""
    local h=""

    w=$(input "New width (or -1, if need aspect ratio by height)")

    h=$(input "New height (or -1, if need aspect ration by width)")

    if [ $w -lt 0 -a $h -lt 0 ] ; then
        loge "Error! Width AND height cannot be less than zero at the same time. Abort."
        return 1
    fi

    # TODO: check for -2 (failed when, ex, 127 and -1)

    logi "Dimensions successfully marked"
    COMMAND="$COMMAND -vf scale=$w:$h"
}




######################
#                    #
#    Start script    #
#                    #
######################

logd "Enabled test mode"

# String for store arguments
COMMAND="-hide_banner"

# If not specified input file, request it
if [ -z "$INPUT_FILENAME" ]; then
    INPUT_FILENAME=$(input 'Enter input filename')
fi

# If not specified output file, request it
if [ -z "$OUTPUT_FILENAME" ]; then
    OUTPUT_FILENAME=$(input 'Enter output filename')
fi

# For current action from user
action=""

logi "Action (for list of all commands type \"${_TDG}help${_TR}${_TDC}\"):"
printf ">: "
read action

while [ ! -z "$action" ]
do
    case "$action" in
        trim)
            loge "Not impemented yet"
            ;;

        resize)
            resize_dialog
            ;;

        rotate)
            loge "Not implemented yet"
            ;;

        vcodec)
            cn=$(input "Codec name (\"-\" for discard)")
            if [ "$cn" != "-" ]; then
                COMMAND="$COMMAND -vcodec $codec_name"
            fi
            ;;

        acodec)
            cn=$(input "Codec name (\"-\" for discard)")
            if [ "$cn" != "-" ]; then
                COMMAND="$COMMAND -acodec $codec_name"
            fi
            ;;

        no_audio)
            logi "Audio disabled"
            COMMAND="$COMMAND -an"
            ;;

        dl_hls)
            logi "HLS enabled"
            COMMAND="$COMMAND -bsf:a aac_adtstoasc"
            ;;

        # Need help
        help)
            show_help
            ;;

        # End of actions
        ok|start)
            logi "Starting..."
            start_ffmpeg
            break
            ;;
        
        # Exit from util
        cancel)
            confirm_exit
            ;;

        *)
            loge "Unknown action $action"
            ;;
    esac

    logd "Current command = $COMMAND"

    printf ">: "
    read action
done
