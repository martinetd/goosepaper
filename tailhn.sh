#!/bin/sh

# get last checked day, restart from it (inclusive), remember current last date and range for all days (ugh)
hntop="$HOME/irclogs/libera/##hntop"
today=$(date +%y-%m-%d)
ndays=1
NOFILT=""

error() {
	printf "%s\n" "$@" >&2
	exit 1
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	-n)
		NOFILT=1
		;;
	*)
		error "unknown option $1"
		;;
	esac
	shift
done

cd "$(dirname "$(realpath "$0")")" || error "cd $0 dir"

[ -e .tailhn.firstday ] && day=$(cat .tailhn.firstday)
[ -n "$day" ] || day="$today"
[ -e .tailhn.seen ] || touch .tailhn.seen
if [ $(stat -c %s .tailhn.seen) -gt 102400 ]; then
	tail -c 10240 .tailhn.seen | tail -n +2 > .tailhn.seen.tmp
	mv .tailhn.seen.tmp .tailhn.seen
fi
filter() {
	grep -q -xF "$num" .tailhn.seen && return 1
	# real link comes before hn link, so hn link is never printed
	# when there's a real link -- I guess it's ok?
	#[ "${link#*news.ycombinator.com/item?id=}" = "$link" ] || echo "$num" >> .tailhn.seen
	echo "$num" >> .tailhn.seen
}
[ -n "$NOFILT" ] && filter() { :; }

while cat "$hntop.$day.log" && [ "$day" != "$today" ]; do
	day="$(date -d "$day + 1 day" +%y-%m-%d)"
	# limit at 100 days, just in casee...
	ndays=$((ndays + 1))
	[ "$ndays" -ge 100 ] && break
done | \
	sed -ne 's@.*egobot> \(.*\) \[[0-9]* [^ ]*\] \(http.\?://.*\) \(http.\?://.*id=\([0-9]*\)\)@\4 \2 \1\n\4 \3 \1@p' \
	     -e 's@.*egobot> \(.*\) \[[0-9]* [^ ]*\] \(http.\?://.*?id=\([0-9]*\)\)@\3 \2 \1@p' | \
	while read num link description; do
		filter || continue
		# check num for dup somehow...
		echo "$description $link"
	done | \
	fzf --no-mouse -m --tac | sed -ne 's@.* \(http.\?://\)@\1@p' | \
	tee -a .tailhn.log | \
	xargs -r ./goosepaper.sh


echo "$today" > .tailhn.firstday
