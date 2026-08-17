# Secrets & ansible-vault

How secrets stay out of git and get injected at deploy time.

## Layout

```
.
├── .vault_pass            # your vault password (GIT-IGNORED; see .vault_pass.example)
├── ansible.cfg            # vault_password_file line (commented by default)
└── inventory/<project>-<env>/group_vars/all/
    ├── vars.yml           # NON-secret + the "wiring": real_var: "{{ vault_* }}"
    ├── vault.yml.example  # committed template listing every vault_* var
    └── vault.yml          # YOUR encrypted secrets (create from the example)
```

Two layers:
- **`vault.yml`** holds the raw secrets as `vault_*` variables, **ansible-vault encrypted**.
- **`vars.yml`** wires each real variable to its `vault_*` value with a safe
  fallback, so the repo runs *before* you set up vault, and switches to real
  secrets the moment `vault.yml` exists.

## Worked example (`notes-api`)

The `notes-api` service needs a password for its Postgres role. That password is
never written in a role — it flows through three files:

```
vault.yml            vault_notes_db_password: "s3cret"          # encrypted
      |
      v
group_vars/all/vars.yml
      notes_db_password: "{{ vault_notes_db_password | default('change-me-notes') }}"
      |
      v
roles/services/notes-api/vars/main.yml
      postgres_users:
        - { name: notes, db: notes, password: "{{ notes_db_password }}" }
```

Without vault -> the fallback `change-me-notes` is used (the lab still runs).
With vault    -> the real secret is used. The role only ever sees `{{ notes_db_password }}`.

## Setup (once per checkout)

```bash
cp .vault_pass.example .vault_pass        # edit: real password on line 1
cp inventory/alpha-prod/group_vars/all/vault.yml.example \
   inventory/alpha-prod/group_vars/all/vault.yml
ansible-vault encrypt inventory/alpha-prod/group_vars/all/vault.yml
```

Run with vault:
```bash
ansible-playbook -i inventory/alpha-prod playbooks/site.yml --vault-password-file .vault_pass
```
Edit later: `ansible-vault edit inventory/alpha-prod/group_vars/all/vault.yml`

> Encrypted `vault.yml` is safe to commit; the scaffold git-ignores `vault.yml`
> so a *plaintext* one is never committed by accident.

## Rule of thumb
Add one `vault_<name>` per secret in `vault.yml`, wire it in `vars.yml`, and
reference the real variable from the role. Never hardcode a secret in a role's
`defaults/`, `vars/`, or a template.
