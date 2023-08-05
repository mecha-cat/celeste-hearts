#!/bin/sh

while [ "$#" -gt 0 ]; do
    case $1 in
        --tgstickers)
			if [ -z "$squareSize" ]; then
            	squareSize=512
				echo "Converting to Telegram Sticker size as set by CLI flags"
			fi
            ;;
		--tgemojis)
			if [ -z "$squareSize" ]; then
				squareSize=100
				echo "Converting to Telegram Emoji size as set by CLI flags"
			fi
			;;
    esac
    shift
done

if [ -z "$squareSize" ]; then
	echo "Converting to Telegram Emoji size by default. Change this by invoking the script with '--tgstickers' flag."
	squareSize=100
fi

# Change dir to the root of the Celeste Hearts repository
a="/$0"; a=${a%/*}; a=${a#/}; a=${a:-.}; BASEDIR=$(cd "$a"; pwd -P)
cd "$BASEDIR"

# Check access to directories, list all files, build hearts accordingly
if ls -A1q . | grep -q .; then
	for file in **/*.gif; do
		fileWebm="converted/${file%.gif}.webm"
		echo "Converting $file $fileWebm"
		mkdir -p "${fileWebm%/*}" >/dev/null 2>&1
		ffmpeg -nostdin -y -i "${file}" -vf "scale=w=${squareSize}:h=${squareSize}:force_original_aspect_ratio=decrease,pad=${squareSize}:${squareSize}:-1:-1:0xFFFFFF00" -sws_flags neighbor -c:v libvpx-vp9 -lossless 1 -pix_fmt yuva420p -r 12.50 "${fileWebm}" >/dev/null 2>&1
	done
else
	echo "Directory is empty or not readable."
	exit 1
fi