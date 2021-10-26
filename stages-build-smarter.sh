#!/usr/bin/env bash

# Theoretically all that it does could be
# exec env -i unshare -nrR arena \
#	/seed/1/bin/tcc -nostdinc -nostdlib -run /seed/1/src/stage1.c
# e.g., just running stage1.c inside arena with env unset, no net and E[UG]ID=0.
#
# But during debugging it's useful to re-run just parts of that,
# so, here's a smarter version.

set -ue
shopt -s globstar

[[ -t 1 ]] && COLOR_DIM='\e[2m' || COLOR_DIM=
[[ -t 1 ]] && COLOR_RESET='\e[0m' || COLOR_RESET=

cut_log_up_to_stage() {
	if [[ -e log ]]; then
		:> log.tmp
		echo -ne "Previous log:\n$COLOR_DIM"
		while read -r line; do
			echo "$line"
			echo "$line" >> log.tmp
			[[ "$line" =~ ---.stage.$1.cutoff.point.*--- ]] && break
		done < log
		echo -ne "$COLOR_RESET"
		mv log.tmp log
	fi
}

STAGE_1_NEEDS_REBUILD=false
STAGE_1_SOME_INPUTS=(
	"hello.c"
	"protobusybox.c"
	"stage1.c"
	"syscall.h"
	"tcc-seed"
)
STAGE_1_OUTPUTS=(
	"arena/stage/1/lib/protomusl.a"
	"arena/stage/1/bin/protomusl-hello"
	"arena/stage/1/bin/protobusybox"
	"arena/stage/1/bin/sash"
	"arena/stage/1/bin/ash"
	"arena/stage/1/bin/cp"
	"arena/stage/1/bin/ln"
	"arena/stage/1/bin/mkdir"
	"arena/stage/1/bin/mv"
)
STAGE_1_FINAL_OUTPUT="arena/stage/1/bin/protobusybox"
for s1out in "${STAGE_1_OUTPUTS[@]}"; do
	[[ -e $s1out ]] || STAGE_1_NEEDS_REBUILD=true
done
for f in arena/seed/1/** ${STAGE_1_SOME_INPUTS[@]}; do
	[[ $STAGE_1_FINAL_OUTPUT -nt $f ]] || STAGE_1_NEEDS_REBUILD=true
done

if $STAGE_1_NEEDS_REBUILD; then
	cp tcc-seed arena/seed/1/bin/
	cp stage1.c hello.c protobusybox.c syscall.h arena/seed/1/src/
	cp stage2.sh arena/seed/2/src/
	env -i unshare -nrR arena \
		/seed/1/bin/tcc -nostdinc -nostdlib -run /seed/1/src/stage1.c \
			2>&1 | tee log
	EX=${PIPESTATUS[0]}; echo "--- stage 1+ exit code $EX ---"; exit $EX
else
	cp stage2.sh arena/seed/2/src/
	cut_log_up_to_stage 1
	env -i unshare -nrR arena /seed/2/src/stage2.sh 2>&1 | tee -a log
	EX=${PIPESTATUS[0]}; echo "--- stage 2+ exit code $EX ---"; exit $EX
fi