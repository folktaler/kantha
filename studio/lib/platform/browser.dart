import 'browser_io.dart' if (dart.library.js_interop) 'browser_web.dart' as impl;

/* Safari on an iPhone clears a site's data after 7 days without a visit, unless the site is on the Home Screen; the
   studio's phone says so under its top bar (device.safariBanner). Chrome, Firefox and Edge on an iPhone name themselves
   (CriOS, FxiOS, EdgiOS) beside "Safari"; an iPad says iPad. Opened from the Home Screen, `standalone` is true and the
   rule does not apply. */
bool isSafariOnIphone(String userAgent, bool standalone) =>
    !standalone &&
    userAgent.contains('iPhone') &&
    userAgent.contains('Safari') &&
    !['CriOS', 'FxiOS', 'EdgiOS'].any(userAgent.contains);

/* This browser, asked when the app is made: on a phone app, never. */
bool safariOnIphone() => impl.safariOnIphone();
