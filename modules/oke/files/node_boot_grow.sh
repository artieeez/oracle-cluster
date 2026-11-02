#!/bin/bash
# OKE worker node: grow the root filesystem so it fills the boot volume.
#
# Delivered to nodes as node_metadata.user_data (base64-encoded cloud-init, see
# modules/oke/main.tf). A custom user_data *replaces* the OKE node image's
# default user data, so this script must run the OKE initialization script
# itself before it exits - otherwise the node never joins the cluster.
#
# Root cause this works around (ADR 002): the OKE node image ships an LVM layout
# sized for the image, not for node_source_details.boot_volume_size_in_gbs. With
# a 75 GiB boot volume the layout is sda1 (/boot/efi) + sda2 (/boot) + sda3
# (LVM PV, ~45.5 GiB) with VG "ocivolume" holding LV "root" (/) and LV "oled"
# (/var/oled). The ~28 GiB that the larger boot volume adds stay unallocated,
# so "/" keeps filling up and kubelet evicts pods once imagefs.available drops
# below its 15% threshold.
#
# Guarantees:
#   - Idempotent: an already-correct disk, a re-run, and a partially grown disk
#     (partition grown but LV not extended) all converge to "root fills the boot
#     volume".
#   - Narrow: only the LV mounted on "/" is extended (never "oled"), and only
#     the disk that also carries /boot is touched (never the sdb data volume
#     that backs the NFS server through the OCI block volume CSI driver).
#   - Fail soft: a growth failure is logged and the boot continues. kubelet and
#     workloads are never restarted, signalled, or blocked.
#   - Bounded: every step runs under a timeout, so a wedged command cannot stall
#     the node join indefinitely.
#   - Race free: growth completes before the OKE init script starts kubelet, so
#     kubelet accounts for the final filesystem size from its first sample.

set -u

readonly TAG="oke-boot-grow"
readonly STEP_TIMEOUT=120
readonly OKE_INIT_URL="http://169.254.169.254/opc/v2/instance/metadata/oke_init_script"
readonly OKE_INIT_FALLBACK="/var/run/oke-init.sh"

log() {
	printf '%s [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TAG" "$*"
}

warn() {
	printf '%s [%s] WARN: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TAG" "$*" >&2
}

# Run a command under a hard timeout so a wedged step cannot stall the boot.
run_with_timeout() {
	if command -v timeout >/dev/null 2>&1; then
		timeout "${STEP_TIMEOUT}" "$@"
	else
		"$@"
	fi
}

# Run one step with a hard timeout, logging what is attempted.
run_step() {
	local description="$1"
	shift

	log "running: ${description}"
	if run_with_timeout "$@"; then
		return 0
	fi
	warn "step failed: ${description}"
	return 1
}

# growpart reports an already full partition as NOCHANGE and exits non-zero, so
# its output - not only its exit status - decides whether the step succeeded.
grow_partition() {
	local disk="$1"
	local partnum="$2"
	local output status

	log "running: growpart ${disk} ${partnum}"
	output=$(run_with_timeout growpart "${disk}" "${partnum}" 2>&1)
	status=$?
	log "growpart: ${output:-no output}"

	case "${output}" in
	*NOCHANGE* | *CHANGED* | *CHANGE*)
		return 0
		;;
	esac

	if [ "${status}" -eq 0 ]; then
		return 0
	fi

	warn "growpart failed with exit status ${status}"
	return 1
}

# Resolve the single physical volume that backs the logical volume mounted on /.
resolve_root_layout() {
	local mountpoint="$1"

	ROOT_SOURCE=$(findmnt -n -o SOURCE "${mountpoint}" 2>/dev/null) || return 1
	ROOT_FSTYPE=$(findmnt -n -o FSTYPE "${mountpoint}" 2>/dev/null) || return 1
	[ -n "${ROOT_SOURCE}" ] || return 1

	ROOT_VG=$(lvs --noheadings -o vg_name "${ROOT_SOURCE}" 2>/dev/null | tr -d '[:space:]')
	ROOT_LV=$(lvs --noheadings -o lv_name "${ROOT_SOURCE}" 2>/dev/null | tr -d '[:space:]')
	[ -n "${ROOT_VG}" ] && [ -n "${ROOT_LV}" ] || return 1

	# Exactly one PV: with more (or none) the mapping to a single boot disk
	# partition is ambiguous, and guessing here could resize the wrong disk.
	local pv_count
	pv_count=$(pvs --noheadings -o pv_name,vg_name 2>/dev/null |
		awk -v vg="${ROOT_VG}" '$2 == vg { print $1 }' | grep -c .)
	[ "${pv_count}" = "1" ] || return 1

	ROOT_PV=$(pvs --noheadings -o pv_name,vg_name 2>/dev/null |
		awk -v vg="${ROOT_VG}" '$2 == vg { print $1 }')
	[ -n "${ROOT_PV}" ] || return 1

	# The PV must be a partition of a whole disk, never a whole disk: resizing a
	# whole-disk PV would destroy the partition table.
	ROOT_DISK_NAME=$(lsblk -no PKNAME "${ROOT_PV}" 2>/dev/null | head -n 1 | tr -d '[:space:]')
	[ -n "${ROOT_DISK_NAME}" ] || return 1
	ROOT_DISK="/dev/${ROOT_DISK_NAME}"

	ROOT_PARTNUM=""
	if [ -r "/sys/class/block/${ROOT_PV##*/}/partition" ]; then
		ROOT_PARTNUM=$(tr -d '[:space:]' <"/sys/class/block/${ROOT_PV##*/}/partition")
	fi
	if [ -z "${ROOT_PARTNUM}" ]; then
		# Fall back to the device name suffix (sda3 -> 3) without sysfs.
		ROOT_PARTNUM="${ROOT_PV##*[!0-9]}"
	fi
	if [ -z "${ROOT_PARTNUM}" ] || [ "${ROOT_PARTNUM}" = "${ROOT_PV}" ]; then
		return 1
	fi

	return 0
}

