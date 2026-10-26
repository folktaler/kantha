# 1. Contributing

Welcome to Kantha. You can contribute in these ways:

1. **Bug reports.** A one-line report is hard to understand and check.
	1. Use the bug report form, and give a clear description and the steps that show the bug.
	2. Search the existing issues first, so the same bug is not reported twice.
	3. An issue without enough information to show the bug may be closed.
	[Report a bug here](../../issues/new/choose).

2. **Ideas for features or changes.** If a change would help many people who use Kantha, open a
   feature or change request.
	1. Search the existing issues first.
	2. What fits the project, its scope and its direction is the maintainer's call. Please respect that,
	   and keep the discussion friendly.
	3. Explain clearly why the change is needed. A well-researched, detailed request saves everyone time.
	4. A request without enough information may be closed.

3. **Docs.** Corrections to the README, these notes and `docs/translating.md` are welcome. Changes to the
   words a reader sees in the studio are decided by the owner (see section 2).

4. **Translations.** See [Translations](#translations).


# 2. Pull requests

A pull request, a new feature or a small fix, has to fit the project's scope, its goals and the way the
code is already written. Its effect on speed, ease of use and stability has to be understood. A big pull
request is hard to review, and reviewing one can take longer than writing it. So whether a pull request is
merged is the maintainer's call.

To keep it smooth:

1. **Send a proposal first.** Open an issue that says what you want to do, why it fits the project and
   how you plan to build it, before you spend time on code.

2. **Send small pull requests.** One change each. The smaller it is, the easier it is to review and
   test. Do not bundle several features into one.

3. **Pull requests are squashed when merged.** A pull request may change a lot over several commits
   before it is approved. On merge, its commits become one.

4. **Words and design are decided by the owner.** A change to words a reader sees (anything in
   `messages/`), or to how the studio looks, is merged only when the owner agrees to it. Say in your proposal what a reader would see change.

5. **The numbers are fixed.** A piece is cut at 6 cm square and finishes at 4 cm; a panel is 5 × 7
   pieces. The printed pattern depends on them (`studio/lib/solver/geometry.dart`). A change to them will
   not be merged.

6. **All words live in `messages/`.** Do not write words a reader sees into the code. Add a key to
   `messages/en.json`, then run `dart run tool/l10n_from_messages.dart` and `flutter gen-l10n` in `studio/`
   to make the studio's word files.

7. **A fork uses another name and icon.** If you publish your own copy of the app, read `TRADEMARKS.md`.

## Sign your commits (DCO)

Every commit must carry a `Signed-off-by` line. It says you wrote the change, or have the right to submit
it, under the project's licence, as the [Developer Certificate of Origin](https://developercertificate.org)
sets out. Add it with `-s`:

```bash
git commit -s -m "Say what the change does"
```

The name and email in the line must match the commit's author. A check on every pull request fails
without it. To sign commits you already made: `git rebase --signoff master`, then push again.

## Run the checks

Every pull request runs these checks on GitHub: `flutter analyze` and `flutter test --exclude-tags pixels`.
Run them yourself before you open a pull request. The maintainer runs the rest before each release: the 2
journeys in Chrome, the tests that run only in Chrome, the test with a test language, and the pixel
comparisons. You are welcome to run them too.

The studio, in `studio/` (Flutter 3.47.6):

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags pixels
```

If you changed the studio, also run the 2 journeys in Chrome, in `studio/`. Set `CHROME_EXECUTABLE` to
a Chrome or Chrome for Testing binary; the script fetches the matching chromedriver the first time:

```bash
CHROME_EXECUTABLE="/path/to/chrome" ./tool/journeys.sh
```

And the tests that run only in Chrome:

```bash
grep -rlE "^@TestOn\('browser'\)|'chrome-only'" test | sort | xargs flutter test --platform chrome
```

The pixel comparisons check the shared photo and the sheet's footer against pictures drawn on a Mac. Other
machines draw text a little differently, so they pass only on a Mac. The maintainer runs them there before each
release:

```bash
flutter test --tags pixels
```

And the test that builds the studio with a test language, which the command above skips:

```bash
flutter test --tags l10n-probe --run-skipped
```

## Translations

Every word the studio shows is in `messages/en.json`. A translation is a copy of it in
another language. [docs/translating.md](docs/translating.md) says how to make one, in the inlang web
editor or by hand, and when a new language goes live.


# 3. Be respectful

Most open-source projects are the work of people who share it for free and expect nothing back.

So:

1. Be respectful. Do not use aggressive or snarky language. It wastes time and goodwill.
2. Do not demand. How much you want a feature does not decide whether it is worth the maintainer's time.
   Whether, how and when something is built is up to the maintainer.
3. Do not nitpick or start discussions that waste time.
4. Search the docs and the issues before you ask a question.
5. The maintainer owes you nothing, including time to answer messages or free support. If you want to be
   heard, be respectful.
6. If this does not suit you, you do not have to use the project. You can fork it and change it as you
   like, within the terms of the licence.

Thank you.

This file follows the shape of [listmonk's contributing guide](https://github.com/knadh/listmonk/blob/master/CONTRIBUTING.md).

Questions about contributing: hello@kantha.app.
