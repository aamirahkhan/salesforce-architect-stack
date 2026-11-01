# Contributing

This repository is a baseline other projects copy. Changes should make it more correct or more
adoptable, never just more clever.

## Setup

```bash
npm ci
sf org login web --alias devhub --set-default-dev-hub
sf org create scratch --definition-file config/project-scratch-def.json --alias stack --set-default
sf project deploy start --source-dir force-app --wait 30
sf org assign permset --name Architect_Stack_Admin
```

`npm run verify` works without an org and is the fastest feedback loop while editing Apex. `npm run
format` requires Java 11+ because `prettier-plugin-apex` runs the Apex parser.

## Daily workflow

1. Pull `main`. Start from the baseline rather than from a stale local copy.
2. Create a branch: `feat/invoice-approval`, `fix/unit-of-work-rollback`, `docs/trigger-control`.
3. Make the smallest change that satisfies the requirement, in the correct layer.
4. Add or update tests in the same commit.
5. Run `npm run verify` and `sf apex run test --test-level RunLocalTests`.
6. Open a pull request using the template. Describe the *why*, not the diff.

## Commit messages

Imperative subject under 72 characters, then a short body explaining the trade-off:

```
Add batch size configuration to BatchJob

Reads DefaultBatchSize from AppConfig so a backfill can be tuned without a
deployment. Falls back to 200 when the metadata record is absent.
```

Do not commit org URLs, auth URLs, secrets, user data or screenshots of real records.

## Adding a feature

Follow the five steps in the [README](README.md#add-a-feature-in-five-steps). Pull requests that skip a
layer should explain why in the description.

Examples of changes that need an ADR in `docs/adr/`:

- A new cross-cutting layer or a change to the layer boundaries.
- A new security or data-access policy.
- A new external dependency in the runtime path.
- A change to the trigger bypass model.

## Tests

- A bug fix includes a test that fails before the fix.
- A new framework class includes tests for the success path, the failure path and the boundaries
  (empty input, null, limits).
- Permission behaviour is tested with `System.runAs` and a second user.
- Tests must pass in a fresh scratch org with no manual data.

## CI

| Job | Runs when | What it does |
| --- | --- | --- |
| Source verification | every push, pull request, weekly cron | `npm run verify` |
| Deploy and run Apex tests | when `SFDX_AUTH_URL` secret exists | scratch org, deploy, `RunLocalTests` |

Create the Dev Hub secret with:

```bash
sf org display --target-org devhub --verbose --json | jq -r '.result.sfdxAuthUrl'
```

Store it as the repository secret `SFDX_AUTH_URL`. Rotate it when the Dev Hub auth changes.

## Definition of done

- Logic is in the correct layer and the pull request says which one.
- No SOQL or DML outside a selector or `UnitOfWork`.
- Access checks are present for anything a user can reach.
- Errors carry an `AppException` code, record id and field name where applicable.
- Tests cover the happy path and at least one failure path.
- `npm run verify` passes.
- Documentation updated if behaviour, configuration or the quickstart changed.
