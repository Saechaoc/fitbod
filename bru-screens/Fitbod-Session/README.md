# Fitbod Session

This folder is a snapshot of the Claude Design project "Fitbod", synced on 2026-10-02.
Source: https://claude.ai/design/p/0d1863d5-d226-44c1-a519-407f6c516a62

## What is where

- `Fitbod Session.html` is the full design canvas: the five Active Session directions, then every brutalist app screen grouped by phase.
- `Fitbod Session-print.html` is the print layout, with a description and requirement IDs for each screen. It opens the print dialog when it loads.
- `debug.html` shows the original 17 screens side by side.
- `bru-theme.jsx` holds the shared BRU color and font tokens and the primitives the screens use (BruPhone, BruHeader, BruChip, BruButton, sheets, alerts, menus).
- `variant-*.jsx` are the five Active Session directions. `variant-brutalist.jsx` is the chosen Active Session screen.
- `app.jsx` lays out the canvas. `design-canvas.jsx` and `ios-frame.jsx` are Claude Design's canvas and device frame.
- `use-session.jsx` and `workout-data.js` supply the sample workout.
- `screens/` has a 1179x2556 PNG of every artboard, named `<section>--<artboard>.png`.

The screen components live one level up, in `bru-screens/*.jsx`.
The Swift code and planning docs point at that copy, so each screen exists only once.

## Differences from the project

The three HTML pages load screens from `../<screen>.jsx` instead of `bru-screens/<screen>.jsx`.
Every other file is byte-identical to the project.
The project's `screenshots/` and `uploads/` folders were not copied.
They hold Claude's working captures and pasted reference images, not design source.

## Viewing the canvas

Opening an HTML file directly shows a blank page, because the JSX files load over HTTP.
Serve the design folder from the repo root instead:

    python3 -m http.server 8000 -d bru-screens

Then open http://localhost:8000/Fitbod-Session/Fitbod%20Session.html
The pages need internet access, because React, Babel and the fonts load from unpkg and Google Fonts.
