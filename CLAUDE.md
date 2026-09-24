# Currency Converter App (3umleh)

## What this app is
A simple currency converter iOS app named "3umleh". The app will automatically get updated rates for the user-selected currencies upon start. The user can add or remove currencies, tap and drag currencies for reorder, and select a main currency to base conversion on.

## Who's building this
I'm not a professional software developer — basic coding background, using Claude Code to do most of the implementation. Please:
- Make changes in small, single-purpose steps rather than big multi-file rewrites, so I can follow what changed and why.
- After each change, briefly explain in plain language what you did and why, not just show the diff.
- If something requires a manual step in Xcode (adding a capability, signing, adding a package dependency via Xcode's UI), say so explicitly and tell me exactly where to click.
- Prefer standard SwiftUI/Apple frameworks over third-party dependencies unless there's a clear reason not to.

## Tech stack
- SwiftUI (iOS 26 target)
- Xe currency API for rates
- No backend of our own

## Core pieces
1. main screen to show the user-selected currencies. In it, user can reorder currencies, remove currencie, and select a main currency to base conversion on
2. a screen to add a currency

## Xe API setup notes
- Request and response headers, payload, and responses will be provided.

## Conventions
- SwiftUI previews for every view where feasible, so changes can be checked visually without a full simulator run.
- Favor `async/await` over completion handlers.
