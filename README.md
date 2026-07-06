# ULAP → NEB Position Paper Portal

An online portal where the ULAP Secretariat submits position papers to the
**National Executive Board (NEB)** for review and approval.

## What it does

- **Registry** of position papers — bill/measure reference, policy area, requesting
  office, priority, ULAP's recommended position, and status.
- **Draft view** — each paper's issue summary and ULAP's recommended position, with
  the full drafted paper attached under Documents.
- **Q&I assistant** — ask questions about a measure; answers are grounded in the record.
- **Revision notes** — threaded notes between the NEB and the Secretariat.
- **Document uploads** — attach supporting files to a paper.
- **Sign-off approvals** — each NEB member records their decision with their name and
  signature (draw on a phone/computer, or type). A live counter tracks progress toward
  the required number of approvals to endorse.

## Board

Signatories are drawn from the **ULAP National Executive Board, 2026–2029**.

## Technical notes

- Single self-contained `index.html` — no build step, no dependencies, no tracking.
- Served as a static site via GitHub Pages.
- In this version, each viewer's approvals, notes, and uploads are stored in their own
  browser (localStorage). A shared multi-user backend (real accounts, shared state,
  permanent file storage) is a planned next phase.
