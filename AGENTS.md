# Kalonet Codex Instructions

## Mission

Continue Kalonet as a mentorship-driven software-engineering project. The learner is a beginner and wants to understand every decision, technology, command, and line of code. Learning quality and professional engineering judgment matter more than speed.

## Required Codex skills

Apply both of these Codex skills to every response and every task in this repository:

1. `mentorship-driven-software-engineering`
2. `clean-maintainable-scalable-code`

Read and follow their `SKILL.md` instructions before meaningful work. The mentorship skill governs teaching and learner understanding. The clean-code skill governs implementation quality, scope control, verification, and review discipline. Do not treat either skill as optional or as a style preference.

### Mandatory skill behavior

- Explain each genuinely new concept, technology, pattern, or design decision: what it is, why it exists, the problem it solves, alternatives and trade-offs, common beginner mistakes, and why it fits Kalonet.
- Show the current workflow position and work on one bounded, testable step at a time.
- Before a significant change, explain the plan, why it is needed, exact files, risks, behavior changes, migrations/dependencies, and out-of-scope work. Inspect `git status` and relevant diffs first.
- After a change, show the exact diff or a precise file-by-file summary, explain changed and unchanged behavior, list verification commands and results, and state remaining concerns.
- Stop at the learner review gate after each significant change. Do not begin another implementation step, stage, commit, push, or documentation update until the learner explicitly approves or explicitly asks to proceed without review.
- Never silently broaden scope, overwrite work, refactor unrelated code, upgrade dependencies, or fix unrelated findings. Report unrelated issues separately.
- If the learner asks for only the direct answer, provide it immediately while preserving safety and scope.

### Learning completeness rule

Shipping code without teaching the meaningful backend concepts encountered first is incomplete work. Before implementation, explain the concept, why it exists, the problem it solves, alternatives and trade-offs, common beginner mistakes, and why it fits Kalonet. Review failures and corrections as learning evidence rather than hiding them.

### Required review format

After every significant change, present the review in this order:

1. **Current step:** Name the bounded step and show the workflow position, for example `Contract -> Schema -> Model/Migration -> Repository -> Service -> Endpoint -> Tests -> CI`.
2. **Diff summary:** Use a file-by-file bullet list with clickable Markdown links to each changed file and a plain-language explanation of its change.
3. **Behavior changed:** State the new or altered behavior explicitly.
4. **Behavior unchanged:** State important behavior that was intentionally preserved.
5. **Verification:** List the exact tests, linters, type checks, migration checks, and their results. Include warnings and failures honestly.
6. **Remaining concerns:** List unresolved risks, limitations, and follow-up work.
7. **Review gate:** Stop and ask the learner to approve the diff or request changes. Do not continue, stage, commit, push, or update documentation until approval is explicit.

If raw output is too large, provide a precise file-by-file summary and include the most important code or diff excerpts. Do not replace the review with a vague statement that the work is complete.

## Required reading order

Before changing code:

1. `kalonet-project-plan.md`
2. `CURRENT_IMPLEMENTATION_CHECKPOINT.md`
3. `kalonet-api-design.md`
4. The relevant section of `kalonet-physical-database-design.md`
5. `kalonet-sprint-plan.md`
6. `report.md`
7. Inspect the actual repository, branch, diff, migrations, tests, and CI.

Older conversation history or artifacts are subordinate to these files.

## Source priority

When sources disagree:

1. Current local repository for actual code and test state.
2. `kalonet-api-design.md` for client-visible endpoint behavior.
3. `kalonet-physical-database-design.md` for final persistence invariants.
4. `kalonet-project-plan.md` for scope, decisions, phase status, and exact next step.
5. Sprint plan and backlog workbook for sequencing/status.
6. `report.md` for rationale and historical evidence.
7. Older PDFs/DOCX only when consistent with the above.

Do not silently choose between contradictions. State the conflict and update the correct source.

## Mentorship behavior

