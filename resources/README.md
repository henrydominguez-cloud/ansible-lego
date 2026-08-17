# resources/ — shared, deduplicated assets

The single source of truth for large static assets a brick needs (config trees,
data packs, offline RPMs). Vendor them **once** here instead of duplicating them
per role. Bricks read them by absolute path (see each brick's `defaults`).

```
resources/
├── nginx/rpms/        # optional: vendored nginx RPMs for offline (local) installs
└── postgres/rpms/     # optional: vendored postgresql RPMs for offline installs
```

Add a folder per brick that ships assets. Big binaries are git-ignored (see
`.gitignore`) — vendor them locally or via Git LFS, and never put secrets here.
