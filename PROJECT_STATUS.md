# TerraPlot LR — project status

Free, offline GPS land survey app for Liberia. Flutter, no backend.
Plan: the "TerraPlot LR — GPS Land Survey App Plan" doc (six phases).

## How the build works

- Only `lib/`, `assets/`, `test/`, `tool/`, `android_overrides/` are committed.
- GitHub Actions (`.github/workflows/build.yml`) runs `flutter create` to generate
  the `android/` folder, then `tool/patch_android.sh` adds permissions, the app
  name and the launcher icons from `android_overrides/res`.
- Every push to `main` analyses, runs tests, builds a release APK and publishes
  it as a GitHub Release (`build-N`) for easy download on a phone.
- Flutter pinned to 3.24.5; flutter_map pinned to 7.0.2.
- Release APK is signed with the debug key for now. A proper upload key is
  needed before Google Play (phase 6).

## Phase 1 — done in this build

- Design system: Field (dark) and Sunlight themes, Inter + JetBrains Mono
  bundled offline, amber accent, accuracy colours.
- App shell: Map, Projects, Points, Tools tabs + raised amber Measure button.
- Map home: live GPS dot with accuracy circle, accuracy pill, follow/recenter,
  street / satellite / night styles, live readout (decimal, DMS, UTM).
- Measure: walk-and-tap, auto-walk (3 m spacing, accuracy limit) and tap-map
  modes; live polygon with side lengths; rolling area; uncertainty; undo;
  select + delete corner; save to a project.
- Plot result: map, area in all units with 95% range, perimeter, field sheet
  (E/N, side lengths, bearings, accuracy), copy coordinates as CSV.
- Points: averaged GPS (30/60/120 s, accuracy-weighted), quick save, types,
  filter, detail page, navigate-to-point (distance + bearing).
- Tools: coordinate converter (lat/long ⇄ UTM 29N, decimal ⇄ DMS), settings
  (units, lot size, accuracy limit, sunlight, animations, surveyor name).
- Geodesy verified against pyproj and the WGS84 geodesic; see `test/`.

## Not yet (by phase)

- Phase 2: offline map downloads (needs a tile provider that allows caching).
- Phase 3: drag/insert corners, field-sheet editing.
- Phase 4: on-device database (data is in memory in phase 1), photos, compass.
- Phase 5: KML / GPX / CSV / GeoJSON / PDF export and import, sharing.
- Phase 6: field testing, Play Store signing and release.
