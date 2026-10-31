// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get canvasSave => 'Save';

  @override
  String get canvasHideControls => 'Done';

  @override
  String get canvasPanelName => 'Design name';

  @override
  String canvasDefaultName(String layout) {
    return '$layout';
  }

  @override
  String get canvasPanelsEyebrow => 'My designs';

  @override
  String get canvasNewDesign => 'New design';

  @override
  String canvasCopyName(String name) {
    return '$name copy';
  }

  @override
  String get canvasDuplicate => 'Duplicate';

  @override
  String get canvasMore => 'More';

  @override
  String get canvasMountEyebrow => 'Mount';

  @override
  String get canvasStitchesSwitch => 'Show stitches';

  @override
  String get canvasStitchColoursEcru => 'Cream';

  @override
  String get canvasStitchColoursMadder => 'Red';

  @override
  String get canvasStitchColoursIndigo => 'Blue';

  @override
  String get canvasStitchColoursTurmeric => 'Yellow';

  @override
  String get canvasStitchColoursLeaf => 'Green';

  @override
  String get canvasStitchColoursBlack => 'Black';

  @override
  String get canvasNoSaved =>
      'Nothing saved yet. Press Save and your design waits here.';

  @override
  String get canvasZoomIn => 'Zoom in';

  @override
  String get canvasZoomOut => 'Zoom out';

  @override
  String get canvasFit => 'Fit';

  @override
  String canvasZoomPercent(String n) {
    return '$n%';
  }

  @override
  String get canvasSolving => 'Arranging the cloth…';

  @override
  String get canvasCantSolve =>
      'This box holds fewer than 35 pieces — open another box.';

  @override
  String get canvasSaved => 'Saved to My designs.';

  @override
  String canvasSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get canvasMissingCloth =>
      'That design uses cloth that is no longer in the box.';

  @override
  String get canvasDelete => 'Delete';

  @override
  String canvasDeleteFailed(String error) {
    return 'Not deleted: $error';
  }

  @override
  String canvasCellLabel(String r, String c, String name) {
    return 'Row $r, column $c — $name';
  }

  @override
  String canvasSwatchLabel(String name, String left, String stock) {
    return '$name — $left of $stock pieces still free';
  }

  @override
  String get canvasLayoutsContrastTitle => 'Chess';

  @override
  String get canvasLayoutsContrastName =>
      'Every seam earns its keep, light against dark.';

  @override
  String get canvasLayoutsGradientTitle => 'Gradient';

  @override
  String get canvasLayoutsGradientName =>
      'Pale at the top corner, falling to the darkest cloth.';

  @override
  String get canvasLayoutsMedallionTitle => 'Centre';

  @override
  String get canvasLayoutsMedallionName =>
      'Dark heart, lightening out to the edge.';

  @override
  String get canvasLayoutsWaveTitle => 'Wave';

  @override
  String get canvasLayoutsWaveName =>
      'Bands of tone on the diagonal, the bargello way.';

  @override
  String get canvasLayoutsFramedTitle => 'Border';

  @override
  String get canvasLayoutsFramedName => 'Dark outer ring anchoring the panel.';

  @override
  String get canvasLayoutsCrossTitle => 'Cross';

  @override
  String get canvasLayoutsCrossName =>
      'Dark diagonals, light in the triangles between.';

  @override
  String get canvasLayoutsSpectrumTitle => 'Spectrum';

  @override
  String get canvasLayoutsSpectrumName =>
      'Cool on the left, running warm to the right.';

  @override
  String get canvasLayoutsBoroTitle => 'Mixed';

  @override
  String get canvasLayoutsBoroName =>
      'No pattern, just nothing repeating or muddy.';

  @override
  String get canvasLayoutsBlocksTitle => 'Blocks';

  @override
  String get canvasLayoutsBlocksName =>
      'Colour gathered where the cloth wants to cluster, seams still held apart.';

  @override
  String get canvasLayoutsMedallionPrintTitle => 'Ripple';

  @override
  String get canvasLayoutsMedallionPrintName =>
      'The busiest cloth at the heart, plainer out to the edge.';

  @override
  String get canvasLayoutsHeartTitle => 'Heart';

  @override
  String get canvasLayoutsHeartName =>
      'A red heart on the lightest cloth, every seam around it held apart.';

  @override
  String get canvasMountsNoneName => 'Panel';

  @override
  String get canvasMountsFrameName => 'Frame';

  @override
  String get canvasMountsToteName => 'Tote';

  @override
  String get canvasNotFillableNoColour =>
      'this box has no cloth with that colour';

  @override
  String get canvasNotFillableFewPieces =>
      'this box has too few pieces near that colour to fill the shape';

  @override
  String get canvasNotFillableNoDarkEnough =>
      'this box has no cloth of that colour dark enough to stand against the ground';

  @override
  String get canvasNotFillableNoFamilies =>
      'this box has too few coloured cloths to make its colour families';

  @override
  String canvasLayoutCannot(String title, String why) {
    return '$title — $why';
  }

  @override
  String canvasCantFill(String why) {
    return 'This box cannot fill this layout: $why.';
  }

  @override
  String get canvasYourBoxes => 'Your boxes';

  @override
  String get canvasShare => 'Share';

  @override
  String get canvasSavePhoto => 'Save photo';

  @override
  String get canvasShareTo => 'Share…';

  @override
  String get canvasSharePhotoFailed => 'Couldn’t prepare the photo — try again';

  @override
  String get canvasDownloadFailed =>
      'The file could not be made. Try again in a minute.';

  @override
  String get canvasMadeWith => 'made with kantha.app';

  @override
  String canvasUpcycled(String n) {
    return 'Upcycled from $n cloth pieces';
  }

  @override
  String get canvasMenu => 'Menu';

  @override
  String get canvasHelp => 'Help';

  @override
  String canvasDeleteSure(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get canvasShop => 'Shop';

  @override
  String get canvasPrivacy => 'Privacy policy';

  @override
  String get canvasSavedFirst =>
      'Saved on this device. Back up from the menu to keep a copy.';

  @override
  String get canvasNothingToSave => 'Add 35 pieces to your box before saving.';

  @override
  String canvasNothingToSaveSize(String n) {
    return 'Add $n pieces to your box before saving.';
  }

  @override
  String canvasCantSolveSize(String n) {
    return 'This box holds fewer than $n pieces — open another box.';
  }

  @override
  String get canvasLevelEyebrow => 'I am a…';

  @override
  String get canvasLevelBeginner => 'Beginner (5 × 7)';

  @override
  String get canvasLevelPatchworker => 'Patchworker (any size)';

  @override
  String get canvasRows => 'Rows';

  @override
  String get canvasColumns => 'Columns';

  @override
  String get canvasRowsFewer => 'Fewer rows';

  @override
  String get canvasRowsMore => 'More rows';

  @override
  String get canvasColumnsFewer => 'Fewer columns';

  @override
  String get canvasColumnsMore => 'More columns';

  @override
  String canvasAddMore(num n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Add $nString more pieces to complete the grid.',
      one: 'Add $nString more piece to complete the grid.',
    );
    return '$_temp0';
  }

  @override
  String canvasEmptyCell(String r, String c) {
    return 'Row $r, column $c — tap to add cloth';
  }

  @override
  String canvasSwatchLeft(String n) {
    return '$n left';
  }

  @override
  String canvasSwatchAllUsed(String name, String stock) {
    return '$name — all $stock pieces are in the design. Tap to add more.';
  }

  @override
  String get canvasTabCloth => 'Cloth box';

  @override
  String get canvasTabDesign => 'Design';

  @override
  String get canvasTabPreview => 'Preview';

  @override
  String get canvasZoom => 'Zoom';

  @override
  String get canvasPrintPattern => 'Print pattern PDF';

  @override
  String get canvasPrintPatternNote => 'A4 — print at 100%';

  @override
  String get canvasStitchingGuide => 'Kantha stitching guide';

  @override
  String get canvasStitchingGuideNote => 'How to lay out and stitch the panel';

  @override
  String get canvasOpen => 'Open';

  @override
  String get canvasPictureOnly => 'Picture only';

  @override
  String get canvasView => 'View';

  @override
  String get canvasAdd => 'Add';

  @override
  String get canvasClose => 'Close';

  @override
  String get canvasShopNote => 'catsofkochi shop';

  @override
  String get canvasBackupNote => 'Your work is kept on this device only';

  @override
  String get clothTitle => 'Add a piece';

  @override
  String get clothPhoto => 'Photo of the piece';

  @override
  String get clothPhotoHint => 'Tap to take one, or choose a picture';

  @override
  String get clothBusy => 'Measuring…';

  @override
  String get clothErrorsNoPhoto => 'A photograph of the piece is needed.';

  @override
  String clothErrorsBadPhoto(String name) {
    return '$name could not be read as a picture.';
  }

  @override
  String get clothErrorsBadCount => 'A count is a whole number, from 1 to 500.';

  @override
  String get clothErrorsBadBox => 'That box is not a fabric box.';

  @override
  String clothErrorsBoxFull(String limit) {
    return 'This box holds $limit cloths already. Take some out before adding more.';
  }

  @override
  String get clothErrorsUnreadable =>
      'The factory answered in a way this could not read. Nothing was added.';

  @override
  String get clothErrorsNotReady =>
      'The cropper is still loading. Give it a moment and press again.';

  @override
  String get clothErrorsNoSuchCloth => 'There is no such cloth.';

  @override
  String get clothErrorsPieceFailed =>
      'That did not work. Try again in a moment.';

  @override
  String get clothCropHint => 'fill the square with the piece';

  @override
  String get clothRetake => 'Choose a different picture';

  @override
  String get clothChoosePicture => 'Choose a picture';

  @override
  String get clothFixTitle => 'Fix this cloth';

  @override
  String get clothFixWiden =>
      'You can only crop further in. What was cut away when this cloth was added was never kept, so widening is not possible — if there is no clean square left, photograph the piece again as a new cloth.';

  @override
  String get clothFixBusy => 'Measuring…';

  @override
  String get clothHowTo => 'How to get it right';

  @override
  String get clothHowTo1 => 'Cut each piece 6 cm by 6 cm.';

  @override
  String get clothHowTo2 => 'For best results, photograph it in daylight.';

  @override
  String get clothHowTo3 =>
      'Lay it flat, and keep the table out of the square.';

  @override
  String get clothHowMany => 'How many of this piece';

  @override
  String get clothRecommend => 'Cotton or linen works best.';

  @override
  String clothPiece(num n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString pieces',
      one: '$nString piece',
    );
    return '$_temp0';
  }

  @override
  String get clothAddOne => 'Add to box';

  @override
  String clothAddMany(String n) {
    return 'Add $n to box';
  }

  @override
  String get clothSaveChanges => 'Save changes';

  @override
  String get clothRemoveThis => 'Remove this piece';

  @override
  String get clothRemoveSure =>
      'Remove it? It comes out of the box, and a pattern already made from it will say so.';

  @override
  String clothRemoveUsed(num n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Remove this piece? $nString saved patterns using it stay as pictures. They can’t be changed or printed.',
      one:
          'Remove this piece? $nString saved pattern using it stays as a picture. It can’t be changed or printed.',
    );
    return '$_temp0';
  }

  @override
  String get clothFewer => 'One fewer piece';

  @override
  String get clothMore => 'One more piece';

  @override
  String clothAddedNext(num n, String name) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString pieces of $name added.',
      one: '$nString piece of $name added.',
    );
    return '$_temp0 Photograph the next one.';
  }

  @override
  String get clothPiecesInBox => 'Pieces in the box';

  @override
  String clothFixAllUsed(String n) {
    return 'All $n pieces are currently in use. Add more to give the pattern solver more options.';
  }

  @override
  String get clothManyTitle => 'Add pieces';

  @override
  String get clothManyPhoto => 'Photo of the pieces';

  @override
  String get clothManyPhotoHint =>
      'One piece or many: lay them out and take one photo.';

  @override
  String get clothManyHowTo3 =>
      'Lay them flat, apart or sewn together, and fill the photo with them.';

  @override
  String get clothManyFind => 'Find the pieces';

  @override
  String get clothManyFinding => 'Finding the pieces…';

  @override
  String get clothManyFindingShort => 'Finding…';

  @override
  String get clothManyTooSmall =>
      'The pieces are too small in this photo to find. Come closer, so the pieces fill the photo, and take it again.';

  @override
  String get clothManyCheckTitle => 'Are these your pieces?';

  @override
  String clothManyCount(num n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString pieces',
      one: '$nString piece',
    );
    return '$_temp0';
  }

  @override
  String clothManyCountRemoved(num n, String gone) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString pieces',
      one: '$nString piece',
    );
    return '$_temp0, $gone removed';
  }

  @override
  String get clothManyUndo => 'Undo';

  @override
  String get clothManyZoomOut => 'Zoom out';

  @override
  String get clothManyZoomIn => 'Zoom in';

  @override
  String clothManyZoom(String n) {
    return '$n %';
  }

  @override
  String get clothManyCheckHint =>
      'Tap a box to remove it. Tap a piece we missed to add it. Zoom in to move a box\'s corners.';

  @override
  String get clothManyNext => 'Next';

  @override
  String get clothManyClothsTitle => 'Your cloths';

  @override
  String get clothManyClothsHint =>
      'Pieces of the same cloth are counted together. Change a count if it is wrong.';

  @override
  String clothManyFound(num n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Found $nString times',
      one: 'Found once',
    );
    return '$_temp0';
  }

  @override
  String get clothManyBack => 'Back to the pieces';

  @override
  String clothManyAdd(num n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Add $nString pieces to box',
      one: 'Add $nString piece to box',
    );
    return '$_temp0';
  }

  @override
  String clothManyAdded(num cloths, num pieces, String box) {
    final intl.NumberFormat clothsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String clothsString = clothsNumberFormat.format(cloths);
    final intl.NumberFormat piecesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String piecesString = piecesNumberFormat.format(pieces);

    String _temp0 = intl.Intl.pluralLogic(
      cloths,
      locale: localeName,
      other: '$clothsString cloths',
      one: '$clothsString cloth',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pieces,
      locale: localeName,
      other: '$piecesString pieces',
      one: '$piecesString piece',
    );
    return '$_temp0, $_temp1, added to $box.';
  }

  @override
  String clothManyAddedNext(num cloths, num pieces, String box) {
    final intl.NumberFormat clothsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String clothsString = clothsNumberFormat.format(cloths);
    final intl.NumberFormat piecesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String piecesString = piecesNumberFormat.format(pieces);

    String _temp0 = intl.Intl.pluralLogic(
      cloths,
      locale: localeName,
      other: '$clothsString cloths',
      one: '$clothsString cloth',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pieces,
      locale: localeName,
      other: '$piecesString pieces',
      one: '$piecesString piece',
    );
    return '$_temp0, $_temp1, added to $box. Photograph the next one.';
  }

  @override
  String get boxesAddPieces => 'Add pieces';

  @override
  String get boxesUnread =>
      'Your cloth could not be read just now. Nothing is lost — try again in a few minutes.';

  @override
  String get boxesSample => 'Sample';

  @override
  String get boxesAddOne => 'Add a box';

  @override
  String get boxesAddSample => 'Add sample cloth';

  @override
  String get boxesDelete => 'Delete box';

  @override
  String boxesDeleteAsk(String n) {
    return 'Delete Box $n? It holds no cloth.';
  }

  @override
  String get boxesDeleteSampleAsk =>
      'Delete the Sample box? It holds no cloth.';

  @override
  String boxesDeleteFullAsk(String n) {
    return 'Delete Box $n and its pieces?';
  }

  @override
  String get boxesDeleteSampleFullAsk =>
      'Delete the Sample box and its pieces?';

  @override
  String boxesName(String n) {
    return 'Box $n';
  }

  @override
  String boxesPieces(num n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString pieces',
      one: '$nString piece',
    );
    return '$_temp0';
  }

  @override
  String get boxesSampleColours => 'sample cloth';

  @override
  String get boxesStartHere =>
      'Start here: photograph your cloth to fill this box.';

  @override
  String get boxesAddOneNote => 'Makes the next number and opens it';

  @override
  String get editBoxRename => 'Rename';

  @override
  String get deviceNotKept =>
      'This browser is not keeping what you make here: it will all be gone when this page closes. Private windows do this. Use Back up in the Menu to keep a copy.';

  @override
  String get deviceBackupTitle => 'Back up or move to another device';

  @override
  String get deviceBackupIntro =>
      'Save everything you have made — boxes, cloth photos and designs — as one file. Open that file on another phone or browser to carry on there.';

  @override
  String get deviceExportButton => 'Save a backup file';

  @override
  String deviceExportDone(String file) {
    return 'Saved $file.';
  }

  @override
  String get deviceImportButton => 'Open a backup file';

  @override
  String deviceImportSure(String file) {
    return 'Opening $file overwrites all designs and boxes currently on this device. Save a backup first to prevent losing your work.';
  }

  @override
  String get deviceImportSaveFirst => 'Save a backup of this device first';

  @override
  String get deviceImportReplace => 'Replace with the file';

  @override
  String get deviceImportCancel => 'Cancel';

  @override
  String deviceImportDone(String file) {
    return 'This device now holds what was in $file.';
  }

  @override
  String get deviceNotBackup =>
      'That file is not a Kantha backup. Nothing was changed.';

  @override
  String get deviceTooNew =>
      'That backup was made by a newer Kantha. Update the app, then open it again. Nothing was changed.';

  @override
  String get deviceBackupFailed =>
      'The backup could not be made. Nothing was changed.';

  @override
  String get deviceStorageFailed => 'this device did not keep it';

  @override
  String get deviceDeleteCancel => 'Cancel';

  @override
  String get deviceImportNote => 'Replaces everything on this device';

  @override
  String get deviceSafariBanner =>
      'Safari clears this browser\'s data after 7 days away. Add Kantha to your Home Screen to keep your work.';

  @override
  String deviceSpaceUsed(String mb) {
    return 'Kantha is using $mb MB on this device';
  }

  @override
  String get deviceFreeSpace => 'Free up space';

  @override
  String get deviceFreeingSpace => 'Freeing space…';

  @override
  String deviceSpaceFreed(String freed, String mb) {
    return 'Freed $freed MB. Kantha is now using $mb MB on this device.';
  }

  @override
  String get deviceFreeSpaceFailed =>
      'Kantha could not free up space. Nothing was lost.';
}
