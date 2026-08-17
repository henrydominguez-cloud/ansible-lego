# Contributing

_Maintained by Henry Domínguez Grullón._

Thanks for extending the kit! Most contributions are **a new brick** (a
technology) or **a new service** (a composition). This page is the convention
cheat-sheet. The mental model lives in [docs/getting-started.md](docs/getting-started.md).

## Setup

```bash
make deps                 # Ansible collections (ansible.posix, community.general, community.docker)
make lab-up               # local EL9/EL8 Docker lab (needs Docker running)
```
Requires `ansible-core` ≥ 2.12. For linting: `pip install -r requirements-dev.txt`
(then `make lint`, or `yamllint .` + `ansible-lint`). CI runs the same checks on
every push / PR — see `.github/workflows/ci.yml`.

## The golden rules (read once)

1. **Bricks are leaves; services compose.** A brick (`roles/components/<x>`)
   knows one technology and nothing about any service. A service
   (`roles/services/<y>`) has **no install logic** — it lists bricks in `meta`
   and sets their knobs. `meta: dependencies` run before the service's own tasks.

2. **Don't let a brick default shadow a service knob.** During a brick's run its
   *own* `defaults/` beat the caller's `defaults/`. So:
   - a knob the **service** provides → the brick references it as
     `{{ knob | default(fallback) }}` (no plain brick default), and the service
     sets it in its **`vars/main.yml`** (identity) — see the `nginx_port` example.
   - a **per-environment** knob → keep it in the service's `defaults/` and set
     the real value in `inventory/<proj>-<env>/group_vars/`.
   Precedence (low→high): `brick defaults < service defaults < inventory group_vars < service vars/ < -e`.

3. **Reference a service's own files with `playbook_dir`, not `role_path`.**
   `{{ playbook_dir }}/../roles/services/<svc>/files/…` — `role_path` inside a
   brick resolves to the *brick*, not your service.

4. **Check caller-provided assets on the controller.** If a brick copies
   something the caller ships from `resources/`, verify it with
   `stat … delegate_to: localhost, become: false` (the file is on the controller,
   not the remote).

5. **Every install brick** asserts the OS and supports install sources:
   ```yaml
   ansible_os_family == "RedHat" and ansible_distribution_major_version in ["8","9"]
   ```
   and exposes `<brick>_install_source: repo | local | auto`
   (see [docs/os-and-install-sources.md](docs/os-and-install-sources.md)).

6. **Tag your tasks** (`install` / `config` / `service`, plus any finer ones) so
   `--tags` works. If you `include_tasks` a file, tag the child tasks too, not
   just the include.

7. **Secrets never touch git.** Put the raw value in `vault.yml` as
   `vault_<name>`, wire it in `group_vars/all/vars.yml`, reference the real var
   from the role. Never hardcode a secret in `defaults/`, `vars/`, or a template.
   See [docs/secrets-vault.md](docs/secrets-vault.md).

8. **Idempotent + check-safe.** A second run reports `changed=0`. Guard shell
   commands with `creates:`/a `SELECT`-style check and set `changed_when`.

## Add a brick

```bash
make new-brick NAME=myapp          # scaffolds roles/components/myapp from skeletons/
```
Fill in `tasks/main.yml` (OS assert → install → template config → enable/start),
add templates, and a handler. Checklist:

- [ ] `meta/main.yml` → `dependencies: []` (bricks are leaves)
- [ ] OS assert + `myapp_install_source` (repo/local/auto)
- [ ] No brick default for knobs the caller provides (use `| default()`)
- [ ] Tasks tagged `install` / `config` / `service`
- [ ] A handler (`restart myapp`) notified by config changes
- [ ] Runnable standalone (`playbooks/install-myapp.yml` optional)

## Add a service

```bash
make new-service NAME=my-api       # scaffolds roles/services/my-api from skeletons/
```
Checklist:

- [ ] `meta/main.yml` → the bricks it needs
- [ ] `vars/main.yml` → IDENTITY knobs (names, file paths via `playbook_dir`)
- [ ] `defaults/main.yml` → per-environment knobs (inventory can override)
- [ ] `files/` → this service's content
- [ ] a playbook `playbooks/<proj>-my-api.yml` (`hosts: <group>`) + a host group
      in `inventory/<proj>-<env>/hosts.yml`
- [ ] add a play to `playbooks/site.yml`

## Before you open a PR

```bash
make lint                                  # yamllint + ansible-lint
make syntax-all                            # every playbook syntax-checks
make lab-up && make lab-run  PB=<your-pb>  # it actually deploys
make lab-idem PB=<your-pb>                 # 2nd run is changed=0
```
- Keep PRs small and focused (one brick or one service).
- Update the relevant `docs/` if you change a convention.
- No secrets, no vendored blobs (RPMs/binaries are git-ignored — see `.gitignore`).

## Commit messages

Short imperative subject, optionally a `type:` prefix (`feat:`, `fix:`, `docs:`,
`test:`), and a body explaining *why*. Example:
```
feat(redis): add redis brick + cache-tier service

Redis from the EL AppStream, multi-instance, optional password via vault.
```

Questions or ideas? Open an issue. Happy building. 🧱
