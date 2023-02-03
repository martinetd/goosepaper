#!/bin/sh

error() {
	printf "%s\n" "$@" >&2
	exit 1
}

while [ $# -ge 1 ]; do
	case "$1" in
	-c) CONF=1;;
	-*) error "Unknown option $1";;
	*) break;;
	esac
	shift
done
[ $# -ge 1 ] || error "need arg = urls"

conf=$(mktemp /tmp/goosepaper.XXXXXXX.conf)
pdf="${conf%.conf}.pdf"
trap "rm -f '$conf' '$pdf'" EXIT

{
	printf "%s\n" "{" \
		'    "font_size": 12,' \
		'    "stories": ['
	while [ $# -ge 1 ]; do
		cat <<EOF
        {
            "provider": "url",
            "config": {
                "url": "$1"
            }
        }
EOF
		[ $# -gt 1 ] && printf "        ,\n"
		shift
	done
	printf "%s\n" "    ]" "}"
} > "$conf"

if [ -n "$CONF" ]; then
	cat "$conf"
	exit 0
fi

set -- env PYTHONPATH="$(dirname "$0")" python3 -m goosepaper -c "$conf" -o "$pdf"
case "$DIRENV_FILE" in
*/goosepaper/.envrc) ;;
*) set -- nix develop --quiet --quiet '/etc/nixos#goosepaper' -c "$@";;
esac

title=$("$@") || exit
mv "$pdf" "$title.pdf"
RMAPI_HOST=https://local.appspot.com rmapi put "$title.pdf" "/print/"
# rm -f "$title.pdf"
