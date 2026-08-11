# State-gated release harness

This is a test-only Mod Organizer 2 mod. It contains console batch files and no
plugin, scripts, native code, or shipped runtime dependency.

Use it only on a disposable copy of a save. Do not save after running a batch.
Reload the pre-test save between scenarios; that is the restoration mechanism.

The commands use persistent EditorIDs instead of load-order prefixes and do not
use `prid` or any other selected-reference-dependent sequence.

For Apparition Travel, the remove batch only unlearns the test power. Cast the
toggle a second time and wait for its dispel message before running the remove
batch. Removing an active toggle can leave Wizarding Traversal's global travel
speed override stuck at its instant-travel value.

See `docs/STATE_GATED_RELEASE_TEST.md` for the complete test matrix.
