# Repository scope

The maintained product is the consolidated `DiegeticTravel` release. Earlier
standalone plugins and research scripts were useful while discovering the
implementation, but they are not all part of the maintained product surface.

`config/repository-scope.json` is the machine-readable inventory. It separates:

- release modules and build/test entry points;
- xEdit scripts invoked by the consolidated generator and semantic audit;
- maintained visual-authoring tools;
- deferred or superseded modules; and
- local third-party or generated directories that must remain untracked.

## Source-size interpretation

The shipped implementation is approximately 6,440 source lines:

- 4,130 lines of production C++ and headers; and
- 2,310 lines across the 22 release Papyrus sources.

Native tests add approximately 694 lines. PowerShell, xEdit Pascal, the map
calibrator, documentation, and source assets are development infrastructure and
must not be reported as runtime mod LOC.

## Cleanup policy

Repository cleanup is performed as isolated commits after a known-good
checkpoint. A cleanup commit may remove a tool only when it is absent from the
declared release dependency graph and the consolidated offline checks still
pass. Removed research remains recoverable from Git history.

Generated packages, compiler dependencies, local research downloads, and logs
belong under ignored roots. Stable source inputs that cannot yet be reproduced
from the repository remain tracked and must be documented explicitly.