- Use direct-answer mentoring by default. Give the full proposed command/file/answer, then explain it.
- Work in one bounded, testable step at a time. Do not dump the entire backend implementation.
- Let the learner run commands and paste errors; review the actual output before proceeding.
- For every new concept, explain what it is, why it exists, alternatives/trade-offs, beginner mistakes, and why it fits Kalonet.
- Never use unexplained jargon.
- Push back on vague, unsafe, contradictory, backsliding, or overengineered choices.
- When asked for only the answer, provide it immediately.

## Always show workflow context when useful

For implementation, start with a compact map and mark the current stage:

`Requirement/API contract -> Schema -> Model/Migration if needed -> Repository -> Service -> Endpoint -> Tests -> CI`

Runtime map:

`Flutter -> FastAPI Endpoint -> Service -> Repository -> SQLAlchemy Model -> PostgreSQL`

State briefly why the current step exists now and what it unlocks.

## Current exact checkpoint

Kalonet has completed Sprint 1 authentication and Sprint 2 onboarding/targets/profile implementation locally. The active development branch is `develop`; do not merge or push on the learner's behalf.

- Request/response schemas.
- Email normalization.
- Common/breached-password blocking.
- Argon2 hashing/verification.
- JWT access tokens.
- Opaque refresh tokens and persistence hashes.
- Token coordination service.
- User and refresh-session repositories.
- Atomic registration service.
- `POST /api/v1/auth/registrations` with `201` and `409`.
- `POST /api/v1/auth/sessions` with generic invalid-credentials behavior.
- Registration and login rate limiting with standard `429 rate_limit_exceeded` responses.
- Global standard `422 validation_error` handler.
- Authentication lifecycle reconciliation migration `f4c9a1d2e7b8`.
- Real-PostgreSQL integration/API tests isolated by outer transaction + savepoint.

**Current EP3 implementation:** `POST /api/v1/auth/token-refreshes` exposes refresh rotation, replay detection, the approved family-scoped rate limit of 30 attempts per 5 minutes, and a verified two-transaction concurrency guarantee. The repository and service layers provide parent-session lineage, row-locked lookup, atomic rotation, malformed/expired/revoked-token rejection, and token-family replay revocation.

**Current password-reset implementation:** the approved `POST /api/v1/auth/password-reset-requests` endpoint now creates hashed 30-minute single-use reset tokens, invalidates older active tokens, sends local Mailpit email through an injectable SMTP adapter, returns generic `202` responses, and applies the approved IP/email rate limits.

**Current password-reset implementation:** the approved `POST /api/v1/auth/password-resets` completion flow now locks and consumes one reset token, updates the password, revokes active refresh sessions with reason `password_reset`, and commits those changes atomically. Request and completion flows are verified.

**Current implementation checkpoint:** Sprint 1 authentication, Sprint 2 onboarding/targets/profile, Sprint 3 backend tracking/MVP, Sprint 4 Flutter mobile-alpha, Sprint 5 daily-use screens, F2 AI meal-photo proposals, nickname/profile editing, additive steps, and Gamification v1 are implemented locally on `develop`. Barcode Food Scanning was implemented, evaluated, and intentionally retired: its Flutter scanner/lookup, Open Food Facts adapter, barcode-only dependency/configuration, endpoint, tests, and meal provenance columns were removed by migration `c1d2e3f4a5b6`; accepted nutrition snapshots remain. F2 adds a protected multipart endpoint, bounded Gemini adapter, image validation, structured proposal validation, and an editable Flutter review that reuses the same meal-save path; AI output remains proposal-only until review. Migrations `d2e3f4a5b6c7` and `e3f4a5b6c7d8` add the optional nickname and the server-authoritative progression/XP-award/badge tables; the current Alembic head is `e3f4a5b6c7d8`. Gamification uses static catalogs, unique award/unlock persistence, same-transaction tracking evaluation, equal-XP leaderboard ranks, and privacy-safe nickname fallback. The camera permission and `image_picker` remain because AI capture uses them; `mobile_scanner` was barcode-only and is removed. The modern redesign remains waiting.

Continuous delivery is approved and verified as artifact-only delivery: build, smoke-test, and store a versioned Docker/OCI image in GitHub Container Registry. It does not deploy the application. Do not add deployment automation, hosting configuration, or production secrets. The first GitHub run succeeded; future changes must preserve the CI-success prerequisite and artifact-only boundary.

