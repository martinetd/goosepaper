#!/bin/sh

error() {
	printf "%s\n" "$@" >&2
	exit 1
}

UPLOAD=1
CONF=

while [ $# -ge 1 ]; do
	case "$1" in
	-c) CONF=1;;
	-d) UPLOAD="";;
	--clean)
		rmapi ls print | awk '$1 == "[f]" { print "/print/"$2 }' | xargs -r rmapi rm
		exit
		;;
	-*) error "Unknown option $1";;
	*) break;;
	esac
	shift
done
[ $# -ge 1 ] || error "need arg = urls"

conf=$(mktemp /tmp/goosepaper.XXXXXXX.conf)
pdf="${conf%.conf}.pdf"
trap "rm -f '$conf' '$pdf'" EXIT


for url; do
	case "$url" in
	*.pdf)
		curl -o "$pdf" "$url" || continue
		title=$(pdftotext -layout "$pdf" /dev/stdout | head -n 1 | sed -e 's/^ \+| \+$//g')
		[ -z "$title" ] && title="${url##*/}" && title="${title%.pdf}"
		title=$(printf "%s" "$title" | sed -e 's/[^a-zA-Z0-9]\+/_/g')
		;;
	*)
		cat > "$conf" <<EOF
{
    "font_size": 12,
    "stories": [
        {
            "provider": "url",
            "config": {
                "url": "$url"
            }
        }
    ]
}
EOF

		if [ -n "$CONF" ]; then
			cat "$conf"
			continue
		fi

		# We can apparently overwite $@ in the middle of the for loop safely...
		set -- env PYTHONPATH="$(dirname "$0")" python3 -m goosepaper -c "$conf" -o "$pdf"
		case "$DIRENV_FILE" in
		*/goosepaper/.envrc) ;;
		*) set -- nix develop --option warn-dirty false '/etc/nixos#goosepaper' -c "$@";;
		esac
		# XXX doesn't work well from different path?
		cd "$(dirname "$0")" || exit 1
		if ! title=$("$@"); then
			# should always include url in error messages...
			[ "${title#*$url}" != "$title" ] || title="$url failed: $title"
			echo "$title" >&2
			continue
		fi
		;;
	esac

	mv "$pdf" "/tmp/$title.pdf"

	words=$(pdftotext "/tmp/$title.pdf" /dev/stdout | wc -w)
	if [ "$words" -lt 40 ]; then
		echo "$url : Less than 30 words, refusing to print" >&2
		continue
	fi

	if [ -n "$UPLOAD" ]; then
		RMAPI_HOST=https://local.appspot.com rmapi put "/tmp/$title.pdf" "/print/"
	else
		echo "fake uploading $title.pdf"
	fi
	rm -f "/tmp/$title.pdf"
done
