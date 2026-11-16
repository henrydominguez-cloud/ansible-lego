# Operating systems & package install sources

How bricks handle **which OS** they run on and **where packages come from**, so
the same role works on RHEL 9 / Rocky / Oracle / RHEL 8, online or air-gapped.

## Supported OS
- **Family:** RedHat — RHEL, Rocky, Oracle, AlmaLinux, CentOS.
- **Versions:** EL9 (preferred) and EL8.
- **Distro-agnostic:** bricks key off `ansible_distribution_major_version` (8/9),
  not the distro name. Every install brick asserts:
  ```yaml
  ansible_os_family == "RedHat" and ansible_distribution_major_version in ["8","9"]
  ```

## Install sources
Each install brick exposes **`<brick>_install_source`**:

| Value | Meaning | Use when |
|---|---|---|
| `repo` *(default)* | install by name from a yum repo | host can reach a repo |
| `local` | install vendored `.rpm` files from a directory | air-gapped / offline |
| `auto` | try `repo`, fall back to `local` | online now, maybe offline later |

Which repo is used for `repo` is just variables you can override in
`group_vars` (point them at your mirror). For `local`, drop `.rpm`s in the
brick's `<brick>_local_rpms_dir` (default `resources/<brick>/rpms/`,
git-ignored) **on the controller** — the machine that runs `ansible-playbook`.
The brick copies every `*.rpm` found there to `<brick>_remote_rpms_dir` on the
target (default `/var/tmp/<brick>-rpms`) and installs them from that copy with
GPG checks off. If the directory has no `.rpm` files, the run stops with a
clear error instead of skipping the install.

## Where to set it
```yaml
# inventory/alpha-prod/group_vars/all/vars.yml — an offline site
nginx_install_source: local
postgres_install_source: local
```
Or per host (`host_vars/`) or per run (`-e nginx_install_source=local`).

## Per brick (this starter's example bricks)

| Brick | install_source var | default | local RPM dir |
|---|---|---|---|
| nginx | `nginx_install_source` | `repo` (EL AppStream) | `resources/nginx/rpms/` |
| postgres | `postgres_install_source` | `repo` (EL AppStream) | `resources/postgres/rpms/` |

New bricks scaffolded with `make new-brick` follow the same pattern out of the box.
