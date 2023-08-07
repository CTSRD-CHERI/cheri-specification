Steps to Finalize New Release
=============================

- Generate a diff relative to the previous version

- Add any missing papers to the Publications section in
  chap-intro.tex

- Update app-versions-<version>.tex with a list of changes from
  the diff

- Review changes since the previous version to ensure the list
  of authors is up to date in cheri-architecture.tex

- Review funding acks in cheri-architecture.tex

- Review acknowledgements.tex to add new projects, DARPA PMs and
  SETAs, contractors, and students

- Request a TR number
  - Requires a tenative (but realistic) publishing date, allowing
    for any needed review
  - Requires updated bibiliography information (e.g. any new
    authors

- Add a new entry with the new TR number to cheri.bib

- Update reference to existing version in chap-intro.tex with new
  version and new TR.

- Add a new \item in the ISA version history in app-versions.tex
  containing an overall summary of the changes in this version,
  the TR number, and expected publication month

- Update last paragraph in abstract.tex with summary from
  app-versions.tex

- Add a new entry in cheri-version-table.tex

- Update version number and set explicit \date{} in
  cheri-architecture.tex

- Tag the release as 'vX.Y'.

Steps to Begin Next Version
===========================

- Update version number to "N+1 - DRAFT" and remove explicit
  \date{} from cheri-architecture.tex

- Update version number in abstract.tex and stub out the
  last paragraph to the first sentence.

- Add a stub app-versions-N+1-0.tex and add it to the end of
  app-versions.tex.

- Update the "CHERI ISA Version History" section in chap-intro.tex
  to reference N+1.0 including the new app-versions-N+1-0.tex.
