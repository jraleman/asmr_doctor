# ASMR Doctor

**A little care. A little quieter.**

A self-paced, illustrated Godot game about a tiny, magical clinic. Welcome an
overbooked office worker, a worried knight, a grumpy cloud, a dragon, a ghost
and a robot. Discover their favorite sounds and send them home a little lighter.

## Play

This is a game module inside the **DCS Base Game**, not a separate Godot project.
It uses the same studio opening, cartridge menu, glass UI, pause, settings,
achievements, cosmetic Store, Saves screen and results/share cards as the other
DeskCanSaw games.

From this folder:

```powershell
godot --path ..\.. -- --game=asmr_doctor
```

Or open `godot-base\project.godot` and choose **ASMR Doctor** in the collection.
The host includes **Windows - ASMR Doctor (standalone)** and
**Web - ASMR Doctor (standalone)** export presets with their own stable save
directory and the `asmr_doctor` feature tag.

## A shift at the clinic

Three appointments make a shift. There is no countdown, losing, passive stress
gain or reward for leaving the game idle.

Choose a tool, read the patient's hints, and give gentle care. Favorites work
faster; sensitive sounds work more slowly, but never block completion. A rhythm
ring suggests a pace for individual sounds; taking a long pause is always fine.
Very rapid presses do not earn extra calm.

| Tool | Interaction | Available after |
| --- | --- | --- |
| Whisper | Hold for a steady, soft hush | From the start |
| Wooden taps | Press once per tap | From the start |
| Feather brush | Hold for gentle strokes | From the start |
| Page turning | Press once per page | 2 completed patients |
| Silk crinkles | Press once per fold | 3 completed patients |
| Soft snips | Press once per snip | 4 completed patients |

Completed appointments and discovered favorites save immediately. Returning
patients share small updates in their stories. Closing a complete three-patient
shift earns **18 Kindness Tokens** for cosmetic plants, lamps and rugs. Unfinished
shifts pay nothing and restart on your next visit; completed journal entries stay.
The first six appointments introduce every patient.

Afternoon and midnight lighting alternate after completed shifts; Settings can
pin either one. **Soundscapes** mixes original synthesized stereo rain, fire and
warm room tone. **Rest mode** suspends appointments, capture, scoring and rewards
without losing the current patient. Return whenever you like.

## Controls and comfort

Mouse: choose a tool, then hold or press the care button or clinic illustration.
Keyboard defaults: **1-6** select tools, **Space** gives care, **J** opens the
journal, **O** opens soundscapes, **R** toggles rest, and **Esc** pauses.
Bindings are editable in the shared **Settings > Controls** tab. **Tab / Enter**
navigate buttons. The care action remains available without a microphone.

All treatment feedback is visual as well as audible. Shared reduced motion,
visual-effects, UI scale, audio-caption and bus-volume settings remain supported.
Game options add sound intensity, completely silent treatments, individual
snip/crinkle sound exclusions, microphone sensitivity and higher-contrast panels.
Muted tools still work. Ambience uses the shared Music bus; tools use SFX.
Landscape is the primary layout; short and portrait screens retain scrolling
content and reachable actions.

## Optional microphone

**Off by default, every visit.** Choose **Enable mic**, read the consent card and
explicitly enable capture. Stay quiet for room calibration, then whisper softly
or make spaced, gentle sounds. Headphones are recommended.

Only loudness above the room floor and sound onsets are measured. There is no
speech recognition or identification of brushes, pages or other real objects.
The selected tool determines the treatment. Loud input causes a small,
recoverable startle, never a failure.

Microphone PCM is read transiently into memory on the device. It is never
monitored through speakers, recorded, saved or uploaded. Capture has a dedicated
muted bus on desktop; Web capture uses an analyser with no speaker connection.
Web capture also releases tracks directly on focus loss or tab hiding, and
immediately closes streams granted after capture was stopped. Opening the
journal or soundscapes, pausing, resting, losing application focus,
finishing an appointment or leaving the scene stops capture and releases its resources.
It never restarts automatically. Owned treatment audio is suppressed and
ambience ducked while listening to reduce feedback.

Web microphone access requires **HTTPS or localhost** and browser permission.
Denied, missing and silent devices report a visible error; mouse and keyboard
remain available. Actual microphone quality, speaker leakage and device/browser
permission UX still need hardware testing.

## Saves and assets

The declared clinic save is `user://asmr_doctor_clinic.cfg`. The shared framework
owns settings, achievements and the per-game cosmetic wallet. Its Saves screen
can back up, restore or delete this game's progress independently. Damaged or
newer clinic saves are never overwritten; earning is disabled with recovery
instructions, while no-goal rest remains usable.

All clinic art, six portraits, vector branding and procedural stereo audio are
original and game-owned. Shop previews and share images reuse the real clinic
illustration. Share images contain no microphone data; their QR opens the studio
website, not a public patient record.

The shared How to Play screen includes a captioned recording of real care,
patient transitions and rest mode. Regenerate it from the host with
`.\tools\record_tutorials.ps1 -Games asmr_doctor`; the recorder isolates saves and
never enables a microphone.

This first release does not implement specialist wings, shareable playlists,
spoken narration or photo/audio recording. It is fictional entertainment, not
medical treatment.

## Regression checks

Run from this game folder, with the host's imports/class cache up to date:

```powershell
godot --headless --path ..\.. --editor --import --quit
godot --headless --path ..\.. --script res://games/asmr_doctor/tests/clinic_session_test.gd -- --game=asmr_doctor
godot --headless --path ..\.. --script res://games/asmr_doctor/tests/clinic_audio_test.gd -- --game=asmr_doctor
godot --headless --path ..\.. --script res://games/asmr_doctor/tests/clinic_scene_test.gd -- --game=asmr_doctor
godot --path ..\.. --script res://games/asmr_doctor/tests/clinic_view_test.gd -- --game=asmr_doctor
```

The scene suite preserves existing clinic progress, achievements, wallet and
changed settings. It drives actual pointer/keyboard events through two complete
shifts. The view suite needs a real Compatibility graphics window; optional
`--asmr-capture=<directory>` saves its rendered screens. On Windows, automated
PowerShell runners must use `Start-Process -NoNewWindow -Wait -PassThru` and check
`.ExitCode`, because the Godot GUI executable does not block `& godot`.
