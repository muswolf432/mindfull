# mindfull

A watchOS app for mental health. If the user's heartrate is below a certain value, a haptic feedback pattern will play to help them breathe (4 seconds in through nose, 6 seconds out of mouth - see heart rate variability training, resonance breathing).


Current issues:
Resonant haptics work fine when the screen is on, however the screen on the watch automatically turns off after a few seconds to save on battery. When the screen is off, the haptics do not play. Inside the console, I see that the haptics function is not called. Instead, the following notice is thrown: onChange(of: Int) action tried to update multiple times per frame.
