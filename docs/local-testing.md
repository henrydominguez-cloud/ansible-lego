# Local testing lab

Run the roles against throwaway **Enterprise Linux containers** on your machine —
no VMs, no real hosts. Lives in `lab/`, driven by the `Makefile` (`make lab-*`).

## Prerequisites
- Docker running (`docker info` works — on macOS start Docker Desktop, or
  `colima start`).
- Collections installed: `make deps` (includes `community.docker`).

## Quick start
```bash
make lab-up                     # build + start EL9 (x2) and EL8 containers
make lab-run PB=alpha-hello     # deploy hello-web (nginx)            -> serves :8080
make lab-run PB=alpha-notes     # deploy notes-api (nginx + postgres) -> serves :8081 + 'notes' DB
make lab-shell C=rocky9a     # poke around inside a container
make lab-down                   # tear it all down
```
Both example services are **arch-native** (nginx/postgres are in the EL
AppStream), so they install and run for real in the lab on Apple Silicon.

Verify:
```bash
docker exec rocky9a curl -s localhost:8080 | grep hello-web
docker exec -u postgres rocky9b psql -tAc "SELECT datname FROM pg_database WHERE datname='notes'"
```

## Caveats worth knowing
- **Colima / Ubuntu Docker hosts:** two settings exist for them (verified on
  Colima; not re-tested on Docker Desktop). `cgroup: host` in `lab/docker-compose.yml` lets EL9's
  systemd boot (without it the EL9 containers exit 255). `ansible_become_method:
  su` in `lab/inventory/hosts.yml` avoids `sudo`, whose PAM account check is
  blocked by the host's AppArmor profile for `unix_chkpwd`
  (`sudo: PAM account management error`).
- **arm64 + x86_64-only RPMs:** if a brick installs a package that only ships
  x86_64 (some vendor RPMs), a native arm64 container can't install it — use
  `--check`/structural mode, or `make lab-up LAB_PLATFORM=linux/amd64` (emulated).
- **EL8 + systemd in Docker:** on cgroup v2, an EL8 container's systemd bus may
  not come up, so service *start* can fail on EL8 (rendering still works). EL9
  containers run systemd fine. For EL8 service behaviour use a real VM.

## Handy commands
| Command | Does |
|---|---|
| `make lab-up [LAB_PLATFORM=linux/amd64]` | build + start containers |
| `make lab-run PB=<playbook>` | deploy a playbook to the lab |
| `make lab-check PB=<playbook>` | dry-run (`--check --diff`) |
| `make lab-idem PB=<playbook>` | run twice; 2nd should be `changed=0` |
| `make lab-shell C=rocky8` | shell into a container |
| `make lab-ps` / `make lab-down` | status / teardown |

## A note on portability (lessons baked into the bricks)
Testing roles locally catches things `--syntax-check` cannot. The bricks and
skeletons here already encode a few hard-won rules — see
[getting-started.md](getting-started.md) → "The one precedence gotcha":
- check a caller-provided asset on the **controller** (`delegate_to: localhost`),
  not the remote;
- reference a service's own files via `{{ playbook_dir }}/../roles/services/<s>/…`,
  not `{{ role_path }}` (which resolves to the brick);
- never let a **brick default shadow** a knob the service provides — put such
  knobs in the service's `vars/` or use `{{ knob | default(...) }}` in the brick.
