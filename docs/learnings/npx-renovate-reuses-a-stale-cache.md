# `npx --package renovate` can run a stale Renovate

`npx --yes --package renovate -- renovate-config-validator --strict` does not
fetch the newest Renovate when an earlier `npx` run left one in `~/.npm/_npx`:
a bare package name is satisfied by whatever is cached. On the maintainer's Mac
that was Renovate 37, which predates `managerFilePatterns`, so a config the
hosted app accepts failed validation:

```
Custom Manager contains disallowed fields: managerFilePatterns
```

Asking for `renovate@latest` makes `npx` resolve the version against the
registry, and the same file validates. The hosted Renovate app always runs a
current release, so validate against one: **a validator error naming an option
the docs list is probably an old validator**; check `renovate --version` through
the same `npx` line before changing the config.
