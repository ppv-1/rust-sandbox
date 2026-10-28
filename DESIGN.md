# Design justification

## Governance Summary
### Identity
This was implemented and tested, where comments on PRs come from github-actions[bot] via github agentic workflows job.

### Least privilege
Implemented in the workflow [llm-triage.md](https://github.com/ppv-1/rust-sandbox/blob/ae8a8afeaf4a487477f5d0a94ca3fd5ef00cb490/.github/workflows/llm-triage.md?plain=1#L15)

### Safe outputs
Implemented and tested by only allowing the agent a maximum of adding llm-assisted label and comments as seen from [here](https://github.com/ppv-1/rust-sandbox/blob/ae8a8afeaf4a487477f5d0a94ca3fd5ef00cb490/.github/workflows/llm-triage.md?plain=1#L33)

### Human approval
All outputs are advisory. Maintainer still has to remove wrong labels and the agent can’t merge, so a human review is still required.

### Budgets
Implemented with a [timeout on runs](https://github.com/ppv-1/rust-sandbox/blob/ae8a8afeaf4a487477f5d0a94ca3fd5ef00cb490/.github/workflows/llm-triage.md?plain=1#L40), to account for the github copilot student plan on gh-aw's daily credit guardrail.

