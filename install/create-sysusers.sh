#!/usr/bin/env bash
#

set -e

CURDIR="$(realpath "$(dirname "$0")")"

. "${CURDIR}/common.sh"

# getent not available in musl
create_group() {
	local group_name="$1"
	if ! getent group "$group_name" >/dev/null; then
		log "Creating group: $group_name"
		_do groupadd -r "$group_name"
	else
		warn "Group $group_name already exists."
	fi
}

create_user() {
	local default_home_dir="/" default_shell="/usr/sbin/nologin"
	local user_name="$1"
	local id="$2"
	# we ignore the id here
	local gecos="$3"
	local home_dir="$4"
	local shell="$5"
	if [[ -z "$home_dir" ]] || [[ $home_dir == "-" ]]; then
		home_dir="$default_home_dir"
	fi
	if [[ -z "$shell" ]] || [[ $shell == "-" ]]; then
		shell="$default_shell"
	fi

	if ! getent passwd "$user_name" >/dev/null; then
		log "Creating user: $user_name"
		if getent group "$user_name" >/dev/null; then
			local additional_args=(-g $user_name)
		fi
		_do useradd -r -m ${additional_args[@]} -d "$home_dir" ${shell:+-s} "$shell" -c "$gecos" "$user_name"
	else
		warn "User $user_name already exists."
	fi
}

is_user_in_group() {
    local user="$1"
    local group="$2"

    if getent group "$group" | cut -d':' -f4 | grep -qw "$user"; then
        return 0
    else
        return 1
    fi
}

append_group() {
	local user_name="$1"
	local group_name="$2"
	if ! getent group "$group_name" > /dev/null; then
		create_group "$group_name"
	fi
	if is_user_in_group "$user_name" "$group_name"; then
		warn "User $user_name has already got group $group_name."
	else
		_do usermod -aG "$group_name" "$user_name"
	fi
}

CONFIG_FILE="$1"
if [ ! -f "$CONFIG_FILE" ]; then
	echo "Configuration file $CONFIG_FILE not found!"
	exit 1
fi

read_line() {
	local chars in_qm in_back_slash char
	while IFS= read -r char; do
		case "$char" in
			\ )
				if [[ $in_back_slash != 0 ]] || \
					[[ $in_qm != "" ]]; then
					chars+=" "
				else
					echo "$chars"
					chars=""
				fi
				in_back_slash=0
				;;
			\\)
				if [[ $in_back_slash != 0 ]]; then
					chars+="\\"
					in_back_slash=0
				else
					in_back_slash=1
				fi
				;;
			\")
				if [[ $in_back_slash != 0 ]] || \
					[[ $in_qm == "'" ]]; then
					chars+='"'
				elif [[ $in_qm == '"' ]]; then
					in_qm=""
				else
					in_qm='"'
				fi
				in_back_slash=0
				;;
			\')
				if [[ $in_back_slash != 0 ]] || \
					[[ $in_qm == '"' ]]; then
					chars+="'"
				elif [[ $in_qm == "'" ]]; then
					in_qm=""
				else
					in_qm="'"
				fi
				in_back_slash=0
				;;
			*)
				chars+="$char"
				in_back_slash=0
				;;
		esac
	done < <(echo "$*" | grep -o .)
	if [[ $chars != "" ]]; then
		echo "$chars"
	fi
}

main() {
	while read -r line; do
		[[ "$line" =~ ^#.*$ ]] && continue
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue
		
		unset typ name id gecos home_dir shell
		local typ name id gecos home_dir shell
		while read -r _line; do
			[[ -n $typ ]] || { typ="$_line"; continue; }
			[[ -n $name ]] || { name="$_line"; continue; }
			[[ -n $id ]] || { id="$_line"; continue; }
			[[ -n $gecos ]] || { gecos="$_line"; continue; }
			[[ -n $home_dir ]] || { home_dir="$_line"; continue; }
			[[ -n $shell ]] || { shell="$_line"; continue; }
		done < <(read_line "$line")

		case "$typ" in
			u)
				create_user "$name" "$id" "$gecos" "$home_dir" "$shell"
				;;
			g)
				create_group "$name"
				;;
			m)
				append_group "$name" "$id"
				;;
			*)
				die "Unknown type: $typ"
				;;
		esac
	done < "$CONFIG_FILE"
}
main
