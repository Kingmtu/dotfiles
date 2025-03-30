#!/bin/bash

## Files
CONFIG="$HOME/.config/wofi/config"
STYLE="$HOME/.config/wofi/style.css"
COLORS="$HOME/.config/wofi/colors"


DIR=$HOME/Pictures/wallpapers
PICS=($(ls ${DIR}))

RANDOMPICS=${PICS[ $RANDOM % ${#PICS[@]} ]}

if [[ $(pidof swaybg) ]]; then
  pkill swaybg
fi

## Wofi Command
wofi_command="wofi --show dmenu \
			--prompt 'choose..'
			--conf ${CONFIG} --style ${STYLE} --color ${COLORS} \
			--width=300 --height=400 \
			--cache-file=/dev/null \
			--hide-scroll --no-actions \
			--define=matching=fuzzy"

menu(){
printf "1. cityscape\n" 
printf "2. cityscape2\n" 
printf "3. colorful-snow\n" 
printf "4. Hong-Kong\n" 
printf "5. Into-the-night\n"
printf "6. lain\n"
printf "7. lonely-night\n"
printf "8. neon\n"
printf "9. old\n"
printf "10. random"
}

swww query || swww-daemon

main() {
choice=$(menu | ${wofi_command} | cut -d. -f1)
case $choice in
1)
    swww img ${DIR}/cityscape.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
2)
    swww img ${DIR}/cityscape2.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
3)
    swww img ${DIR}/colorful-snow.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
4)
    swww img ${DIR}/hong-kong.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
5)
    swww img ${DIR}/into-the-night.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
6)
    swww img ${DIR}/lain.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
7)
    swww img ${DIR}/lonely-night.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
8)
    swww img ${DIR}/neon.jpg --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
9)
    swww img ${DIR}/old.png --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
10)
    swww img ${DIR}/${RANDOMPICS} --transition-fps 30 --transition-type any --transition-duration 3
    return
    ;;
esac
}

killall -f || main
