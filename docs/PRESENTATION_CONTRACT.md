# Provider presentation contract

The physical picker may begin with a provider-specific spoken response, but
presentation is never allowed to become the travel authority. The current
offline candidate generalizes the gameplay-proven Mirabelle path behind this
Papyrus API:

```papyrus
Float Function PlayPresentation(
    ObjectReference SpeakerRef,
    String VoicePath,
    String SubtitleText,
    Float VoiceDurationSeconds
) Global Native
```

On success the function queues playback/subtitle work and returns the measured
voice duration plus a `0.20` second task margin. A provider waits that returned
window before entering its existing dialogue-close and picker path. It returns
`0.0` on rejection, and the provider opens the picker without a presentation.

## Ownership

- The provider owns speaker choice, installed FUZ path, exact subtitle, and
  measured audio duration.
- Native code validates the request, pauses the current silent response,
  dispatches `SpeakSound` on the game task queue, and inserts a forced normal
  subtitle using the speaker handle and `SubtitleManager` lock.
- The picker still owns only UI and selection.
- The service still owns availability, fare, time, and movement.

The earlier Mirabelle-only diagnostic wrapper has been removed. Every provider
uses the same validated `PlayPresentation` contract.

## Safety constraints

- Runtime is locked to Skyrim `1.6.1170` for this native path.
- The corrected Address Library relocation must resolve ID `441582` to
  `SkyrimSE.exe+0x33D6A0`; any drift rejects playback.
- Speaker must resolve to a live actor. Its `ObjectRefHandle` is retained across
  the queued task instead of relying only on a later FormID lookup.
- Voice path is 1–260 characters, starts with `Voice/`, ends in `.fuz`, contains
  only a constrained filename alphabet, and rejects parent traversal.
- Subtitle is 1–512 bytes and rejects control characters.
- Measured duration must be finite and inside `(0, 30]` seconds.
- Failure always falls back to the picker. It never denies travel.

## First provider

Mirabelle supplies:

- `Voice/Skyrim.esm/FemaleUniqueMirabelleErvine/mg01__000d67d1_1.fuz`
- `Very good. Then we're done here.`
- exact XWM duration `2.147846` seconds
- returned presentation window `2.347846` seconds

The audio asset is read from the user's installed Skyrim data and is never
included in this repository or a package.

## Required verification

Offline:

- accept the known Mirabelle contract;
- reject command delimiters, traversal, wrong roots, control characters, and
  invalid durations;
- compile native and Papyrus bindings;
- audit the exact runtime and relocation guard;
- ensure packages contain no `.fuz`, `.xwm`, or `.wav` files.

Deferred gameplay check after the active game is closed:

- Mirabelle voice, subtitle, and lip sync begin once;
- parchment opens after the measured line rather than over it;
- cancel remains inert;
- funded selection charges once and travels;
- rejected/missing presentation still opens the map;
- ordinary faculty continue directly to the map.
