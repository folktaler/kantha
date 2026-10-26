# Translating Kantha

Every word the studio shows is in one file: `messages/en.json`.
A translation is a copy of that file in another language, named by its
language tag, for example `messages/ml.json` for Malayalam or
`messages/pt-BR.json` for Brazilian Portuguese.

You can translate in 2 ways. Both end with a pull request on GitHub.

## Way 1: the inlang web editor

1. Open https://fink.inlang.com/github.com/folktaler/kantha.
2. Sign in with GitHub. The editor asks to fork the repository to your
   account.
3. Add your language, or pick one that is already there.
4. Translate the text in each box. Use the filters to show only the words
   that still need translating.
5. Push your changes from the editor. They go to your fork.
6. Select "Open a pull request". GitHub opens, and you write a short message
   saying which language it is.

## Way 2: edit the file yourself

1. Fork https://github.com/folktaler/kantha.
2. Copy `messages/en.json` to `messages/<your language tag>.json`.
3. Translate the words. Keep the keys (the names on the left) exactly as
   they are, nested the way `en.json` nests them. The inlang editor keeps
   that nesting for you.
4. Commit with a sign-off (see below) and open a pull request.

You do not need to translate everything at once. A word you leave out, or
leave empty, shows in English.

## What to keep as it is

- Names in curly brackets, like `{name}` or `{layout}`. The app puts a
  value there. You can move them within the sentence, but do not translate
  or remove them.
- Plurals, like `{n, plural, one {# piece} other {# pieces}}`. Translate the
  words inside each `{…}` and keep the rest. `#` is where the number goes.
  If your language has other plural forms, such as `few` or `many`, you can
  add them. The inlang editor shows a whole plural as one block it cannot
  edit, so translate plurals in the JSON file by hand.

## Sign off your commits

Every commit needs a Developer Certificate of Origin sign-off: a line at the
end of the commit message saying you have the right to give this work to the
project. See https://developercertificate.org.

Add it with `git commit -s`. It writes a line like this, with your name and
email:

```
Signed-off-by: Your Name <you@example.com>
```

If you used the web editor, add the sign-off to the commits in your fork
before you open the pull request, or ask in the pull request for help with
it.

## When a language goes live

A new language goes live only when the owner of Kantha approves it.

The studio checks some things itself, and refuses a file that fails them,
naming the file and what is wrong:

- a regional language, like `pt-BR`, needs its language file, `pt.json`,
  as well;
- Flutter must have its own words in the language;
- each message must keep English's `{names}`.

### Before a new language goes live

These are not checked. Look at each before the owner says yes:

- **The fonts for the printed sheet and the photo.** Their footer and
  caption are in the new language, so the fonts they use must have that
  script's letters.
- **A design's name.** A new design is named after its template, in the
  language the studio was in. If the language changes while a design is
  open and not yet saved, its name stays in the old language.
- **Plurals.** The inlang editor cannot edit them (see above). Check that
  they were translated in the file.

- **The studio** shows a language once its file is merged into `messages/`.
  People whose phone or browser is set to that language then see it: the
  studio's own words, and Flutter's words in that language too, such as
  Paste, or Dismiss read out by a screen reader.
- **The website**, kantha.app, stays in English for now. Its words are not
  in this repository.

## For maintainers

- `project.inlang.json` tells the inlang editor where the files are. Add a
  new language tag to `locales` and `languageTags` when its file is merged.
- In `studio/`, `dart run tool/l10n_from_messages.dart` makes
  `lib/l10n/app_<lang>.arb` for each file in `messages/`. Then run
  `flutter gen-l10n`. `--check` fails if any of these is out of date.
- `flutter test --tags l10n-probe --run-skipped` builds the studio with a
  test language and checks that it shows. A plain `flutter test` skips it.
