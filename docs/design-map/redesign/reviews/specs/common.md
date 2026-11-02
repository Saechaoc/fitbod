Constraints: do not edit, create or delete any file in the repository or in the proposal folder other than your own report file. Do not run xcodebuild, swift build or any test. Do not commit. Cite a file and line (path:line) for every claim about the code, the design map or the proposal. Do not summarise or restate the proposal; report only what is wrong, missing or unproven. If you cannot verify a claim, say so and mark the finding "unverified" instead of guessing. Do not ask the coordinator questions unless you are blocked; decide and state your assumption.

Ownership: you own only your report file. The proposal files and the repository are read-only for you.

Report format (Markdown):
1. A one-paragraph verdict: can this proposal be finalized as written, yes or no, and why.
2. Findings ranked by blast radius, worst first. Each finding has: a bold one-line title; "Trigger:" the data, state or action that sets it off; "Mechanism:" how the proposal breaks, loses or misplaces something; "Blast radius:" what the lifter loses and in which states or screens; "Smallest fix:" the least change to the proposal that closes it; "Evidence:" path:line citations; "Severity:" either "blocks finalization" or "fix soon".
3. A short list of what you checked and found correct (names only, no prose).
Write it with one sentence per line and no em dashes.

Observable acceptance: the report file exists at the path named above with the three sections, every finding carries Trigger, Mechanism, Blast radius, Smallest fix, Evidence and Severity, and the findings are ranked. If the report path is not writable, put the entire report in your worker_done message instead. When done, send worker_done with the report path, the number of "blocks finalization" findings and the number of "fix soon" findings.
