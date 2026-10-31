---
name: tdd
description: Test-driven development in vertical slices. Use when building a feature or fixing a bug test-first, when red-green-refactor is mentioned, or when the feature-dev agent implements an issue.
---

# Test-driven development

TDD is the red to green loop. This skill is what makes that loop produce tests worth keeping: what a good test is,
where tests go, the anti-patterns and the rules of the loop. Every section applies on every cycle.

Use the domain's own words for test names and interfaces: the issue's, the repo's docs (`CONTEXT.md` or
`docs/engineering/` when they exist) and the terms `list_people_and_terms` returns. Respect the decisions recorded in
the area you touch (`docs/adr/`).

## What a good test is

Tests verify behaviour through public interfaces, not implementation details. The code can change entirely; the tests
should not. A good test reads like a specification ("a customer can pay by invoice" says exactly what capability
exists) and survives a refactor because it does not care about internal structure.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for when to mock.

## Seams: where tests go

A **seam** is the public boundary you test at: the interface where you observe behaviour without reaching inside.
Tests live at seams, never against internals.

Before the first test, write down the seams under test: the public interfaces the issue's acceptance criteria are about.
Put them in your report. You cannot test everything; choosing the seams first is how the effort lands on the critical
paths and the complex logic instead of every edge case. When the issue leaves the seam open and it matters, ask before
you write the test.

## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private functions, or verifies through a side channel
  (querying the database instead of using the interface). The tell: the test breaks on a refactor that did not change
  behaviour.
- **Tautological**: the assertion recomputes the expected value the way the code does
  (`expect(add(a, b)).toBe(a + b)`), so it passes by construction and can never disagree with the code. Expected values
  come from an independent source: a known literal, a worked example, the issue.
- **Horizontal slicing**: all tests first, then all code. Bulk tests verify imagined behaviour, test the shape of
  things and commit to a structure before you understand the problem. Work in **vertical slices** instead: one test,
  one implementation, repeat, each test answering what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first and watch it fail for the right reason. Then write only enough
  code to pass it. Do not anticipate later tests or add features nobody asked for.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Run only the file you are on.** It takes seconds. The full suite runs once, before the commit.
- **Refactor after green, not during red.** Tidy when the slice passes, with the tests as the net.
