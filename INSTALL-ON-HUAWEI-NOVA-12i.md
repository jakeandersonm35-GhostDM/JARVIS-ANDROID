# Installing JARVIS on a Huawei nova 12i

The nova 12i is a 64-bit (arm64) phone running HarmonyOS/EMUI with **no Google
Mobile Services**. The APK works on it, but a few things need setting up.

## 1. Install the APK
1. Build the APK (see `BUILD-APK-INSTRUCTIONS.txt`) and copy
   `JARVIS-Android-APK.apk` to the phone (USB cable, Huawei Share, or download it
   straight from the GitHub artifact page in the phone browser).
2. Open it from **Files**. When prompted, allow installs from that app
   (**Settings > Security > More security settings > Install apps from external
   sources** if you need to find it later).
3. If the "Security check / Pure Mode" screen blocks it, tap **Continue install**.
   Pure Mode (Settings > Security) can be switched off if it keeps blocking.

## 2. Permissions (JARVIS has a Permissions screen that shows what is missing)
| Feature | What to do |
| --- | --- |
| Screen control (tap/type/scroll) | Settings > Accessibility > Installed services > JARVIS > On |
| Floating bubble | Settings > Apps > Apps > JARVIS > Display over other apps |
| Email / SMS triage | Settings > Notifications > Notification access > JARVIS |
| Camera (Jarvis Eye) | Allow when JARVIS asks |
| Files tool | Settings > Apps > JARVIS > Permissions > Files and media (All files access). Without it, files go to the app's own folder and JARVIS tells you the path. |

If Accessibility or Notification access is greyed out, open
**Settings > Apps > Apps > JARVIS**, tap the **⋮** menu (or "More") and choose
**Allow restricted settings**, then try again.

## 3. Keep it alive in the background (important on Huawei)
Huawei aggressively kills background apps, which stops "Hey JARVIS" and the
accessibility service.
- **Settings > Battery > App launch > JARVIS** -> turn off *Manage automatically*,
  then enable **Auto-launch**, **Secondary launch** and **Run in background**.
- In the recent-apps view, pull JARVIS down (or tap the lock icon) so it is not
  swept away by "Clear all".

## 4. Voice on a phone without Google services
- **Typing commands and chat work normally.**
- **Voice output:** *Ultra-Realistic Studio Neural Voice* (JARVIS settings, **on by
  default**) streams a voice over the internet and does not need Google. Offline
  text-to-speech needs a TTS engine installed on the phone; JARVIS no longer hangs
  if none exists.
- **Voice input ("Hey JARVIS")** uses Android's built-in speech recognizer. If your
  phone has none, JARVIS now shows *VOICE INPUT UNAVAILABLE // TYPE YOUR COMMANDS*
  instead of looping silently. It starts working if a speech service is installed
  (for example Google's "Speech Services" / the Google app, or a Huawei voice
  service if your region provides one).

## 5. First run
Open JARVIS > Settings and enter your AI provider API key (DeepSeek by default).
