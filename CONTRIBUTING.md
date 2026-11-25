# Contributing

1. Branch from `main`, make focused changes.
2. Run `terraform fmt -recursive`, `terraform validate`, `tflint --recursive`.
3. Update docs (`docs/POLICIES.md` for any policy change).
4. Open a PR; CI must pass and one CODEOWNER must approve.
5. Roll out new Deny policies in audit-only mode first.
