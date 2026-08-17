# Downloading only ONE role (sparse checkout)

For a slow / metered link where you want just one brick or service **and its
dependencies**, not the whole repo. Paths are relative to the repo root.

## Recipe
```bash
git clone --filter=blob:none --no-checkout --depth 1 <REPO_URL> kit
cd kit
git sparse-checkout init --cone
git sparse-checkout set inventory/alpha-prod playbooks roles/services/notes-api \
    roles/components/postgres roles/components/nginx
git checkout
```
Root files (`ansible.cfg`, `requirements.yml`, `Makefile`) come automatically in
cone mode. Add more later: `git sparse-checkout add roles/components/<x>`.

## What each target needs
A **service** needs its own dir **+ every brick in its `meta/main.yml`**. A brick
is self-contained.

| Target | sparse paths (besides `inventory/<env> playbooks`) |
|---|---|
| brick nginx | `roles/components/nginx` |
| brick postgres | `roles/components/postgres` |
| service hello-web | `roles/services/hello-web roles/components/nginx` |
| service notes-api | `roles/services/notes-api roles/components/postgres roles/components/nginx` |

For your own roles, the rule is the same: the service dir + the bricks its
`meta` lists.