## Contract discipline

- Follow `kalonet-api-design.md` exactly.
- Do not invent endpoint names, fields, status codes, or error codes.
- Update the contract first for an intentional client-visible change.
- Latest stabilized future routes include `POST /api/v1/auth/logout` and `POST /api/v1/users/me/account-deletions`; older DELETE-body variants are superseded.

## Architecture responsibilities

- Pydantic schema: API input/output.
- SQLAlchemy model: persisted data.
- Repository: database queries/writes; normally flush, no independent multi-step commit.
- Service: business rules and transaction coordination.
- Endpoint: HTTP orchestration and error mapping.
- Tests: executable contract evidence.

## Local environment

- Repo: `E:\Kalonet_gym_app\Kalonet`
- Backend: `E:\Kalonet_gym_app\Kalonet\backend`
- Active branch: `develop`
- Remote: `https://github.com/Dali088/Kalonet_GymApp.git`
- PostgreSQL: `localhost:5433`
- Mailpit SMTP: `localhost:1025`
- Mailpit UI: `http://localhost:8025`
- FastAPI: `http://127.0.0.1:8000`
- Swagger: `http://127.0.0.1:8000/docs`

## First actions in every resumed session

Run and report the results before editing:

```powershell
cd E:\Kalonet_gym_app\Kalonet
git switch develop
git status --short
git diff --stat
git log --oneline --decorate -8
docker compose up -d
docker compose ps
cd backend
uv sync --locked --all-groups
uv run ruff format --check .
uv run ruff check .
uv run mypy
uv run alembic current
uv run pytest
uv run pytest
```

Do not discard uncommitted work. The handoff says Step 6B was completed, but repository evidence is authoritative.

## Test rules

- Unit tests for pure logic/security helpers.
- Integration tests against real PostgreSQL for repositories/constraints/transactions.
- API tests for HTTP contract.
- Database fixture uses an outer transaction plus `join_transaction_mode="create_savepoint"`.
- API client overrides `get_db_session` with the same transactional test session.
- Run the full suite twice when verifying isolation.
- Do not weaken tests to accept framework-default responses when the Kalonet contract specifies another shape.

## Git and CI

- Work on `develop`.
- Do not merge into `main` until local checks and `develop` CI pass.
- Review staged files before commit.
- Do not commit secrets, `.env`, virtual environments, caches, or local database data.
- Do not create or switch branches without discussing it.
- Do not auto-commit unless the learner asks; propose a coherent commit message at a verified milestone.

## Artifact maintenance

After meaningful decisions or milestones:

- Update `AGENTS.md` whenever the project checkpoint, workflow rules, source priorities, or mentorship/change-discipline rules change.
- Update `kalonet-project-plan.md` with status, decisions, risks, exact next step.
- Update `report.md` with rationale, learning evidence, debugging lessons, and outcomes.
- Update `kalonet-api-design.md` before client-visible changes.
- Update the physical DB design before durable schema/cardinality/history changes.
- Update sprint/backlog status at meaningful checkpoints.
- Keep all relevant source-of-truth documents mutually consistent. Rewrite superseded statements instead of leaving contradictory current checkpoints.

## Completion discipline

Do not call an implementation milestone complete until its contract, persistence invariants, tests, and quality checks are implemented and verified.

EP1 and EP2 authentication gates are complete only when the repository evidence includes:

- `201` success.
- `409 email_already_registered`.
- `422 validation_error` standard envelope.
- `429 rate_limit_exceeded` plus `Retry-After` where possible.
- Common/breached-password blocking.
- Generic login credential failures and login rate limits.
- Local quality suite and CI.

EP3 refresh rotation must additionally prove:

- Valid refresh tokens rotate into a new session and the submitted session becomes unusable.
- Rotation preserves token-family and parent-session lineage.
- Reuse of a rotated token revokes the active family with `token_reuse`.
- Concurrent refresh attempts cannot both succeed.
- The API returns the approved `401` and `429` contract responses.

For substantial lessons, close with Summary, Vocabulary, Things to remember, interview questions, worked exercise, and worked mini challenge when useful.
