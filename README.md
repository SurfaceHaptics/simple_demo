# PhotoFeel — minimal TanvasTouch photo demo

Load a photo, feel it on the panel. That is the whole app.

It is the smallest possible use of the TanvasTouch SDK: one `QTView` laid over the displayed
image and one `QTSprite` textured with a grayscale version of it. No screen capture, no
trackpad modes, no Python, no direct USB access.

## Requirements

- A TanvasTouch **touchscreen** (the photo is shown on the haptic surface, so touch is absolute)
- Visual Studio 2022 (Desktop development with C++), CMake ≥ 3.13, Python 3
- **Conan 1.x** (fetches Qt at build time):

```powershell
pip install -r requirements.txt
```

> **Assumed SDK location:** `deploy-sdk.ps1` expects the TanvasTouch SDK at
> `C:\Program Files\TanvasTouch SDK` (hardcoded). Install the SDK there, or edit
> `$SdkRoot` in `deploy-sdk.ps1` before deploying.

## Build and run

```powershell
.\build.ps1                  # first run builds Qt from source; expect a long wait
.\deploy-sdk.ps1             # copies Qt DLLs + the TanvasTouch QML plugin next to the exe
Start-Process "C:\Program Files\TanvasTouch SDK\Engine\TanvasTouch Engine.exe"
.\build\bin\PhotoFeel.exe
```

The Engine must be running. It owns the USB device and does all the rendering — without it
the app looks fine and feels like nothing.

## Using it

Press **Open photo…** or drag an image onto the window. Then drag a finger across the photo.

- **Invert** flips which parts you feel. See "Polarity" below.
- **Show haptic map** displays the grayscale texture instead of the photo, so you can see
  what you are feeling.

## How it works

A haptic texture is a grayscale image read as a friction map: `0` is the natural surface and
`255` is the most extra friction the hardware can add. The SDK inverts on load —
`QTSprite` stores **`friction = 255 − gray`** — so out of the box **dark parts of your photo
feel rough and bright parts feel slick**. The Invert switch flips the source image first if
you would rather feel the highlights.

Three pieces:

| File | Job |
|---|---|
| `src/hapticimage.cpp` | Load the photo, convert to `Format_Grayscale8`, downscale, optionally invert, write a PNG to `%TEMP%` |
| `src/main.qml` | Show the photo, and place a `QTView`/`QTSprite` exactly over the painted pixels |
| `src/main.cpp` | Start Qt, add the exe directory to the QML import path so `co.tanvas.tanvastouch` resolves |

### The alignment rule

The Engine samples the sprite as `UV = (touch_pos − sprite_pos) / sprite_size`. The sprite
rectangle *is* the coordinate system, so it must match the pixels on screen exactly or the
photo will feel shifted or stretched relative to what you see.

Because `Image` uses `fillMode: PreserveAspectFit`, the painted area is smaller than the item
and letterboxed inside it. So the view binds to `paintedWidth`/`paintedHeight` plus centering
offsets, not to `anchors.fill`. `mapToGlobal` is not a bindable expression, which is why
`updatePhotoScreenRect()` is re-run on every window move and resize.

The toolbar is deliberately outside the view, so you feel nothing under the UI chrome.

### Two details that look optional but are not

**Cache busting.** `hapticimage.cpp` appends `?t=<ms>` to the texture URL. Qt caches images by
URL, so reloading the same `%TEMP%` path would serve the stale texture and the haptics would
silently stay on the first photo you opened.

**Texture size cap.** Photos are downscaled to the screen resolution before upload. The Engine
samples roughly one texel per screen unit, so a 12 MP source is megabytes of upload for detail
that can never be felt.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Nothing felt at all | Engine not running, or the window is not focused (`QTView.enabled` requires `win.active`) |
| QML error about `co.tanvas.tanvastouch` | `deploy-sdk.ps1` was not run, SDK not at `C:\Program Files\TanvasTouch SDK`, or deploy ran before the build |
| Feels like the inverse of what you expect | Expected: `friction = 255 − gray`. Use the Invert switch |
| Haptics offset from the image | The sprite rect drifted from the painted rect — check `updatePhotoScreenRect()` is firing |
| Haptics frozen on the first photo | Cache busting broken (missing `?t=`) |
| Build fails with "Unsupported image format" for PNG | Qt built without PNG. Run `.\build.ps1 -Clean -ForceQtRebuild` |
| Qt link errors mentioning `inflate`/`deflate`/zlib | Corrupt Conan cache. Run `.\build.ps1 -Clean -CleanCache` |