# Guard: only ever operate on the disk that also carries /boot. The NFS data
# volume (sdb, no partition table, no /boot) can therefore never be touched.
is_boot_disk() {
	local candidate="$1"
	local mountpoint boot_source boot_disk=""

	for mountpoint in /boot /boot/efi; do
		boot_source=$(findmnt -n -o SOURCE "${mountpoint}" 2>/dev/null) || continue
		[ -n "${boot_source}" ] || continue
		boot_disk=$(lsblk -no PKNAME "${boot_source}" 2>/dev/null | head -n 1 | tr -d '[:space:]')
		[ -n "${boot_disk}" ] && break
	done

	[ -n "${boot_disk}" ] || return 1
	[ "${boot_disk}" = "${candidate}" ]
}

grow_root_filesystem() {
	local free_extents

	for tool in findmnt lsblk pvs vgs lvs growpart pvresize lvextend; do
		if ! command -v "${tool}" >/dev/null 2>&1; then
			warn "'${tool}' is not installed; cannot grow the boot volume"
			return 1
		fi
	done

	if ! resolve_root_layout /; then
		warn "/ is not an LVM logical volume on a single partitioned disk; nothing to grow here"
		return 1
	fi

	log "root: ${ROOT_SOURCE} (${ROOT_FSTYPE}) on ${ROOT_PV} = partition ${ROOT_PARTNUM} of ${ROOT_DISK} -> VG ${ROOT_VG}, LV ${ROOT_LV}"

	if [ "${ROOT_FSTYPE}" != "xfs" ]; then
		warn "root filesystem is ${ROOT_FSTYPE}, not xfs; not guessing how to grow it"
		return 1
	fi

	if ! is_boot_disk "${ROOT_DISK_NAME}"; then
		warn "${ROOT_DISK} does not carry /boot; refusing to resize it"
		return 1
	fi

	log "before: $(df -h / | awk 'NR == 2 { print $2 " total, " $4 " available, " $5 " used" }')"

	# 1. Take the partition to the end of the disk. On a disk that is already
	#    correct growpart only reports NOCHANGE, so this step is a no-op.
	grow_partition "${ROOT_DISK}" "${ROOT_PARTNUM}" || return 1

	# 2. Teach LVM about the new space behind the PV. Old PVs are smaller than
	#    the partition, because the image never grew them.
	run_step "pvresize ${ROOT_PV}" pvresize "${ROOT_PV}" || return 1

	# 3. Consume only the newly freed extents, and only for the LV backing /.
	free_extents=$(vgs --noheadings -o vg_free_count "${ROOT_VG}" 2>/dev/null | tr -d '[:space:]')
	if [ -n "${free_extents}" ] && [ "${free_extents}" -gt 0 ] 2>/dev/null; then
		run_step "lvextend -l +100%FREE /dev/${ROOT_VG}/${ROOT_LV}" \
			lvextend -l +100%FREE "/dev/${ROOT_VG}/${ROOT_LV}" || return 1
	else
		log "no free extents in VG ${ROOT_VG}; LV ${ROOT_LV} already fills the volume group"
	fi

	# 4. Grow the filesystem online. A filesystem that already fills its LV is
	#    left untouched by xfs_growfs.
	run_step "xfs_growfs /" xfs_growfs / || return 1

	log "after: $(df -h / | awk 'NR == 2 { print $2 " total, " $4 " available, " $5 " used" }')"
	return 0
}

# Hand over to OKE's own init script, which is what actually joins the node to
# the cluster. Same behaviour as the image default: fetch it from the instance
# metadata service, then execute it.
run_oke_init() {
	local encoded decoded status

	if ! command -v curl >/dev/null 2>&1 || ! command -v base64 >/dev/null 2>&1; then
		warn "curl or base64 is missing; cannot retrieve the OKE init script"
		return 1
	fi

	encoded=$(mktemp) || return 1
	decoded=$(mktemp) || {
		rm -f "${encoded}"
		return 1
	}

	if curl --fail --silent --show-error --location --max-time 30 \
		--retry 5 --retry-delay 3 --retry-connrefused \
		-H "Authorization: Bearer Oracle" "${OKE_INIT_URL}" -o "${encoded}" &&
		base64 --decode "${encoded}" >"${decoded}" &&
		[ -s "${decoded}" ]; then
		rm -f "${encoded}"
		log "retrieved the OKE init script from the instance metadata service"
		bash "${decoded}"
		status=$?
		rm -f "${decoded}"
		return "${status}"
	fi

	rm -f "${encoded}" "${decoded}"
	if [ -s "${OKE_INIT_FALLBACK}" ]; then
		warn "could not refresh the OKE init script; running the copy already on disk"
		bash "${OKE_INIT_FALLBACK}"
		return $?
	fi

	warn "could not obtain the OKE init script; the node will not join the cluster"
	return 1
}

main() {
	log "starting boot volume growth"

	if grow_root_filesystem; then
		log "boot volume growth finished"
	else
		warn "boot volume growth did not finish; continuing boot with the current filesystem size"
	fi

	log "handing over to the OKE init script"
	if ! run_oke_init; then
		warn "OKE node initialization failed; see /var/log/cloud-init-output.log"
		exit 1
	fi

	log "done"
	return 0
}

main "$@"
