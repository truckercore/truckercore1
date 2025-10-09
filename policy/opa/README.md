# OPA Policies for Modules

This directory contains Rego policies and tests that can be used to guard module rollouts and CI gates.

Files
- modules.rego — example policy with allow/deny decisions for branch approvals and function egress allowlist checks.
- modules_tests.rego — unit tests for the above policy using `opa test` or `conftest test`.

Usage
- Run with conftest: `conftest test ci/github.json -p policy/opa`
- Or with OPA: `opa test policy/opa -v`

Inputs
- Expect a JSON input object with fields: branch, approvals, checks_succeeded, functions_egress (array).
