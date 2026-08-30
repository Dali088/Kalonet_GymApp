# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Kalonet serves casual fitness users who train several times per week but do not
want to become nutrition experts just to make consistent progress.

## Product Purpose

Kalonet helps users plan and track nutrition, hydration, steps, and activity in
one daily routine. Success means a user can understand today's status and take
the next useful action without wrestling with spreadsheet-like nutrition tools.

## Positioning

Kalonet performs the planning and calculation work—especially calorie and
macronutrient targets—so ordinary fitness users can act on a useful plan without
already knowing how to calculate it.

## Operating Context

The product is a Flutter application backed by the existing FastAPI and
PostgreSQL system. The product is mobile-first; Chrome/Web is an intentionally
supported development and visual-verification target for this redesign.

## Capabilities and Constraints

- Email/password authentication and password recovery.
- Resumable onboarding, deterministic nutrition targets, and profile/settings.
- Manual meal entry and AI Meal-Photo proposals that remain editable before save.
- Water tracking, additive daily steps, activity tracking, and daily dashboard.
- Gamification v1: XP, ranks E–S, quests, badges, and privacy-safe leaderboard.
- Barcode food scanning is retired and must not return.
- Backend API behavior, database behavior, and server-authoritative nutrition,
  steps, XP, rank, quest, badge, and authentication rules are frozen for this
  presentation redesign.
- AI artwork, when used, is generated during development and bundled as static
  assets; the application never calls an image provider at runtime.

## Brand Commitments

- Preserve the Kalonet name and recognizable dark green/obsidian identity.
- Keep the existing `kalonet_progress_emblem.png` as the primary brand asset.
- Use semantic accents for nutrition, hydration, steps, activity, gamification,
  warning, and error states.
- The interface should feel premium, calm, precise, and motivating rather than
  neon, childish, or over-decorated.

## Evidence on Hand

- Existing product and API documentation in `docs/project/`.
- Existing Flutter implementation under `frontend/lib/` and its widget/API tests.
- Existing static brand asset at
  `frontend/assets/brand/kalonet_progress_emblem.png`.
- Existing backend-authoritative feature behavior and Flutter providers.
- No user-provided photography, testimonials, or commercial claims may be
  invented for the UI.

## Product Principles

1. Make the next healthy action obvious.
2. Show authoritative progress without making users decode the calculation.
3. Reward consistency with clarity and restraint.
4. Keep functional fallbacks visible when AI or network services fail.
5. Preserve trust through accessible, responsive, and honest states.

## Accessibility & Inclusion

The redesign must keep important information available through text and
semantics, provide accessible tap targets and contrast, remain usable with
text scaling and keyboard-visible layouts, and avoid making state depend on
color or animation alone.
