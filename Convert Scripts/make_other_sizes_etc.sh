#!/bin/bash
a="/$0"; a=${a%/*}; a=${a#/}; a=${a:-.}; BASEDIR=$(cd "$a" || exit 1; pwd -P)
POOL_PIDS=""

if ! which ffmpeg &>/dev/null; then
	echo "Install ffmpeg first"
	exit 1
fi

worker() {
	while [ ! -e "$BASEDIR/convert.fifo" ]; do
		sleep 1
	done

	touch "$BASEDIR/convert.lock"
	exec 3<"$BASEDIR/convert.fifo"
	exec 4<"$BASEDIR/convert.lock"

	ntcounter=1

	while :; do
		flock 4
		IFS= read -r -u 3 task
		flock -u 4
		if [ -z "$task" ]; then
			ntcounter=$((ntcounter + 1))
			[ "$ntcounter" -eq "3" ] && break
			sleep 1
			continue
		fi
		if [ "$task" = "break" ]; then
			break
		fi
		eval "$task"
	done
}

run_pool(){
  mkfifo "$BASEDIR/convert.fifo"

  for _ in $(seq "$jobs"); do
    worker &
	POOL_PIDS="${POOL_PIDS} $!"
  done
}

stop_pool(){
	for _ in $POOL_PIDS; do
		echo "break" > "$BASEDIR/convert.fifo"
	done
	wait

	rm -f "$BASEDIR/convert.lock" "$BASEDIR/convert.fifo"
}

run_task() {
	line="$(printf " %q" "$@")"
	echo "$line" > "$BASEDIR/convert.fifo"
}

while [ "$#" -gt 0 ]; do
    case $1 in
		--path)
			path=$2
			shift
			;;
		--jobs)
			jobs=$2
			shift
			;;
    esac
    shift
done

if [ -z "$jobs" ]; then
	jobs=$(nproc --all)
fi

if [ -z "$path" ]; then
	path="other_sizes"
fi

# Change dir to the root of the Celeste Hearts repository
cd "$BASEDIR" || exit 1

declare -A exts
exts[png]="-frames:v 1 -update true -vf \"scale=w=-1:h={size}:force_original_aspect_ratio=decrease:flags=neighbor\""
#exts[gif]="-filter_complex \"[0:v] scale=w=-1:h={size}:force_original_aspect_ratio=decrease:flags=neighbor,split [a][b]; [a] palettegen [p]; [b][p] paletteuse\" -r 12.50"
#exts[webm]="-vf \"scale=w=-1:h={size}:force_original_aspect_ratio=decrease:flags=neighbor\" -c:v libvpx-vp9 -lossless 1 -pix_fmt yuva420p -r 12.50"
sizes=("1000")

echo "Spawing ${jobs} jobs"
run_pool

shopt -s globstar nullglob extglob

# Check access to directories, list all files, build hearts accordingly
if ls -A1q .. | grep -q .; then
	for file in ../!(${path})/**/*.gif; do
		for size in "${sizes[@]}"; do
			for ext in "${!exts[@]}"; do
				arg="${exts["$ext"]}"
				fileWithoutDots=${file#../}
				fileConverted="${path}/${fileWithoutDots%.gif}_$size.$ext"
				mkdir -p "${fileConverted%/*}" >/dev/null 2>&1
				run_task sh -c "echo Converting \"$file\" \"$fileConverted\" && ffmpeg -hide_banner -loglevel warning -nostdin -y -i \"${file}\" ${arg//"{size}"/"${size}"} \"${fileConverted}\""
			done
		done
	done
	stop_pool
else
	echo "Directory is empty or not readable."
	stop_pool
	exit 1
fi
