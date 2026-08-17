You're picking up an implementation plan in this repo.

**Project:** flutter_proje — Yakında, canlı konum paylaşımı, yakındaki yerler ve arkadaş takip sistemi sunan Flutter & Firebase mobil uygulaması.

**Plan:** `docs/plans/2026-08-17-hava-durumu-plan.md`

**Goal:** Add a "Hava Durumu" tab to the app that shows the current weather (temperature + condition) for the user's GPS location.

**Tech:** No new packages. Reuses `http` (already a dependency, used by `overpass_service.dart`), `geolocator` (via existing `LocationService`), `latlong2` (`LatLng`).

**Tasks:**
- TASK-01: Weather service (Open-Meteo client + model)
- TASK-02: Weather screen (GPS location + loading/error/loaded UI)
- TASK-03: Wire the tab into bottom navigation

**How to execute (full execution contract is at the top of the plan file):**
1. When I ask for a task ("do TASK-03"), read **only** that task's block in the plan.
2. Stay strictly inside its **Targets** — don't edit files outside that list.
3. Follow the **Implementation Notes**; don't invent extra scope.
4. When **Done When** and **Verification** are satisfied, **stop and report**. Wait for my approval before moving on.
5. If verification fails, report and stop. Don't attempt fixes outside the task's Targets.

Start by reading `docs/plans/2026-08-17-hava-durumu-plan.md` end-to-end, then wait for me to ask for the first task. Don't begin TASK-01 until I ask.
