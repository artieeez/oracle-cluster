# ADR 002: Grow the node boot partition automatically

Status: Accepted · 2026-11-02

## Context

The node pool requests a 75 GiB boot volume (`node_boot_volume_size_gbs`), but the
OKE node image only ever allocates part of it:

```text
sda 75 GiB -> sda1 100 MiB (/boot/efi) + sda2 1 GiB (/boot) + sda3 45.5 GiB (LVM PV)
              ~28.4 GiB never allocated

VG ocivolume 45.50g (VFree 0)
  LV root  35.5g  -> /
  LV oled  10.0g  -> /var/oled
```

Nothing in the image, in cloud-init, or in the node pool grows `sda3`, resizes the
PV, or extends `root`, so the extra 28.4 GiB of the larger boot volume simply do
not exist as usable space. This was not theoretical: `/` sat at 82% used, putting
kubelet's `imagefs.available < 15%` eviction floor roughly 1 GiB away. A nightly
Job that writes ~500 MiB tripped `DiskPressure`, and the pod was evicted.

On 2026-10-17 the node was repaired by hand:

```bash
growpart /dev/sda 3
pvresize /dev/sda3
lvextend -l +100%FREE /dev/ocivolume/root
xfs_growfs /
```

`/` is now 63.8 GiB at 45.7% used (34.5 GiB free). The manual repair does not
survive a node replacement: `terraform apply` that recreates the node, a node
pool upgrade, or a node pool cycle all start from the image layout again, and the
same slow-motion disk pressure returns unnoticed until kubelet starts evicting.
The failure is also invisible in Terraform - the node pool says 75 GiB, and the
plan is clean.

## Decision

Grow the boot volume from the node itself, at first boot, from node pool metadata:

- `modules/oke/main.tf` sets `node_metadata = { user_data = base64encode(file(...)) }`
  on `oci_containerengine_node_pool.oke`.
- `modules/oke/files/node_boot_grow.sh` is the cloud-init user data. It grows
  `sda3` with `growpart`, runs `pvresize`, extends only the LV mounted on `/`
  with `lvextend -l +100%FREE`, and grows the filesystem online with
  `xfs_growfs /`.
- The script grows the disk *before* handing over to the OKE init script, so
  kubelet starts with the final filesystem size and no init-order race exists.

Mechanism details, verified against the pinned provider (`oracle/oci` 8.29.0,
constraint `~> 8.26`, `versions.tf`): `node_metadata` is a `map(string)` and is
updatable, and OKE passes `user_data` through to the instance metadata as
base64-encoded cloud-init. Because a custom `user_data` replaces the image's
default user data, the payload fetches and runs `oke_init_script` from the
instance metadata service itself - the pattern Oracle documents for custom
cloud-init on managed nodes.

## Why the manual fix is not enough

- **It is not durable.** Any node replacement (pool update, cycle, or an
  unrelated `apply` that forces recreation) recreates the gap. This cluster runs a
  single node, so "just fix the new node" also means a manual SSH session right
  after every replacement, before disk pressure has any chance to matter.
- **It leaves no trace.** Nothing in the repo records that the layout is wrong, so
  the next person debugging `DiskPressure` starts from scratch.
- **It is invisible to `terraform plan`.** The node pool already claims 75 GiB, so
  drift detection cannot surface this class of problem.

## Alternatives considered

- **Rely on `oci-growfs -y` from `oci-utils`.** This is what the OKE
  documentation suggests, and the commands the script runs are the same sequence
  its LVM branch performs. It was rejected as the *only* mechanism because it
  prompts interactively when stdin is not a tty, aborts with exit 1 on
  unexpected layouts, gives no explicit statement about which LV is extended, and
  adds a dependency on `oci-utils` being present on the image. An explicit script
  is auditable, bounded by per-step timeouts, and can be fail-soft by design.
- **Bake a pre-grown image or instance configuration.** This moves the problem to
  image/pipeline maintenance and still needs a disk-level growth step for whatever
  `boot_volume_size_in_gbs` is set to.
- **Fix it after the node joins the cluster** (DaemonSet, Job, or Cluster API style
  post-boot hook). Requires a working kubelet on a disk that is already near its
  eviction threshold, which is exactly the state being avoided.
- **Manage the node instances with Terraform** to use `oci_core_instance` metadata.
  OKE owns those instances; this is not available for managed node pools.

## Consequences

Guarantees in the payload:

- **Idempotent.** An already-correct disk only produces `NOCHANGE` from
  `growpart`, `pvresize` reports nothing to resize, `vgs` reports zero free
  extents so `lvextend` is skipped, and `xfs_growfs` is a no-op. A partially grown
  disk (partition grown, LV not extended) is repaired.
- **Narrow.** Only the PV that backs the VG of the LV mounted on `/` is touched,
  only that LV is extended (`oled` and `/var/oled` are left alone), and the disk
  must also carry `/boot` - so the 50 GB `sdb` block volume behind the in-cluster
  NFS server (`blockvolume.csi.oraclecloud.com`) can never be resized.
- **Fail soft.** Every growth failure is logged with an `[oke-boot-grow]` prefix
  and boot continues; kubelet and workloads are never restarted or signalled.
  Failure to obtain the OKE init script is the one hard failure, because a node
  that cannot join the cluster should not look healthy.
- **Bounded.** Each step runs under `timeout 120`, so a wedged command cannot stall
  the node join indefinitely.

Known limitations:

- The change only applies to nodes launched after the node pool is updated. The
  running node keeps its current (already repaired) layout until it is replaced;
  on a single-node cluster that replacement is downtime and is a human decision.
- The script is specific to the current image layout: Oracle Linux, xfs on an LVM
  LV, PV on a partition. If a future image changes the layout it logs a warning
  and skips growth rather than guessing.
- The payload now owns the OKE init handover. If OKE changes how nodes bootstrap,
  this script must follow; the cluster-join failure mode is loud
  (`/var/log/cloud-init-output.log`, node never registers) rather than silent.
- Growth is untested on a real replacement node so far; validate with `lsblk`,
  `vgs`, `lvs` and `df -h /`, plus the `[oke-boot-grow]` lines in
  `/var/log/cloud-init-output.log`.

## References

- `modules/oke/main.tf` - `node_metadata.user_data` on the node pool.
- `modules/oke/files/node_boot_grow.sh` - the payload.
- Oracle: Using Custom Cloud-init Initialization Scripts to Set Up Managed Nodes
  (example 5 grows the boot partition with `oci-growfs` before running the OKE
  init script) -
  <https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengusingcustomcloudinitscripts.htm>.
- Oracle: `oci-growfs` in `oci-utils`, for the LVM resize sequence this script
  reproduces explicitly -
  <https://github.com/oracle/oci-utils/blob/master/lib/oci_utils/impl/oci_growfs_main.py>.
