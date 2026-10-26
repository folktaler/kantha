import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/* Help is the site's own page (spec decision 3). In a browser the studio is on that site, at
   /studio, so Help is its path and opens in the same tab; on a phone it is kantha.app's, opened
   in the browser. The shop is the catsofkochi shop (spec decision 5), the same address on every
   platform; in a browser it opens in a new tab, so the studio stays open behind it. The privacy policy is the
   site's own page, as Help is. */
final _site = Uri.parse('https://kantha.app/');
final _shop = Uri.parse('https://catsofkochi.com/shop/');

Uri helpUriFor({required bool web, String? anchor}) => _onSite(Uri(path: '/help', fragment: anchor), web: web);
Uri _onSite(Uri page, {required bool web}) => web ? page : _site.resolveUri(page);

Uri helpUri([String? anchor]) => helpUriFor(web: kIsWeb, anchor: anchor);
Uri shopUri() => _shop;
Uri privacyUriFor({required bool web}) => _onSite(Uri(path: '/policies/privacy'), web: web);
Uri privacyUri() => privacyUriFor(web: kIsWeb);

/* In a browser: a page on another site opens in a new tab, the site's own in the studio's tab. */
String webWindowFor(Uri uri) => uri.hasAuthority ? '_blank' : '_self';

Future<void> openLink(Uri uri) async {
  await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication, webOnlyWindowName: webWindowFor(uri));
}
