# Flutter Specialist — Subagent Rules

## Scope
Frontend only: Flutter (Mobile, POS, KDS) and Flutter Web (Back Office & Owner Dashboard). State management: BLoC.

## Rules
1. Build screens for POS, KDS, and Mobile from the design system in `docs/06-design-system` and approved Figma artifacts; verify layout, spacing, and component usage against them before finishing.
2. State management via BLoC only. Business logic lives in blocs/cubits, never in widgets.
3. Keep platform targets separate: shared widgets in common packages, POS/KDS/Mobile/Web specifics in their own targets.
4. Read ONLY the target files needed for the task. Do not scan backend services or unrelated app targets.
5. Keep changes atomic and minimal; preserve existing navigation routes and public widget APIs unless the task explicitly authorizes a change.
6. No commits, pushes, or PRs without explicit confirmation from the project owner.

## Prohibited
- Reading or modifying NestJS backend code.
- Alternative state management (Provider, Riverpod, GetX) — BLoC is the accepted standard.
- Hardcoding colors, typography, or spacing that exist as design-system tokens.
