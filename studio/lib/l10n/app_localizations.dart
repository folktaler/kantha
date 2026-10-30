import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @canvasSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get canvasSave;

  /// No description provided for @canvasHideControls.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get canvasHideControls;

  /// No description provided for @canvasPanelName.
  ///
  /// In en, this message translates to:
  /// **'Design name'**
  String get canvasPanelName;

  /// No description provided for @canvasDefaultName.
  ///
  /// In en, this message translates to:
  /// **'{layout}'**
  String canvasDefaultName(String layout);

  /// No description provided for @canvasPanelsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'My designs'**
  String get canvasPanelsEyebrow;

  /// No description provided for @canvasNewDesign.
  ///
  /// In en, this message translates to:
  /// **'New design'**
  String get canvasNewDesign;

  /// No description provided for @canvasCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String canvasCopyName(String name);

  /// No description provided for @canvasDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get canvasDuplicate;

  /// No description provided for @canvasMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get canvasMore;

  /// No description provided for @canvasMountEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Mount'**
  String get canvasMountEyebrow;

  /// No description provided for @canvasStitchesSwitch.
  ///
  /// In en, this message translates to:
  /// **'Show stitches'**
  String get canvasStitchesSwitch;

  /// No description provided for @canvasStitchColoursEcru.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get canvasStitchColoursEcru;

  /// No description provided for @canvasStitchColoursMadder.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get canvasStitchColoursMadder;

  /// No description provided for @canvasStitchColoursIndigo.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get canvasStitchColoursIndigo;

  /// No description provided for @canvasStitchColoursTurmeric.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get canvasStitchColoursTurmeric;

  /// No description provided for @canvasStitchColoursLeaf.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get canvasStitchColoursLeaf;

  /// No description provided for @canvasStitchColoursBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get canvasStitchColoursBlack;

  /// No description provided for @canvasNoSaved.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. Press Save and your design waits here.'**
  String get canvasNoSaved;

  /// No description provided for @canvasZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get canvasZoomIn;

  /// No description provided for @canvasZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get canvasZoomOut;

  /// No description provided for @canvasFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get canvasFit;

  /// No description provided for @canvasZoomPercent.
  ///
  /// In en, this message translates to:
  /// **'{n}%'**
  String canvasZoomPercent(String n);

  /// No description provided for @canvasSolving.
  ///
  /// In en, this message translates to:
  /// **'Arranging the cloth…'**
  String get canvasSolving;

  /// No description provided for @canvasCantSolve.
  ///
  /// In en, this message translates to:
  /// **'This box holds fewer than 35 pieces — open another box.'**
  String get canvasCantSolve;

  /// No description provided for @canvasSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to My designs.'**
  String get canvasSaved;

  /// No description provided for @canvasSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String canvasSaveFailed(String error);

  /// No description provided for @canvasMissingCloth.
  ///
  /// In en, this message translates to:
  /// **'That design uses cloth that is no longer in the box.'**
  String get canvasMissingCloth;

  /// No description provided for @canvasDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get canvasDelete;

  /// No description provided for @canvasDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Not deleted: {error}'**
  String canvasDeleteFailed(String error);

  /// No description provided for @canvasCellLabel.
  ///
  /// In en, this message translates to:
  /// **'Row {r}, column {c} — {name}'**
  String canvasCellLabel(String r, String c, String name);

  /// No description provided for @canvasSwatchLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} — {left} of {stock} pieces still free'**
  String canvasSwatchLabel(String name, String left, String stock);

  /// No description provided for @canvasLayoutsContrastTitle.
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get canvasLayoutsContrastTitle;

  /// No description provided for @canvasLayoutsContrastName.
  ///
  /// In en, this message translates to:
  /// **'Every seam earns its keep, light against dark.'**
  String get canvasLayoutsContrastName;

  /// No description provided for @canvasLayoutsGradientTitle.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get canvasLayoutsGradientTitle;

  /// No description provided for @canvasLayoutsGradientName.
  ///
  /// In en, this message translates to:
  /// **'Pale at the top corner, falling to the darkest cloth.'**
  String get canvasLayoutsGradientName;

  /// No description provided for @canvasLayoutsMedallionTitle.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get canvasLayoutsMedallionTitle;

  /// No description provided for @canvasLayoutsMedallionName.
  ///
  /// In en, this message translates to:
  /// **'Dark heart, lightening out to the edge.'**
  String get canvasLayoutsMedallionName;

  /// No description provided for @canvasLayoutsWaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get canvasLayoutsWaveTitle;

  /// No description provided for @canvasLayoutsWaveName.
  ///
  /// In en, this message translates to:
  /// **'Bands of tone on the diagonal, the bargello way.'**
  String get canvasLayoutsWaveName;

  /// No description provided for @canvasLayoutsFramedTitle.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get canvasLayoutsFramedTitle;

  /// No description provided for @canvasLayoutsFramedName.
  ///
  /// In en, this message translates to:
  /// **'Dark outer ring anchoring the panel.'**
  String get canvasLayoutsFramedName;

  /// No description provided for @canvasLayoutsCrossTitle.
  ///
  /// In en, this message translates to:
  /// **'Cross'**
  String get canvasLayoutsCrossTitle;

  /// No description provided for @canvasLayoutsCrossName.
  ///
  /// In en, this message translates to:
  /// **'Dark diagonals, light in the triangles between.'**
  String get canvasLayoutsCrossName;

  /// No description provided for @canvasLayoutsSpectrumTitle.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get canvasLayoutsSpectrumTitle;

  /// No description provided for @canvasLayoutsSpectrumName.
  ///
  /// In en, this message translates to:
  /// **'Cool on the left, running warm to the right.'**
  String get canvasLayoutsSpectrumName;

  /// No description provided for @canvasLayoutsBoroTitle.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get canvasLayoutsBoroTitle;

  /// No description provided for @canvasLayoutsBoroName.
  ///
  /// In en, this message translates to:
  /// **'No pattern, just nothing repeating or muddy.'**
  String get canvasLayoutsBoroName;

  /// No description provided for @canvasLayoutsBlocksTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get canvasLayoutsBlocksTitle;

  /// No description provided for @canvasLayoutsBlocksName.
  ///
  /// In en, this message translates to:
  /// **'Colour gathered where the cloth wants to cluster, seams still held apart.'**
  String get canvasLayoutsBlocksName;

  /// No description provided for @canvasLayoutsMedallionPrintTitle.
  ///
  /// In en, this message translates to:
  /// **'Ripple'**
  String get canvasLayoutsMedallionPrintTitle;

  /// No description provided for @canvasLayoutsMedallionPrintName.
  ///
  /// In en, this message translates to:
  /// **'The busiest cloth at the heart, plainer out to the edge.'**
  String get canvasLayoutsMedallionPrintName;

  /// No description provided for @canvasLayoutsHeartTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get canvasLayoutsHeartTitle;

  /// No description provided for @canvasLayoutsHeartName.
  ///
  /// In en, this message translates to:
  /// **'A red heart on the lightest cloth, every seam around it held apart.'**
  String get canvasLayoutsHeartName;

  /// No description provided for @canvasMountsNoneName.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get canvasMountsNoneName;

  /// No description provided for @canvasMountsFrameName.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get canvasMountsFrameName;

  /// No description provided for @canvasMountsToteName.
  ///
  /// In en, this message translates to:
  /// **'Tote'**
  String get canvasMountsToteName;

  /// No description provided for @canvasNotFillableNoColour.
  ///
  /// In en, this message translates to:
  /// **'this box has no cloth with that colour'**
  String get canvasNotFillableNoColour;

  /// No description provided for @canvasNotFillableFewPieces.
  ///
  /// In en, this message translates to:
  /// **'this box has too few pieces near that colour to fill the shape'**
  String get canvasNotFillableFewPieces;

  /// No description provided for @canvasNotFillableNoDarkEnough.
  ///
  /// In en, this message translates to:
  /// **'this box has no cloth of that colour dark enough to stand against the ground'**
  String get canvasNotFillableNoDarkEnough;

  /// No description provided for @canvasNotFillableNoFamilies.
  ///
  /// In en, this message translates to:
  /// **'this box has too few coloured cloths to make its colour families'**
  String get canvasNotFillableNoFamilies;

  /// No description provided for @canvasLayoutCannot.
  ///
  /// In en, this message translates to:
  /// **'{title} — {why}'**
  String canvasLayoutCannot(String title, String why);

  /// No description provided for @canvasCantFill.
  ///
  /// In en, this message translates to:
  /// **'This box cannot fill this layout: {why}.'**
  String canvasCantFill(String why);

  /// No description provided for @canvasYourBoxes.
  ///
  /// In en, this message translates to:
  /// **'Your boxes'**
  String get canvasYourBoxes;

  /// No description provided for @canvasShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get canvasShare;

  /// No description provided for @canvasSavePhoto.
  ///
  /// In en, this message translates to:
  /// **'Save photo'**
  String get canvasSavePhoto;

  /// No description provided for @canvasShareTo.
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get canvasShareTo;

  /// No description provided for @canvasSharePhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t prepare the photo — try again'**
  String get canvasSharePhotoFailed;

  /// No description provided for @canvasDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be made. Try again in a minute.'**
  String get canvasDownloadFailed;

  /// No description provided for @canvasMadeWith.
  ///
  /// In en, this message translates to:
  /// **'made with kantha.app'**
  String get canvasMadeWith;

  /// No description provided for @canvasUpcycled.
  ///
  /// In en, this message translates to:
  /// **'Upcycled from {n} cloth pieces'**
  String canvasUpcycled(String n);

  /// No description provided for @canvasMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get canvasMenu;

  /// No description provided for @canvasHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get canvasHelp;

  /// No description provided for @canvasDeleteSure.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? This cannot be undone.'**
  String canvasDeleteSure(String name);

  /// No description provided for @canvasShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get canvasShop;

  /// No description provided for @canvasPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get canvasPrivacy;

  /// No description provided for @canvasSavedFirst.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. Back up from the menu to keep a copy.'**
  String get canvasSavedFirst;

  /// No description provided for @canvasNothingToSave.
  ///
  /// In en, this message translates to:
  /// **'Add 35 pieces to your box before saving.'**
  String get canvasNothingToSave;

  /// No description provided for @canvasAddMore.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Add {n} more piece to complete the grid.} other{Add {n} more pieces to complete the grid.}}'**
  String canvasAddMore(num n);

  /// No description provided for @canvasEmptyCell.
  ///
  /// In en, this message translates to:
  /// **'Row {r}, column {c} — tap to add cloth'**
  String canvasEmptyCell(String r, String c);

  /// No description provided for @canvasSwatchLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} left'**
  String canvasSwatchLeft(String n);

  /// No description provided for @canvasSwatchAllUsed.
  ///
  /// In en, this message translates to:
  /// **'{name} — all {stock} pieces are in the design. Tap to add more.'**
  String canvasSwatchAllUsed(String name, String stock);

  /// No description provided for @canvasTabCloth.
  ///
  /// In en, this message translates to:
  /// **'Cloth box'**
  String get canvasTabCloth;

  /// No description provided for @canvasTabDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get canvasTabDesign;

  /// No description provided for @canvasTabPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get canvasTabPreview;

  /// No description provided for @canvasZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get canvasZoom;

  /// No description provided for @canvasPrintPattern.
  ///
  /// In en, this message translates to:
  /// **'Print pattern PDF'**
  String get canvasPrintPattern;

  /// No description provided for @canvasPrintPatternNote.
  ///
  /// In en, this message translates to:
  /// **'A4 — print at 100%'**
  String get canvasPrintPatternNote;

  /// No description provided for @canvasStitchingGuide.
  ///
  /// In en, this message translates to:
  /// **'Kantha stitching guide'**
  String get canvasStitchingGuide;

  /// No description provided for @canvasStitchingGuideNote.
  ///
  /// In en, this message translates to:
  /// **'How to lay out and stitch the panel'**
  String get canvasStitchingGuideNote;

  /// No description provided for @canvasOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get canvasOpen;

  /// No description provided for @canvasPictureOnly.
  ///
  /// In en, this message translates to:
  /// **'Picture only'**
  String get canvasPictureOnly;

  /// No description provided for @canvasView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get canvasView;

  /// No description provided for @canvasAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get canvasAdd;

  /// No description provided for @canvasClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get canvasClose;

  /// No description provided for @canvasShopNote.
  ///
  /// In en, this message translates to:
  /// **'catsofkochi shop'**
  String get canvasShopNote;

  /// No description provided for @canvasBackupNote.
  ///
  /// In en, this message translates to:
  /// **'Your work is kept on this device only'**
  String get canvasBackupNote;

  /// No description provided for @clothTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a piece'**
  String get clothTitle;

  /// No description provided for @clothPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo of the piece'**
  String get clothPhoto;

  /// No description provided for @clothPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to take one, or choose a picture'**
  String get clothPhotoHint;

  /// No description provided for @clothBusy.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get clothBusy;

  /// No description provided for @clothErrorsNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'A photograph of the piece is needed.'**
  String get clothErrorsNoPhoto;

  /// No description provided for @clothErrorsBadPhoto.
  ///
  /// In en, this message translates to:
  /// **'{name} could not be read as a picture.'**
  String clothErrorsBadPhoto(String name);

  /// No description provided for @clothErrorsBadCount.
  ///
  /// In en, this message translates to:
  /// **'A count is a whole number, from 1 to 500.'**
  String get clothErrorsBadCount;

  /// No description provided for @clothErrorsBadBox.
  ///
  /// In en, this message translates to:
  /// **'That box is not a fabric box.'**
  String get clothErrorsBadBox;

  /// No description provided for @clothErrorsBoxFull.
  ///
  /// In en, this message translates to:
  /// **'This box holds {limit} cloths already. Take some out before adding more.'**
  String clothErrorsBoxFull(String limit);

  /// No description provided for @clothErrorsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The factory answered in a way this could not read. Nothing was added.'**
  String get clothErrorsUnreadable;

  /// No description provided for @clothErrorsNotReady.
  ///
  /// In en, this message translates to:
  /// **'The cropper is still loading. Give it a moment and press again.'**
  String get clothErrorsNotReady;

  /// No description provided for @clothErrorsNoSuchCloth.
  ///
  /// In en, this message translates to:
  /// **'There is no such cloth.'**
  String get clothErrorsNoSuchCloth;

  /// No description provided for @clothErrorsPieceFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again in a moment.'**
  String get clothErrorsPieceFailed;

  /// No description provided for @clothCropHint.
  ///
  /// In en, this message translates to:
  /// **'fill the square with the piece'**
  String get clothCropHint;

  /// No description provided for @clothRetake.
  ///
  /// In en, this message translates to:
  /// **'Choose a different picture'**
  String get clothRetake;

  /// No description provided for @clothChoosePicture.
  ///
  /// In en, this message translates to:
  /// **'Choose a picture'**
  String get clothChoosePicture;

  /// No description provided for @clothFixTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix this cloth'**
  String get clothFixTitle;

  /// No description provided for @clothFixWiden.
  ///
  /// In en, this message translates to:
  /// **'You can only crop further in. What was cut away when this cloth was added was never kept, so widening is not possible — if there is no clean square left, photograph the piece again as a new cloth.'**
  String get clothFixWiden;

  /// No description provided for @clothFixBusy.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get clothFixBusy;

  /// No description provided for @clothHowTo.
  ///
  /// In en, this message translates to:
  /// **'How to get it right'**
  String get clothHowTo;

  /// No description provided for @clothHowTo1.
  ///
  /// In en, this message translates to:
  /// **'Cut each piece 6 cm by 6 cm.'**
  String get clothHowTo1;

  /// No description provided for @clothHowTo2.
  ///
  /// In en, this message translates to:
  /// **'For best results, photograph it in daylight.'**
  String get clothHowTo2;

  /// No description provided for @clothHowTo3.
  ///
  /// In en, this message translates to:
  /// **'Lay it flat, and keep the table out of the square.'**
  String get clothHowTo3;

  /// No description provided for @clothHowMany.
  ///
  /// In en, this message translates to:
  /// **'How many of this piece'**
  String get clothHowMany;

  /// No description provided for @clothRecommend.
  ///
  /// In en, this message translates to:
  /// **'Cotton or linen works best.'**
  String get clothRecommend;

  /// No description provided for @clothPiece.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} piece} other{{n} pieces}}'**
  String clothPiece(num n);

  /// No description provided for @clothAddOne.
  ///
  /// In en, this message translates to:
  /// **'Add to box'**
  String get clothAddOne;

  /// No description provided for @clothAddMany.
  ///
  /// In en, this message translates to:
  /// **'Add {n} to box'**
  String clothAddMany(String n);

  /// No description provided for @clothSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get clothSaveChanges;

  /// No description provided for @clothRemoveThis.
  ///
  /// In en, this message translates to:
  /// **'Remove this piece'**
  String get clothRemoveThis;

  /// No description provided for @clothRemoveSure.
  ///
  /// In en, this message translates to:
  /// **'Remove it? It comes out of the box, and a pattern already made from it will say so.'**
  String get clothRemoveSure;

  /// No description provided for @clothRemoveUsed.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Remove this piece? {n} saved pattern using it stays as a picture. It can’t be changed or printed.} other{Remove this piece? {n} saved patterns using it stay as pictures. They can’t be changed or printed.}}'**
  String clothRemoveUsed(num n);

  /// No description provided for @clothFewer.
  ///
  /// In en, this message translates to:
  /// **'One fewer piece'**
  String get clothFewer;

  /// No description provided for @clothMore.
  ///
  /// In en, this message translates to:
  /// **'One more piece'**
  String get clothMore;

  /// No description provided for @clothAddedNext.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} piece of {name} added.} other{{n} pieces of {name} added.}} Photograph the next one.'**
  String clothAddedNext(num n, String name);

  /// No description provided for @clothPiecesInBox.
  ///
  /// In en, this message translates to:
  /// **'Pieces in the box'**
  String get clothPiecesInBox;

  /// No description provided for @clothFixAllUsed.
  ///
  /// In en, this message translates to:
  /// **'All {n} pieces are currently in use. Add more to give the pattern solver more options.'**
  String clothFixAllUsed(String n);

  /// No description provided for @clothManyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add pieces'**
  String get clothManyTitle;

  /// No description provided for @clothManyPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo of the pieces'**
  String get clothManyPhoto;

  /// No description provided for @clothManyPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'One piece or many: lay them out and take one photo.'**
  String get clothManyPhotoHint;

  /// No description provided for @clothManyHowTo3.
  ///
  /// In en, this message translates to:
  /// **'Lay them flat, apart or sewn together, and fill the photo with them.'**
  String get clothManyHowTo3;

  /// No description provided for @clothManyFind.
  ///
  /// In en, this message translates to:
  /// **'Find the pieces'**
  String get clothManyFind;

  /// No description provided for @clothManyFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding the pieces…'**
  String get clothManyFinding;

  /// No description provided for @clothManyFindingShort.
  ///
  /// In en, this message translates to:
  /// **'Finding…'**
  String get clothManyFindingShort;

  /// No description provided for @clothManyTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The pieces are too small in this photo to find. Come closer, so the pieces fill the photo, and take it again.'**
  String get clothManyTooSmall;

  /// No description provided for @clothManyCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Are these your pieces?'**
  String get clothManyCheckTitle;

  /// No description provided for @clothManyCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} piece} other{{n} pieces}}'**
  String clothManyCount(num n);

  /// No description provided for @clothManyCountRemoved.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} piece} other{{n} pieces}}, {gone} removed'**
  String clothManyCountRemoved(num n, String gone);

  /// No description provided for @clothManyUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get clothManyUndo;

  /// No description provided for @clothManyZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get clothManyZoomOut;

  /// No description provided for @clothManyZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get clothManyZoomIn;

  /// No description provided for @clothManyZoom.
  ///
  /// In en, this message translates to:
  /// **'{n} %'**
  String clothManyZoom(String n);

  /// No description provided for @clothManyCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a box to remove it. Tap a piece we missed to add it. Zoom in to move a box\'s corners.'**
  String get clothManyCheckHint;

  /// No description provided for @clothManyNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get clothManyNext;

  /// No description provided for @clothManyClothsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cloths'**
  String get clothManyClothsTitle;

  /// No description provided for @clothManyClothsHint.
  ///
  /// In en, this message translates to:
  /// **'Pieces of the same cloth are counted together. Change a count if it is wrong.'**
  String get clothManyClothsHint;

  /// No description provided for @clothManyFound.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Found once} other{Found {n} times}}'**
  String clothManyFound(num n);

  /// No description provided for @clothManyBack.
  ///
  /// In en, this message translates to:
  /// **'Back to the pieces'**
  String get clothManyBack;

  /// No description provided for @clothManyAdd.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Add {n} piece to box} other{Add {n} pieces to box}}'**
  String clothManyAdd(num n);

  /// No description provided for @clothManyAdded.
  ///
  /// In en, this message translates to:
  /// **'{cloths, plural, one{{cloths} cloth} other{{cloths} cloths}}, {pieces, plural, one{{pieces} piece} other{{pieces} pieces}}, added to {box}.'**
  String clothManyAdded(num cloths, num pieces, String box);

  /// No description provided for @boxesAddPieces.
  ///
  /// In en, this message translates to:
  /// **'Add pieces'**
  String get boxesAddPieces;

  /// No description provided for @boxesUnread.
  ///
  /// In en, this message translates to:
  /// **'Your cloth could not be read just now. Nothing is lost — try again in a few minutes.'**
  String get boxesUnread;

  /// No description provided for @boxesSample.
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get boxesSample;

  /// No description provided for @boxesAddOne.
  ///
  /// In en, this message translates to:
  /// **'Add a box'**
  String get boxesAddOne;

  /// No description provided for @boxesAddSample.
  ///
  /// In en, this message translates to:
  /// **'Add sample cloth'**
  String get boxesAddSample;

  /// No description provided for @boxesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete box'**
  String get boxesDelete;

  /// No description provided for @boxesDeleteAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete Box {n}? It holds no cloth.'**
  String boxesDeleteAsk(String n);

  /// No description provided for @boxesDeleteSampleAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete the Sample box? It holds no cloth.'**
  String get boxesDeleteSampleAsk;

  /// No description provided for @boxesDeleteFullAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete Box {n} and its pieces?'**
  String boxesDeleteFullAsk(String n);

  /// No description provided for @boxesDeleteSampleFullAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete the Sample box and its pieces?'**
  String get boxesDeleteSampleFullAsk;

  /// No description provided for @boxesName.
  ///
  /// In en, this message translates to:
  /// **'Box {n}'**
  String boxesName(String n);

  /// No description provided for @boxesPieces.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} piece} other{{n} pieces}}'**
  String boxesPieces(num n);

  /// No description provided for @boxesSampleColours.
  ///
  /// In en, this message translates to:
  /// **'sample cloth'**
  String get boxesSampleColours;

  /// No description provided for @boxesStartHere.
  ///
  /// In en, this message translates to:
  /// **'Start here: photograph your cloth to fill this box.'**
  String get boxesStartHere;

  /// No description provided for @boxesAddOneNote.
  ///
  /// In en, this message translates to:
  /// **'Makes the next number and opens it'**
  String get boxesAddOneNote;

  /// No description provided for @editBoxRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get editBoxRename;

  /// No description provided for @deviceNotKept.
  ///
  /// In en, this message translates to:
  /// **'This browser is not keeping what you make here: it will all be gone when this page closes. Private windows do this. Use Back up in the Menu to keep a copy.'**
  String get deviceNotKept;

  /// No description provided for @deviceBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up or move to another device'**
  String get deviceBackupTitle;

  /// No description provided for @deviceBackupIntro.
  ///
  /// In en, this message translates to:
  /// **'Save everything you have made — boxes, cloth photos and designs — as one file. Open that file on another phone or browser to carry on there.'**
  String get deviceBackupIntro;

  /// No description provided for @deviceExportButton.
  ///
  /// In en, this message translates to:
  /// **'Save a backup file'**
  String get deviceExportButton;

  /// No description provided for @deviceExportDone.
  ///
  /// In en, this message translates to:
  /// **'Saved {file}.'**
  String deviceExportDone(String file);

  /// No description provided for @deviceImportButton.
  ///
  /// In en, this message translates to:
  /// **'Open a backup file'**
  String get deviceImportButton;

  /// No description provided for @deviceImportSure.
  ///
  /// In en, this message translates to:
  /// **'Opening {file} overwrites all designs and boxes currently on this device. Save a backup first to prevent losing your work.'**
  String deviceImportSure(String file);

  /// No description provided for @deviceImportSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save a backup of this device first'**
  String get deviceImportSaveFirst;

  /// No description provided for @deviceImportReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace with the file'**
  String get deviceImportReplace;

  /// No description provided for @deviceImportCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deviceImportCancel;

  /// No description provided for @deviceImportDone.
  ///
  /// In en, this message translates to:
  /// **'This device now holds what was in {file}.'**
  String deviceImportDone(String file);

  /// No description provided for @deviceNotBackup.
  ///
  /// In en, this message translates to:
  /// **'That file is not a Kantha backup. Nothing was changed.'**
  String get deviceNotBackup;

  /// No description provided for @deviceTooNew.
  ///
  /// In en, this message translates to:
  /// **'That backup was made by a newer Kantha. Update the app, then open it again. Nothing was changed.'**
  String get deviceTooNew;

  /// No description provided for @deviceBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup could not be made. Nothing was changed.'**
  String get deviceBackupFailed;

  /// No description provided for @deviceStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'this device did not keep it'**
  String get deviceStorageFailed;

  /// No description provided for @deviceDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deviceDeleteCancel;

  /// No description provided for @deviceImportNote.
  ///
  /// In en, this message translates to:
  /// **'Replaces everything on this device'**
  String get deviceImportNote;

  /// No description provided for @deviceSafariBanner.
  ///
  /// In en, this message translates to:
  /// **'Safari clears this browser\'s data after 7 days away. Add Kantha to your Home Screen to keep your work.'**
  String get deviceSafariBanner;

  /// No description provided for @deviceSpaceUsed.
  ///
  /// In en, this message translates to:
  /// **'Kantha is using {mb} MB on this device'**
  String deviceSpaceUsed(String mb);

  /// No description provided for @deviceFreeSpace.
  ///
  /// In en, this message translates to:
  /// **'Free up space'**
  String get deviceFreeSpace;

  /// No description provided for @deviceFreeingSpace.
  ///
  /// In en, this message translates to:
  /// **'Freeing space…'**
  String get deviceFreeingSpace;

  /// No description provided for @deviceSpaceFreed.
  ///
  /// In en, this message translates to:
  /// **'Freed {freed} MB. Kantha is now using {mb} MB on this device.'**
  String deviceSpaceFreed(String freed, String mb);

  /// No description provided for @deviceFreeSpaceFailed.
  ///
  /// In en, this message translates to:
  /// **'Kantha could not free up space. Nothing was lost.'**
  String get deviceFreeSpaceFailed;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
