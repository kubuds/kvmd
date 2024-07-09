#!/usr/bin/env bash
#

set -e

CURDIR="$(realpath "$(dirname "$0")")"
REPODIR="$(realpath "${CURDIR}/..")"

. "${CURDIR}/common.sh"

CONFIGURATIONS=(
	/etc/kvmd/{main,override,logging,auth,meta}.yaml
	/etc/kvmd/{ht,ipmi,vnc}passwd
	/etc/kvmd/totp.secret
	/etc/kvmd/nginx/{kvmd.ctx-{http,server},certbot.ctx-server}.conf
	/etc/kvmd/nginx/loc-{login,nocache,proxy,websocket,nobuffering,bigpost}.conf
	/etc/kvmd/nginx/{mime-types,ssl}.conf
	/etc/kvmd/nginx/nginx.conf.mako
	/etc/kvmd/janus/janus{,.plugin.ustreamer,.transport.websockets}.jcfg
	/etc/kvmd/web.css
	/etc/sysctl.d/99-kvmd.conf
	/etc/udev/rules.d/99-kvmd.rules
) 

pkg_install() {
	_do cd "$REPODIR" || die
	_do pip install --no-deps .
	_do pip install pyotp

	_do install -Dm755 -t "/usr/bin" scripts/kvmd-{bootconfig,gencert,certbot}

	_do install -Dm644 configs/os/tmpfiles.conf "/usr/lib/tmpfiles.d/kvmd.conf"

	_do mkdir -p "/usr/share/kvmd"
	_do cp -r {hid,web,extras,contrib/keymaps} "/usr/share/kvmd"
	_do find "/usr/share/kvmd/web" -name '*.pug' -exec rm -f '{}' \;

	local _cfg_default="/usr/share/kvmd/configs.default"
	_do mkdir -p "$_cfg_default"
	_do cp -r configs/* "$_cfg_default"

	_do find "$_cfg_default" -type f -exec chmod 444 '{}' \;
	_do chmod 400 "$_cfg_default/kvmd"/*passwd
	_do chmod 400 "$_cfg_default/kvmd"/*.secret
	_do chmod 750 "$_cfg_default/os/sudoers"
	_do chmod 400 "$_cfg_default/os/sudoers"/*

	_do mkdir -p "/etc/kvmd/"{nginx,vnc}"/ssl"
	_do chmod 755 "/etc/kvmd/"{nginx,vnc}"/ssl"
	_do install -Dm444 -t "/etc/kvmd/nginx" "$_cfg_default/nginx"/*.conf*
	_do chmod 644 "/etc/kvmd/nginx/"{nginx,ssl}.conf*

	_do mkdir -p "/etc/kvmd/janus"
	_do chmod 755 "/etc/kvmd/janus"
	_do install -Dm444 -t "/etc/kvmd/janus" "$_cfg_default/janus"/*.jcfg

	_do install -Dm644 -t "/etc/kvmd" "$_cfg_default/kvmd"/*.yaml
	_do install -Dm600 -t "/etc/kvmd" "$_cfg_default/kvmd"/*passwd
	_do install -Dm600 -t "/etc/kvmd" "$_cfg_default/kvmd"/*.secret
	_do install -Dm644 -t "/etc/kvmd" "$_cfg_default/kvmd"/web.css
	_do mkdir -p "/etc/kvmd/override.d"

	_do mkdir -p "/var/lib/kvmd/"{msd,pst}

	_do install -Dm755 -t "/usr/bin" scripts/kvmd-udev-restart-pass

	_do install -Dm644 configs/os/sysctl.conf "/etc/sysctl.d/99-kvmd.conf"
	_do install -Dm644 configs/os/udev/common.rules "/usr/lib/udev/rules.d/99-kvmd-common.rules"
	# TODO: HID udev rules

	# TODO: main.yaml rules
	#_do install -Dm444 TODO "/etc/kvmd/main.yaml"
	_do install -Dm755 -t "/usr/bin" testenv/fakes/vcgencmd #TODO
	_do cat testenv/fakes/etc/fstab >>"/etc/fstab" #TODO
}

post_install() {
	log "==> Ensuring KVMD users and groups ..."
	"${CURDIR}/create-sysusers.sh" "${REPODIR%%/}"/configs/os/sysusers.conf

	_do chown kvmd:kvmd /etc/kvmd/htpasswd
	_do chown kvmd:kvmd /etc/kvmd/totp.secret
	_do chown kvmd-ipmi:kvmd-ipmi /etc/kvmd/ipmipasswd
	_do chown kvmd-vnc:kvmd-vnc /etc/kvmd/vncpasswd
	_do chmod 600 /etc/kvmd/*passwd
	for target in nginx.conf.mako ssl.conf; do
		_do chmod 644 "/etc/kvmd/nginx/$target"
	done

	_do chown kvmd /var/lib/kvmd/msd 2>/dev/null
	_do chown kvmd-pst /var/lib/kvmd/pst 2>/dev/null

	if [ ! -e /etc/kvmd/nginx/ssl/server.crt ]; then
		log "==> Generating KVMD-Nginx certificate ..."
		_do kvmd-gencert --do-the-thing
	fi

	if [ ! -e /etc/kvmd/vnc/ssl/server.crt ]; then
		log "==> Generating KVMD-VNC certificate ..."
		_do kvmd-gencert --do-the-thing --vnc
	fi

	for target in nginx vnc; do
		_do chown root:root /etc/kvmd/$target/ssl
		owner="root:kvmd-$target"
		path="/etc/kvmd/$target/ssl/server.key"
		if [ ! -L "$path" ]; then
			_do chown "$owner" "$path"
			_do chmod 440 "$path"
		fi
		path="/etc/kvmd/$target/ssl/server.crt"
		if [ ! -L "$path" ]; then
			_do chown "$owner" "$path"
			_do chmod 444 "$path"
		fi
	done

	_do cd ~
	_do mkdir -p /tmp/nginx
	_do mkdir -p /run/kvmd
	_do python -m kvmd.apps.ngxmkconf /etc/kvmd/nginx/nginx.conf.mako /etc/kvmd/nginx/nginx.conf
}

pkg_install
post_install

# for nginx
# nginx -c /etc/kvmd/nginx/nginx.conf -g 'user www-data; error_log stderr;'
#
# for kvmd app
# python -m kvmd.apps.kvmd --run
#
