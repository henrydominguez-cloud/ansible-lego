# Getting started — build your platform from this base

This repo is a **starter kit** for a component-based ("Lego") Ansible setup. You
keep the base (conventions, lab, vault, docs) and drop in **your own** bricks and
services. This guide shows the model and how to configure/extend it.

---

## 1. The mental model (three layers)

```
   INVENTORY   inventory/<project>-<env>/          "where & how much"
               hosts.yml               → put it on host X
               group_vars/<group>.yml  → port 8081, this IP, env=prod
        ▲ places & tunes
   SERVICES    roles/services/<name>/               "the instructions"
               meta: which bricks      files/: this service's content
               defaults/ + vars/: the brick knobs for THIS service
        ▲ composes (meta dependencies)
   BRICKS      roles/components/<name>/             "reusable technology"
               e.g. nginx, postgres — install · configure · run
               parameterised, never copied

   resources/  big shared assets (configs, packs, RPMs), vendored ONCE
```

One brick, many services. Fix the brick once — every service inherits.

---

## 2. What a deploy looks like

```
  ansible-playbook -i inventory/alpha-prod playbooks/alpha-hello.yml
                         │                        │
                         │                        └─ service: hello-web
                         │                              meta → components/nginx
                         └─ inventory: group `hello`, env=prod, nginx_port=8080

   hello-web  ─┐
               ├─ pulls  components/nginx     (install nginx, template site, run)
               └─ ships  files/index.html     (its own content)
                                   │
                                   ▼
                      host alpha-hello-01  →  nginx serving :8080
```

The `hello-web` service is the on-ramp — it runs end-to-end in the local lab:
```
make lab-up && make lab-run PB=alpha-hello
```

---

## 3. Add your own BRICK (a component)

```
make new-brick NAME=myapp        # scaffolds roles/components/myapp from skeletons/
```
```
roles/components/myapp/
├── defaults/main.yml   ← knobs (brick tunables). DON'T default caller-provided ones
├── tasks/main.yml      ← install (repo|local|auto) · config · service   [tags]
├── handlers/main.yml   ← restart myapp
├── templates/          ← your *.conf.j2
└── meta/main.yml       ← dependencies: []   (bricks are leaves)
```
Then fill in `tasks/main.yml` (OS assert + install + template your config +
enable/start) and add config templates. Run it standalone via a small playbook
or from a service.

---

## 4. Add your own SERVICE (instructions)

```
make new-service NAME=my-api     # scaffolds roles/services/my-api from skeletons/
```
```
roles/services/my-api/
├── meta/main.yml       ← dependencies: [components/myapp, components/postgres]
├── vars/main.yml       ← IDENTITY knobs (instance name, file paths)  ◄─ see §5
├── defaults/main.yml   ← per-ENV knobs (ports…) that inventory may override
├── files/              ← this service's content (configs/scripts/pages)
└── tasks/main.yml      ← optional finalisation (render app config, restart)
```
Then:
1. Point `meta` at the bricks it needs.
2. Set the brick knobs (identity in `vars/`, env in `defaults/`).
3. Add a playbook `playbooks/<proj>-my-api.yml` (`hosts: <group>`), and a host
   group in `inventory/<proj>-<env>/hosts.yml`.

```
  # playbooks/alpha-my-api.yml
  - hosts: my_api
    become: true
    roles: [ services/my-api ]
```

---

## 5. The one precedence gotcha (read this)

Three tiers, low → high. Put each knob where it should be overridable **from**:

```
   brick defaults        (fallback)          roles/components/<b>/defaults  ── lowest
        ▲ overridden by
   service defaults      (per-env fallback)  roles/services/<s>/defaults
        ▲ overridden by
   inventory group_vars  (the real per-env)  inventory/<proj>-<env>/group_vars
        ▲ overridden by
   service vars/         (identity)          roles/services/<s>/vars        ── beats brick
        ▲ overridden by
   -e on the CLI                                                            ── highest
```

⚠️ **Gotcha:** during a *brick's* execution, that brick's OWN defaults **shadow**
a service's `defaults/`. So:
- A knob the SERVICE must set → put it in the service's **`vars/main.yml`**
  (identity), and/or reference it in the brick with `{{ knob | default(x) }}`
  **instead of** giving it a plain brick default.
- A knob that varies per ENV → keep it in service `defaults/` and set the real
  value in **inventory group_vars** (inventory beats brick defaults).

Example (the nginx brick): `nginx_port` has **no** brick default; the template
uses `{{ nginx_port | default(80) }}`, and `hello-web` sets `nginx_port: 8080`.
Result: 8080 wins.

Also: file paths a service passes to a brick must use
`{{ playbook_dir }}/../roles/services/<svc>/…`, **not** `{{ role_path }}` (which
resolves to the brick, not the service).

---

## 6. Configure per environment

```
inventory/
├── alpha-prod/        env=prod   (prod IPs)
│   ├── hosts.yml
│   └── group_vars/
│       ├── all/vars.yml     ← env-wide + secret wiring
│       └── <group>.yml      ← e.g. ports, IPs, endpoints
└── alpha-dev/         env=dev    (dev IPs)    same shape
```
Same role + playbook, different `-i` → different environment. You can't mix them.

### Scaling to more projects
A new project (customer, region, tenant…) is just a new inventory tree — the
roles and services are reused unchanged:
```
inventory/
├── alpha-prod/  alpha-dev/     # project "alpha"
└── beta-prod/   beta-dev/      # project "beta"  ← copy alpha-*, change hosts/values
```
```bash
ansible-playbook -i inventory/beta-prod playbooks/alpha-notes.yml   # same service, new project
```
Nothing in `roles/` changes. That is how the base scales: N projects × M
environments × the same reusable bricks and services.

---

## 7. Secrets, OS/install source, local testing
- Secrets: [secrets-vault.md](secrets-vault.md) — `ansible-vault`, nothing in git.
- OS (EL8/EL9, RHEL/Rocky/Oracle) + repo/local/air-gapped: [os-and-install-sources.md](os-and-install-sources.md).
- Local Docker lab (EL9/EL8): [local-testing.md](local-testing.md) — `make lab-up`.

---

## 8. Cheat-sheet

| I want to… | Do |
|---|---|
| Add a technology | `make new-brick NAME=x`, fill install/config/service |
| Add a deployable | `make new-service NAME=y`, set `meta` bricks + knobs + playbook |
| Change a per-env value | edit `inventory/<proj>-<env>/group_vars/<group>.yml` |
| Change service identity | edit `roles/services/<y>/vars/main.yml` |
| Try it locally | `make lab-up && make lab-run PB=alpha-hello` |
| Deploy one brick only | `ansible-playbook -i inventory/alpha-prod playbooks/install-<brick>.yml` |
