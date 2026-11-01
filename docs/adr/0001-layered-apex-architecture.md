# ADR 0001 — Layered Apex architecture

- **Status:** Accepted
- **Date:** 2026-11-01
- **Deciders:** Salesforce architecture

## Context

Salesforce projects start with a trigger and a service class and end up with five variants of the same
logic: one in the trigger, one in the LWC controller, one in a Flow, one in the batch job and one that
a consultant added in production. The costs show up later as recursion bugs, inconsistent validation,
queries that cannot be explained during a security review, and tests that only pass with a full sandbox
refresh.

The alternative — a framework per project — is worse. Every team rebuilds it, every rebuild has the same
missing guardrails, and nobody can onboard onto the fifth version.

## Decision

Adopt one dependency-free layered structure, enforced by code review:

```
trigger → TriggerDispatcher → TriggerHandler
                                 ├── Domain     (rules, no SOQL/DML)
                                 └── Service    (use case)
                                       ├── Selector   (all SOQL, user mode)
                                       └── UnitOfWork (all DML, atomic)
```

Rules that make the structure real:

1. A trigger file contains exactly one line.
2. A trigger handler orchestrates; it does not contain business rules.
3. A domain never queries or persists.
4. A service is the only layer that composes access checks, queries, rules and DML.
5. Every SOQL statement is a selector method with an explicit field list.
6. Every user-facing write goes through `UnitOfWork` or documents why it cannot.

## Consequences

**Positive**

- A new engineer can find any rule by object and layer, without searching the whole codebase.
- Security review has one place to inspect for queries and one for writes.
- Tests run without `seeAllData`, because each layer can be exercised independently.
- Reuse across trigger, LWC, Flow and async is structural rather than aspirational.

**Negative**

- More files per feature than a single service class. A simple rule touches a domain, a handler and a
  trigger, even when it is five lines.
- Teams must resist adding "just this one query" to a service. The structure only pays off when it is
  followed.
- `UnitOfWork` requires callers to think about insert order instead of resolving relationships
  implicitly.

## Alternatives considered

**One service class per object, called from the trigger.** Simplest to start, but access checks, query
construction and DML mix into one 800-line class, and the same rules get duplicated per entry point.

**Adopt fflib Apex Common.** Mature, but it is an external dependency with a large surface, and teams
still need to define the trigger-handler and domain conventions on top of it. This stack borrows the
patterns without the dependency.

**Declarative-first (Flow + validation rules) with Apex for edge cases.** Good default for simple
validation, but it does not scale to transactional multi-object logic, callouts, or testable complex
rules, which is where the failure modes live.

## References

- [Architecture](../ARCHITECTURE.md)
- [Coding standards](../CODING-STANDARDS.md)
