
_do() {
	echo ">>>" "$@" >&2
	"$@"
}
log() {
	echo "  [LOG]" "$@"
}
warn() {
	local prefix=" [WARN]"
	if [[ ${FUNCNAME[1]} == die ]]; then
		prefix="[ERROR]"
	fi
	echo "$prefix" "$@" >&2
}
die() {
	local ret=1
	if [[ $1 =~ ^[[:digit:]]{1,3}$ ]] && (( $1 <= 255 )); then
		ret="$1"
		shift
	fi
	if [[ -z $1 ]]; then
		set -- "something error"
	fi
	warn "$@"
	exit "$ret"
}
