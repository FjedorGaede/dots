---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me", "poke holes", "devil's advocate", "challenge this", or "what am I missing".
---

Interview the user relentlessly about every aspect of their plan until reaching shared understanding. These are patterns, not a rigid script — skip steps that don't apply. The goal is shared understanding, not checklist completion.

## Procedure

1. Ask the user to state their plan in one sentence.
2. Map it into a decision tree — break it into independent dimensions (architecture, data model, tooling, deployment, security, etc.). If the plan is too simple to branch, confirm understanding and stop. Don't invent branches.
3. For each dimension, ask one question at a time. For each, provide a recommended answer with reasoning.
4. Resolve dependencies — revisit earlier decisions if a later answer creates a conflict.
5. Continue until all branches are resolved or the user says "done."

## Question categories

Ask about: alternatives, constraints, edge cases, tradeoffs, assumptions, scope.

## Finishing

Summarize the resolved decisions in a table:

| Dimension | Decision | Rationale |
|-----------|----------|-----------|

Then ask: "Does this match your understanding? Anything to revisit?"

## Codebase exploration

If a question can be answered by reading the codebase, explore it instead of asking. Report findings and move on.
