## What changed

<!-- One or two sentences. Link the issue if there is one. -->

## Layer check

- [ ] Business rules are in a domain or service, not in a trigger file
- [ ] Every new SOQL query lives in a selector and declares its fields
- [ ] Every DML operation goes through `UnitOfWork` or documents why it cannot
- [ ] New configuration is a custom metadata record, not hardcoded Apex
- [ ] Access is enforced (`AccessGuard`, user-mode queries/DML) for anything a user can reach

## Verification

- [ ] `npm run verify` passes
- [ ] Tests added or updated, and `sf apex run test --test-level RunLocalTests` passes locally
- [ ] No secrets, org URLs or personal data in the diff
