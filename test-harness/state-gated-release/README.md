# State-gated release harness

This is a test-only Mod Organizer 2 mod. It contains console batch files and no
plugin, scripts, native code, or shipped runtime dependency.

Use it only on a disposable copy of a save. Do not save after running a batch.
Reload the pre-test save between scenarios; that is the restoration mechanism.

The commands use persistent EditorIDs instead of load-order prefixes and do not
use `prid` or any other selected-reference-dependent sequence.

See `docs/STATE_GATED_RELEASE_TEST.md` for the complete test matrix.
