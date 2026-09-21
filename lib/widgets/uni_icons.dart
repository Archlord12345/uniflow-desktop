/// Icônes UniFlow — famille Phosphor, commune au web, au mobile et au desktop.
///
/// Voir `docs/icones-uniflow.md` à la racine du projet : ce fichier en est
/// l'implémentation Flutter (table sémantique, `subjectIcon`, `subjectColor`,
/// tuile `IconTile`).
///
/// Les glyphes viennent de `phosphor.dart`, généré par
/// `tool/generate_phosphor_glyphs.dart` : le code Dart de `phosphor_flutter`
/// ne compile plus depuis que `IconData` est une classe `final` (Flutter
/// 3.47), on n'en garde donc que les polices.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motion.dart' show motionReduced;
import 'phosphor.dart';

export 'phosphor.dart';

/// Les trois graisses retenues par la spécification. Jamais `thin`, `light`
/// ni `regular` seules sur la navigation, les tableaux de bord et les cartes.
enum UniIconStyle {
  /// Par défaut : dans les tuiles et sur les cartes.
  duotone,

  /// Destination active de la navigation.
  fill,

  /// Destinations inactives et chrome (fermer, retour, flèches…).
  bold,
}

/// Une icône sémantique déclinable dans les trois graisses.
///
/// Les trois variantes sont des constantes : une `UniIcon` peut donc vivre
/// dans une table `const` (`AppDestination`, actions rapides), ce qu'un appel
/// de fonction ne permettrait pas. `UniIcons.x()` rend le duotone,
/// `UniIcons.x(UniIconStyle.bold)` la graisse demandée.
class UniIcon {
  const UniIcon(this.duotone, this.fill, this.bold);

  final IconData duotone;
  final IconData fill;
  final IconData bold;

  IconData call([UniIconStyle style = UniIconStyle.duotone]) => switch (style) {
        UniIconStyle.duotone => duotone,
        UniIconStyle.fill => fill,
        UniIconStyle.bold => bold,
      };
}

/// Table sémantique de la spécification (même nom Phosphor sur les trois
/// plateformes), complétée par le chrome propre au desktop.
abstract final class UniIcons {
  static const UniIconStyle defaultStyle = UniIconStyle.duotone;

  static const UniIcon dashboard = UniIcon(PhosphorIconsDuotone.squaresFour,
      PhosphorIconsFill.squaresFour, PhosphorIconsBold.squaresFour);
  static const UniIcon schedule = UniIcon(PhosphorIconsDuotone.calendarBlank,
      PhosphorIconsFill.calendarBlank, PhosphorIconsBold.calendarBlank);
  static const UniIcon courses = UniIcon(PhosphorIconsDuotone.bookOpenText,
      PhosphorIconsFill.bookOpenText, PhosphorIconsBold.bookOpenText);
  static const UniIcon teachingUnits = UniIcon(
      PhosphorIconsDuotone.bookBookmark,
      PhosphorIconsFill.bookBookmark,
      PhosphorIconsBold.bookBookmark);
  static const UniIcon assignments = UniIcon(PhosphorIconsDuotone.clipboardText,
      PhosphorIconsFill.clipboardText, PhosphorIconsBold.clipboardText);
  static const UniIcon grades = UniIcon(PhosphorIconsDuotone.chartLineUp,
      PhosphorIconsFill.chartLineUp, PhosphorIconsBold.chartLineUp);
  static const UniIcon attendance = UniIcon(PhosphorIconsDuotone.qrCode,
      PhosphorIconsFill.qrCode, PhosphorIconsBold.qrCode);
  static const UniIcon messaging = UniIcon(PhosphorIconsDuotone.chatsCircle,
      PhosphorIconsFill.chatsCircle, PhosphorIconsBold.chatsCircle);
  static const UniIcon forum = UniIcon(PhosphorIconsDuotone.usersThree,
      PhosphorIconsFill.usersThree, PhosphorIconsBold.usersThree);
  static const UniIcon library = UniIcon(PhosphorIconsDuotone.books,
      PhosphorIconsFill.books, PhosphorIconsBold.books);
  static const UniIcon directory = UniIcon(PhosphorIconsDuotone.addressBook,
      PhosphorIconsFill.addressBook, PhosphorIconsBold.addressBook);
  static const UniIcon accounts = UniIcon(PhosphorIconsDuotone.userGear,
      PhosphorIconsFill.userGear, PhosphorIconsBold.userGear);
  static const UniIcon students = UniIcon(PhosphorIconsDuotone.graduationCap,
      PhosphorIconsFill.graduationCap, PhosphorIconsBold.graduationCap);
  static const UniIcon teachers = UniIcon(
      PhosphorIconsDuotone.chalkboardTeacher,
      PhosphorIconsFill.chalkboardTeacher,
      PhosphorIconsBold.chalkboardTeacher);
  static const UniIcon teaching = UniIcon(PhosphorIconsDuotone.chalkboard,
      PhosphorIconsFill.chalkboard, PhosphorIconsBold.chalkboard);
  static const UniIcon subscription = UniIcon(PhosphorIconsDuotone.creditCard,
      PhosphorIconsFill.creditCard, PhosphorIconsBold.creditCard);
  static const UniIcon settings = UniIcon(PhosphorIconsDuotone.gearSix,
      PhosphorIconsFill.gearSix, PhosphorIconsBold.gearSix);
  static const UniIcon badges = UniIcon(PhosphorIconsDuotone.medal,
      PhosphorIconsFill.medal, PhosphorIconsBold.medal);
  static const UniIcon assistant = UniIcon(PhosphorIconsDuotone.sparkle,
      PhosphorIconsFill.sparkle, PhosphorIconsBold.sparkle);
  static const UniIcon video = UniIcon(PhosphorIconsDuotone.videoCamera,
      PhosphorIconsFill.videoCamera, PhosphorIconsBold.videoCamera);
  static const UniIcon notifications = UniIcon(PhosphorIconsDuotone.bellRinging,
      PhosphorIconsFill.bellRinging, PhosphorIconsBold.bellRinging);
  static const UniIcon profile = UniIcon(PhosphorIconsDuotone.userCircle,
      PhosphorIconsFill.userCircle, PhosphorIconsBold.userCircle);
  static const UniIcon agenda = UniIcon(PhosphorIconsDuotone.calendarCheck,
      PhosphorIconsFill.calendarCheck, PhosphorIconsBold.calendarCheck);
  static const UniIcon tasks = UniIcon(PhosphorIconsDuotone.checkSquare,
      PhosphorIconsFill.checkSquare, PhosphorIconsBold.checkSquare);
  static const UniIcon university = UniIcon(PhosphorIconsDuotone.buildings,
      PhosphorIconsFill.buildings, PhosphorIconsBold.buildings);
  static const UniIcon room = UniIcon(PhosphorIconsDuotone.door,
      PhosphorIconsFill.door, PhosphorIconsBold.door);
  static const UniIcon clock = UniIcon(PhosphorIconsDuotone.clock,
      PhosphorIconsFill.clock, PhosphorIconsBold.clock);
  static const UniIcon statistics = UniIcon(PhosphorIconsDuotone.chartBar,
      PhosphorIconsFill.chartBar, PhosphorIconsBold.chartBar);
  static const UniIcon team = UniIcon(PhosphorIconsDuotone.usersFour,
      PhosphorIconsFill.usersFour, PhosphorIconsBold.usersFour);
  static const UniIcon help = UniIcon(PhosphorIconsDuotone.question,
      PhosphorIconsFill.question, PhosphorIconsBold.question);
  static const UniIcon about = UniIcon(PhosphorIconsDuotone.info,
      PhosphorIconsFill.info, PhosphorIconsBold.info);
  static const UniIcon security = UniIcon(PhosphorIconsDuotone.shieldCheck,
      PhosphorIconsFill.shieldCheck, PhosphorIconsBold.shieldCheck);
  static const UniIcon search = UniIcon(PhosphorIconsDuotone.magnifyingGlass,
      PhosphorIconsFill.magnifyingGlass, PhosphorIconsBold.magnifyingGlass);
  static const UniIcon add = UniIcon(PhosphorIconsDuotone.plusCircle,
      PhosphorIconsFill.plusCircle, PhosphorIconsBold.plusCircle);
  static const UniIcon signOut = UniIcon(PhosphorIconsDuotone.signOut,
      PhosphorIconsFill.signOut, PhosphorIconsBold.signOut);
  static const UniIcon back = UniIcon(PhosphorIconsDuotone.arrowLeft,
      PhosphorIconsFill.arrowLeft, PhosphorIconsBold.arrowLeft);
  static const UniIcon close =
      UniIcon(PhosphorIconsDuotone.x, PhosphorIconsFill.x, PhosphorIconsBold.x);
  static const UniIcon check = UniIcon(PhosphorIconsDuotone.check,
      PhosphorIconsFill.check, PhosphorIconsBold.check);
  static const UniIcon chevronLeft = UniIcon(PhosphorIconsDuotone.caretLeft,
      PhosphorIconsFill.caretLeft, PhosphorIconsBold.caretLeft);
  static const UniIcon chevronRight = UniIcon(PhosphorIconsDuotone.caretRight,
      PhosphorIconsFill.caretRight, PhosphorIconsBold.caretRight);
  static const UniIcon chevronDown = UniIcon(PhosphorIconsDuotone.caretDown,
      PhosphorIconsFill.caretDown, PhosphorIconsBold.caretDown);
  static const UniIcon chevronUp = UniIcon(PhosphorIconsDuotone.caretUp,
      PhosphorIconsFill.caretUp, PhosphorIconsBold.caretUp);
  static const UniIcon more = UniIcon(PhosphorIconsDuotone.dotsThreeVertical,
      PhosphorIconsFill.dotsThreeVertical, PhosphorIconsBold.dotsThreeVertical);
  static const UniIcon edit = UniIcon(PhosphorIconsDuotone.pencilSimple,
      PhosphorIconsFill.pencilSimple, PhosphorIconsBold.pencilSimple);
  static const UniIcon delete = UniIcon(PhosphorIconsDuotone.trash,
      PhosphorIconsFill.trash, PhosphorIconsBold.trash);
  static const UniIcon copy = UniIcon(PhosphorIconsDuotone.copy,
      PhosphorIconsFill.copy, PhosphorIconsBold.copy);
  static const UniIcon refresh = UniIcon(PhosphorIconsDuotone.arrowsClockwise,
      PhosphorIconsFill.arrowsClockwise, PhosphorIconsBold.arrowsClockwise);
  static const UniIcon filter = UniIcon(PhosphorIconsDuotone.funnel,
      PhosphorIconsFill.funnel, PhosphorIconsBold.funnel);
  static const UniIcon upload = UniIcon(PhosphorIconsDuotone.uploadSimple,
      PhosphorIconsFill.uploadSimple, PhosphorIconsBold.uploadSimple);
  static const UniIcon download = UniIcon(PhosphorIconsDuotone.downloadSimple,
      PhosphorIconsFill.downloadSimple, PhosphorIconsBold.downloadSimple);
  static const UniIcon attachment = UniIcon(PhosphorIconsDuotone.paperclip,
      PhosphorIconsFill.paperclip, PhosphorIconsBold.paperclip);
  static const UniIcon send = UniIcon(PhosphorIconsDuotone.paperPlaneTilt,
      PhosphorIconsFill.paperPlaneTilt, PhosphorIconsBold.paperPlaneTilt);
  static const UniIcon lock = UniIcon(PhosphorIconsDuotone.lock,
      PhosphorIconsFill.lock, PhosphorIconsBold.lock);
  static const UniIcon today = UniIcon(PhosphorIconsDuotone.calendarDot,
      PhosphorIconsFill.calendarDot, PhosphorIconsBold.calendarDot);
  static const UniIcon calendarOff = UniIcon(PhosphorIconsDuotone.calendarX,
      PhosphorIconsFill.calendarX, PhosphorIconsBold.calendarX);
  static const UniIcon warning = UniIcon(PhosphorIconsDuotone.warning,
      PhosphorIconsFill.warning, PhosphorIconsBold.warning);
  static const UniIcon offline = UniIcon(PhosphorIconsDuotone.wifiSlash,
      PhosphorIconsFill.wifiSlash, PhosphorIconsBold.wifiSlash);
  static const UniIcon online = UniIcon(PhosphorIconsDuotone.wifiHigh,
      PhosphorIconsFill.wifiHigh, PhosphorIconsBold.wifiHigh);
  static const UniIcon sidebar = UniIcon(PhosphorIconsDuotone.sidebar,
      PhosphorIconsFill.sidebar, PhosphorIconsBold.sidebar);
  static const UniIcon sun = UniIcon(
      PhosphorIconsDuotone.sun, PhosphorIconsFill.sun, PhosphorIconsBold.sun);
  static const UniIcon moon = UniIcon(PhosphorIconsDuotone.moon,
      PhosphorIconsFill.moon, PhosphorIconsBold.moon);
  static const UniIcon microphone = UniIcon(PhosphorIconsDuotone.microphone,
      PhosphorIconsFill.microphone, PhosphorIconsBold.microphone);
  static const UniIcon microphoneOff = UniIcon(
      PhosphorIconsDuotone.microphoneSlash,
      PhosphorIconsFill.microphoneSlash,
      PhosphorIconsBold.microphoneSlash);
  static const UniIcon videoOff = UniIcon(PhosphorIconsDuotone.videoCameraSlash,
      PhosphorIconsFill.videoCameraSlash, PhosphorIconsBold.videoCameraSlash);
  static const UniIcon screenShare = UniIcon(PhosphorIconsDuotone.screencast,
      PhosphorIconsFill.screencast, PhosphorIconsBold.screencast);
  static const UniIcon hangUp = UniIcon(PhosphorIconsDuotone.phoneX,
      PhosphorIconsFill.phoneX, PhosphorIconsBold.phoneX);
  static const UniIcon link = UniIcon(PhosphorIconsDuotone.link,
      PhosphorIconsFill.link, PhosphorIconsBold.link);
  static const UniIcon people = UniIcon(PhosphorIconsDuotone.users,
      PhosphorIconsFill.users, PhosphorIconsBold.users);
  static const UniIcon person = UniIcon(PhosphorIconsDuotone.user,
      PhosphorIconsFill.user, PhosphorIconsBold.user);
  static const UniIcon addPerson = UniIcon(PhosphorIconsDuotone.userPlus,
      PhosphorIconsFill.userPlus, PhosphorIconsBold.userPlus);
  static const UniIcon document = UniIcon(PhosphorIconsDuotone.fileText,
      PhosphorIconsFill.fileText, PhosphorIconsBold.fileText);
  static const UniIcon folder = UniIcon(PhosphorIconsDuotone.folderOpen,
      PhosphorIconsFill.folderOpen, PhosphorIconsBold.folderOpen);
  static const UniIcon note = UniIcon(PhosphorIconsDuotone.notePencil,
      PhosphorIconsFill.notePencil, PhosphorIconsBold.notePencil);
  static const UniIcon flashcards = UniIcon(PhosphorIconsDuotone.cards,
      PhosphorIconsFill.cards, PhosphorIconsBold.cards);
  static const UniIcon trophy = UniIcon(PhosphorIconsDuotone.trophy,
      PhosphorIconsFill.trophy, PhosphorIconsBold.trophy);
  static const UniIcon target = UniIcon(PhosphorIconsDuotone.target,
      PhosphorIconsFill.target, PhosphorIconsBold.target);
  static const UniIcon fire = UniIcon(PhosphorIconsDuotone.fire,
      PhosphorIconsFill.fire, PhosphorIconsBold.fire);
  static const UniIcon hourglass = UniIcon(PhosphorIconsDuotone.hourglassMedium,
      PhosphorIconsFill.hourglassMedium, PhosphorIconsBold.hourglassMedium);
  static const UniIcon timer = UniIcon(PhosphorIconsDuotone.timer,
      PhosphorIconsFill.timer, PhosphorIconsBold.timer);
  static const UniIcon palette = UniIcon(PhosphorIconsDuotone.palette,
      PhosphorIconsFill.palette, PhosphorIconsBold.palette);
  static const UniIcon language = UniIcon(PhosphorIconsDuotone.translate,
      PhosphorIconsFill.translate, PhosphorIconsBold.translate);
  static const UniIcon sync = UniIcon(PhosphorIconsDuotone.cloudArrowUp,
      PhosphorIconsFill.cloudArrowUp, PhosphorIconsBold.cloudArrowUp);
  static const UniIcon database = UniIcon(PhosphorIconsDuotone.database,
      PhosphorIconsFill.database, PhosphorIconsBold.database);
  static const UniIcon megaphone = UniIcon(PhosphorIconsDuotone.megaphone,
      PhosphorIconsFill.megaphone, PhosphorIconsBold.megaphone);
  static const UniIcon pin = UniIcon(PhosphorIconsDuotone.pushPin,
      PhosphorIconsFill.pushPin, PhosphorIconsBold.pushPin);
  static const UniIcon star = UniIcon(PhosphorIconsDuotone.star,
      PhosphorIconsFill.star, PhosphorIconsBold.star);
  static const UniIcon eye = UniIcon(
      PhosphorIconsDuotone.eye, PhosphorIconsFill.eye, PhosphorIconsBold.eye);
  static const UniIcon eyeOff = UniIcon(PhosphorIconsDuotone.eyeSlash,
      PhosphorIconsFill.eyeSlash, PhosphorIconsBold.eyeSlash);
  static const UniIcon mail = UniIcon(PhosphorIconsDuotone.envelopeSimple,
      PhosphorIconsFill.envelopeSimple, PhosphorIconsBold.envelopeSimple);
  static const UniIcon phone = UniIcon(PhosphorIconsDuotone.phone,
      PhosphorIconsFill.phone, PhosphorIconsBold.phone);
  static const UniIcon key = UniIcon(
      PhosphorIconsDuotone.key, PhosphorIconsFill.key, PhosphorIconsBold.key);
  static const UniIcon shield = UniIcon(PhosphorIconsDuotone.shield,
      PhosphorIconsFill.shield, PhosphorIconsBold.shield);
  static const UniIcon checks = UniIcon(PhosphorIconsDuotone.checks,
      PhosphorIconsFill.checks, PhosphorIconsBold.checks);
  static const UniIcon tray = UniIcon(PhosphorIconsDuotone.tray,
      PhosphorIconsFill.tray, PhosphorIconsBold.tray);
  static const UniIcon image = UniIcon(PhosphorIconsDuotone.image,
      PhosphorIconsFill.image, PhosphorIconsBold.image);
  static const UniIcon desktop = UniIcon(PhosphorIconsDuotone.desktop,
      PhosphorIconsFill.desktop, PhosphorIconsBold.desktop);
  static const UniIcon export = UniIcon(PhosphorIconsDuotone.export,
      PhosphorIconsFill.export, PhosphorIconsBold.export);
  static const UniIcon lightbulb = UniIcon(PhosphorIconsDuotone.lightbulb,
      PhosphorIconsFill.lightbulb, PhosphorIconsBold.lightbulb);
  static const UniIcon bookmark = UniIcon(PhosphorIconsDuotone.bookmarkSimple,
      PhosphorIconsFill.bookmarkSimple, PhosphorIconsBold.bookmarkSimple);
  static const UniIcon play = UniIcon(PhosphorIconsDuotone.play,
      PhosphorIconsFill.play, PhosphorIconsBold.play);
  static const UniIcon history = UniIcon(
      PhosphorIconsDuotone.clockCounterClockwise,
      PhosphorIconsFill.clockCounterClockwise,
      PhosphorIconsBold.clockCounterClockwise);
  static const UniIcon sliders = UniIcon(PhosphorIconsDuotone.slidersHorizontal,
      PhosphorIconsFill.slidersHorizontal, PhosphorIconsBold.slidersHorizontal);
  static const UniIcon wallet = UniIcon(PhosphorIconsDuotone.wallet,
      PhosphorIconsFill.wallet, PhosphorIconsBold.wallet);
  static const UniIcon hammer = UniIcon(PhosphorIconsDuotone.hammer,
      PhosphorIconsFill.hammer, PhosphorIconsBold.hammer);
  static const UniIcon userList = UniIcon(PhosphorIconsDuotone.userList,
      PhosphorIconsFill.userList, PhosphorIconsBold.userList);
  static const UniIcon arrowRight = UniIcon(PhosphorIconsDuotone.arrowRight,
      PhosphorIconsFill.arrowRight, PhosphorIconsBold.arrowRight);
  static const UniIcon openExternal = UniIcon(
      PhosphorIconsDuotone.arrowSquareOut,
      PhosphorIconsFill.arrowSquareOut,
      PhosphorIconsBold.arrowSquareOut);
  static const UniIcon bell = UniIcon(PhosphorIconsDuotone.bell,
      PhosphorIconsFill.bell, PhosphorIconsBold.bell);
  static const UniIcon readAll = UniIcon(PhosphorIconsDuotone.envelopeOpen,
      PhosphorIconsFill.envelopeOpen, PhosphorIconsBold.envelopeOpen);
  static const UniIcon treeStructure = UniIcon(
      PhosphorIconsDuotone.treeStructure,
      PhosphorIconsFill.treeStructure,
      PhosphorIconsBold.treeStructure);
  static const UniIcon filePdf = UniIcon(PhosphorIconsDuotone.filePdf,
      PhosphorIconsFill.filePdf, PhosphorIconsBold.filePdf);
  static const UniIcon filePpt = UniIcon(PhosphorIconsDuotone.filePpt,
      PhosphorIconsFill.filePpt, PhosphorIconsBold.filePpt);
  static const UniIcon fileXls = UniIcon(PhosphorIconsDuotone.fileXls,
      PhosphorIconsFill.fileXls, PhosphorIconsBold.fileXls);
  static const UniIcon fileImage = UniIcon(PhosphorIconsDuotone.fileImage,
      PhosphorIconsFill.fileImage, PhosphorIconsBold.fileImage);
  static const UniIcon fileZip = UniIcon(PhosphorIconsDuotone.fileZip,
      PhosphorIconsFill.fileZip, PhosphorIconsBold.fileZip);
  static const UniIcon fileText = UniIcon(PhosphorIconsDuotone.fileText,
      PhosphorIconsFill.fileText, PhosphorIconsBold.fileText);
  static const UniIcon printer = UniIcon(PhosphorIconsDuotone.printer,
      PhosphorIconsFill.printer, PhosphorIconsBold.printer);
  static const UniIcon checkCircle = UniIcon(PhosphorIconsDuotone.checkCircle,
      PhosphorIconsFill.checkCircle, PhosphorIconsBold.checkCircle);
  static const UniIcon circle = UniIcon(PhosphorIconsDuotone.circle,
      PhosphorIconsFill.circle, PhosphorIconsBold.circle);
  static const UniIcon hardDrives = UniIcon(PhosphorIconsDuotone.hardDrives,
      PhosphorIconsFill.hardDrives, PhosphorIconsBold.hardDrives);
  static const UniIcon network = UniIcon(PhosphorIconsDuotone.network,
      PhosphorIconsFill.network, PhosphorIconsBold.network);
  static const UniIcon terminalWindow = UniIcon(
      PhosphorIconsDuotone.terminalWindow,
      PhosphorIconsFill.terminalWindow,
      PhosphorIconsBold.terminalWindow);
  static const UniIcon warningCircle = UniIcon(
      PhosphorIconsDuotone.warningCircle,
      PhosphorIconsFill.warningCircle,
      PhosphorIconsBold.warningCircle);
  static const UniIcon signIn = UniIcon(PhosphorIconsDuotone.signIn,
      PhosphorIconsFill.signIn, PhosphorIconsBold.signIn);
  static const UniIcon globe = UniIcon(PhosphorIconsDuotone.globe,
      PhosphorIconsFill.globe, PhosphorIconsBold.globe);
  static const UniIcon stopCircle = UniIcon(PhosphorIconsDuotone.stopCircle,
      PhosphorIconsFill.stopCircle, PhosphorIconsBold.stopCircle);
  static const UniIcon lockKey = UniIcon(PhosphorIconsDuotone.lockKey,
      PhosphorIconsFill.lockKey, PhosphorIconsBold.lockKey);
  static const UniIcon camera = UniIcon(PhosphorIconsDuotone.camera,
      PhosphorIconsFill.camera, PhosphorIconsBold.camera);
  static const UniIcon trashSimple = UniIcon(PhosphorIconsDuotone.trashSimple,
      PhosphorIconsFill.trashSimple, PhosphorIconsBold.trashSimple);
  static const UniIcon code = UniIcon(PhosphorIconsDuotone.code,
      PhosphorIconsFill.code, PhosphorIconsBold.code);
  static const UniIcon broadcast = UniIcon(PhosphorIconsDuotone.broadcast,
      PhosphorIconsFill.broadcast, PhosphorIconsBold.broadcast);
  static const UniIcon phoneDisconnect = UniIcon(
      PhosphorIconsDuotone.phoneDisconnect,
      PhosphorIconsFill.phoneDisconnect,
      PhosphorIconsBold.phoneDisconnect);
  static const UniIcon monitor = UniIcon(PhosphorIconsDuotone.monitor,
      PhosphorIconsFill.monitor, PhosphorIconsBold.monitor);
  static const UniIcon monitorArrowUp = UniIcon(
      PhosphorIconsDuotone.monitorArrowUp,
      PhosphorIconsFill.monitorArrowUp,
      PhosphorIconsBold.monitorArrowUp);
  static const UniIcon robot = UniIcon(PhosphorIconsDuotone.robot,
      PhosphorIconsFill.robot, PhosphorIconsBold.robot);
  static const UniIcon globeSimple = UniIcon(PhosphorIconsDuotone.globeSimple,
      PhosphorIconsFill.globeSimple, PhosphorIconsBold.globeSimple);
  static const UniIcon stairs = UniIcon(PhosphorIconsDuotone.stairs,
      PhosphorIconsFill.stairs, PhosphorIconsBold.stairs);
  static const UniIcon laptop = UniIcon(PhosphorIconsDuotone.laptop,
      PhosphorIconsFill.laptop, PhosphorIconsBold.laptop);
  static const UniIcon deviceMobile = UniIcon(PhosphorIconsDuotone.deviceMobile,
      PhosphorIconsFill.deviceMobile, PhosphorIconsBold.deviceMobile);
  static const UniIcon arrowUp = UniIcon(PhosphorIconsDuotone.arrowUp,
      PhosphorIconsFill.arrowUp, PhosphorIconsBold.arrowUp);
  static const UniIcon arrowDown = UniIcon(PhosphorIconsDuotone.arrowDown,
      PhosphorIconsFill.arrowDown, PhosphorIconsBold.arrowDown);

  // ── Matières (table `subjectIcon` de la spécification) ─────────────────
  static const UniIcon bookOpen = UniIcon(PhosphorIconsDuotone.bookOpen,
      PhosphorIconsFill.bookOpen, PhosphorIconsBold.bookOpen);
  static const UniIcon mathOperations = UniIcon(
      PhosphorIconsDuotone.mathOperations,
      PhosphorIconsFill.mathOperations,
      PhosphorIconsBold.mathOperations);
  static const UniIcon atom = UniIcon(PhosphorIconsDuotone.atom,
      PhosphorIconsFill.atom, PhosphorIconsBold.atom);
  static const UniIcon flask = UniIcon(PhosphorIconsDuotone.flask,
      PhosphorIconsFill.flask, PhosphorIconsBold.flask);
  static const UniIcon dna = UniIcon(
      PhosphorIconsDuotone.dna, PhosphorIconsFill.dna, PhosphorIconsBold.dna);
  static const UniIcon brain = UniIcon(PhosphorIconsDuotone.brain,
      PhosphorIconsFill.brain, PhosphorIconsBold.brain);
  static const UniIcon cloud = UniIcon(PhosphorIconsDuotone.cloud,
      PhosphorIconsFill.cloud, PhosphorIconsBold.cloud);
  static const UniIcon chartLine = UniIcon(PhosphorIconsDuotone.chartLine,
      PhosphorIconsFill.chartLine, PhosphorIconsBold.chartLine);
  static const UniIcon rocket = UniIcon(PhosphorIconsDuotone.rocket,
      PhosphorIconsFill.rocket, PhosphorIconsBold.rocket);
  static const UniIcon kanban = UniIcon(PhosphorIconsDuotone.kanban,
      PhosphorIconsFill.kanban, PhosphorIconsBold.kanban);
  static const UniIcon terminal = UniIcon(PhosphorIconsDuotone.terminal,
      PhosphorIconsFill.terminal, PhosphorIconsBold.terminal);
  static const UniIcon coins = UniIcon(PhosphorIconsDuotone.coins,
      PhosphorIconsFill.coins, PhosphorIconsBold.coins);
  static const UniIcon scales = UniIcon(PhosphorIconsDuotone.scales,
      PhosphorIconsFill.scales, PhosphorIconsBold.scales);
  static const UniIcon scroll = UniIcon(PhosphorIconsDuotone.scroll,
      PhosphorIconsFill.scroll, PhosphorIconsBold.scroll);
  static const UniIcon globeHemisphereWest = UniIcon(
      PhosphorIconsDuotone.globeHemisphereWest,
      PhosphorIconsFill.globeHemisphereWest,
      PhosphorIconsBold.globeHemisphereWest);
  static const UniIcon lightning = UniIcon(PhosphorIconsDuotone.lightning,
      PhosphorIconsFill.lightning, PhosphorIconsBold.lightning);
  static const UniIcon musicNotes = UniIcon(PhosphorIconsDuotone.musicNotes,
      PhosphorIconsFill.musicNotes, PhosphorIconsBold.musicNotes);
  static const UniIcon barbell = UniIcon(PhosphorIconsDuotone.barbell,
      PhosphorIconsFill.barbell, PhosphorIconsBold.barbell);
  static const UniIcon firstAid = UniIcon(PhosphorIconsDuotone.firstAid,
      PhosphorIconsFill.firstAid, PhosphorIconsBold.firstAid);
  static const UniIcon feather = UniIcon(PhosphorIconsDuotone.feather,
      PhosphorIconsFill.feather, PhosphorIconsBold.feather);
}

// ── subjectIcon ──────────────────────────────────────────────────────────

/// Palette des matières sans `colorHex`, dans l'ordre de la spécification
/// (le hachage indexe cette liste : ne pas la réordonner).
const List<Color> subjectPalette = [
  AppColors.teal,
  AppColors.primaryBlue,
  AppColors.purple,
  AppColors.warning,
  AppColors.success,
  Color(0xFFEC4899), // rose
  Color(0xFFF97316), // orange
];

class _SubjectRule {
  const _SubjectRule(this.pattern, this.icon);
  final RegExp pattern;
  final UniIcon icon;
}

RegExp _kw(String source) => RegExp(source, caseSensitive: false);

/// Règles de `subjectIcon`, dans l'ordre de la spécification : le premier
/// mot-clé trouvé gagne (« Développement web » doit donner Globe, pas Code).
/// Les mots-clés sont écrits sans accents parce que le nom est normalisé avant
/// la recherche.
///
/// Les mots très courts (« ia », « ios », « adn », « bdd », « tic », « art »,
/// « web », « geo ») sont ancrés en début de mot : en simple sous-chaîne,
/// « ia » aurait transformé « Matériaux » en intelligence artificielle et
/// « art » aurait envoyé « Cartographie » au dessin. Les racines plus longues
/// (« phys », « chim », « algorith »…) restent des sous-chaînes pour attraper
/// les pluriels et les dérivés. « bases? de donn » : la spécification écrit
/// « base de donn », mais l'intitulé réel est presque toujours au pluriel.
final List<_SubjectRule> _subjectRules = [
  _SubjectRule(_kw(r'math|algebre|analyse|geometrie'), UniIcons.mathOperations),
  _SubjectRule(_kw(r'phys'), UniIcons.atom),
  _SubjectRule(_kw(r'chim'), UniIcons.flask),
  _SubjectRule(_kw(r'bio|genetique|\badn\b'), UniIcons.dna),
  _SubjectRule(_kw(r'reseau'), UniIcons.network),
  _SubjectRule(_kw(r'bases? de donn|sql|\bbdd\b'), UniIcons.database),
  _SubjectRule(_kw(r'\bweb'), UniIcons.globe),
  _SubjectRule(_kw(r'mobile|android|\bios\b'), UniIcons.deviceMobile),
  _SubjectRule(_kw(r'secur|crypto'), UniIcons.security),
  _SubjectRule(
    _kw(r'intelligence artificielle|\bia\b|apprentissage|data|science des donn'),
    UniIcons.brain,
  ),
  _SubjectRule(_kw(r'cloud|devops'), UniIcons.cloud),
  _SubjectRule(_kw(r'statisti|proba'), UniIcons.chartLine),
  _SubjectRule(
    _kw(r'anglais|english|langue|francais|espagnol|allemand'),
    UniIcons.language,
  ),
  _SubjectRule(_kw(r'entrepren|innov'), UniIcons.rocket),
  _SubjectRule(_kw(r'projet|stage|tutore'), UniIcons.kanban),
  _SubjectRule(_kw(r'systeme|linux|exploitation'), UniIcons.terminal),
  _SubjectRule(
    _kw(r'algorith|programm|code|logiciel|info|developpement'),
    UniIcons.code,
  ),
  _SubjectRule(_kw(r'econom|gestion|compta|finance|marketing'), UniIcons.coins),
  _SubjectRule(_kw(r'droit|juridique'), UniIcons.scales),
  _SubjectRule(_kw(r'histoire'), UniIcons.scroll),
  _SubjectRule(_kw(r'\bgeo'), UniIcons.globeHemisphereWest),
  _SubjectRule(_kw(r'energ|electr'), UniIcons.lightning),
  _SubjectRule(_kw(r'musique'), UniIcons.musicNotes),
  _SubjectRule(_kw(r'\bart|dessin|design'), UniIcons.palette),
  _SubjectRule(_kw(r'sport|education physique'), UniIcons.barbell),
  _SubjectRule(_kw(r'sante|medecine|anatomie'), UniIcons.firstAid),
  _SubjectRule(_kw(r'\btic|telecom|communication'), UniIcons.broadcast),
  _SubjectRule(_kw(r'philo|lettres|litterature'), UniIcons.feather),
];

/// Icône d'une matière sans mot-clé reconnu.
const UniIcon subjectDefaultIcon = UniIcons.bookOpen;

const Map<String, String> _accentFolding = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// Minuscules + suppression des accents latins + `trim`, sans dépendance
/// externe : ce petit tableau couvre le français, l'anglais, l'espagnol et
/// l'allemand des intitulés. Même résultat que `normalizeSubjectText` du web,
/// ce qui compte pour que le hachage de [subjectColor] tombe sur la même
/// couleur.
String normalizeSubjectName(String input) {
  final out = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    out.write(_accentFolding[ch] ?? ch);
  }
  return out.toString().trim();
}

/// Comme [subjectIcon], mais rend l'icône dans ses trois graisses.
///
/// Le code n'est consulté qu'après le nom : « INF301 » ne doit pas décider à
/// la place de « Réseaux informatiques ».
UniIcon subjectUniIcon(String name, {String? code}) {
  final haystacks = [
    normalizeSubjectName(name),
    if (code != null) normalizeSubjectName(code),
  ];
  for (final text in haystacks) {
    if (text.isEmpty) continue;
    for (final rule in _subjectRules) {
      if (rule.pattern.hasMatch(text)) return rule.icon;
    }
  }
  return subjectDefaultIcon;
}

/// Icône d'une matière ou d'un cours, dérivée de son nom (puis de son code) :
/// fonction pure identique sur les trois plateformes, les matières n'ayant pas
/// d'attribut « icône » en base. Insensible à la casse et aux accents ;
/// `BookOpen` par défaut.
IconData subjectIcon(
  String name, {
  String? code,
  UniIconStyle style = UniIcons.defaultStyle,
}) =>
    subjectUniIcon(name, code: code)(style);

/// Analyse `#RRGGBB`, `RRGGBB`, `#RGB` ou `#AARRGGBB`. Renvoie `null` si
/// invalide, pour retomber sur la palette plutôt que d'afficher du noir.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 3) value = value.split('').map((c) => '$c$c').join();
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Hachage FNV-1a 32 bits, le même que `stableHash` du web : arithmétique
/// entière reproductible à l'identique, contrairement à `String.hashCode`
/// dont la valeur n'est pas garantie d'une plateforme (ni d'une session) à
/// l'autre. C'est ce qui donne à un cours la même couleur sur le web et ici.
int stableSubjectHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Couleur d'une matière : `colorHex` si présent et valide (cours libres de
/// l'espace personnel), sinon une couleur de [subjectPalette] choisie par
/// hachage stable du code normalisé.
Color subjectColor(String code, {String? colorHex}) {
  final explicit = parseHexColor(colorHex);
  if (explicit != null) return explicit;
  final key = normalizeSubjectName(code);
  return subjectPalette[stableSubjectHash(key) % subjectPalette.length];
}

// ── IconTile ─────────────────────────────────────────────────────────────

enum IconTileVariant { filled, soft }

/// Tuile d'icône carrée arrondie (44 px par défaut, 56 sur les cartes de
/// statistiques, 36 dans les listes denses).
///
/// Mouvement : apparition en cascade (échelle 0,85 → 1 + fondu, `easeOutBack`,
/// 40 ms par [index]), survol : translation −2 px et ombre renforcée,
/// pression : échelle 0,94 quand [onTap] est fourni. Tout est fini et
/// désactivé quand `MediaQuery.disableAnimationsOf` (ou `motionReduced`) est
/// vrai, pour que `pumpAndSettle` termine dans les tests.
class IconTile extends StatefulWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.variant = IconTileVariant.filled,
    this.index = 0,
    this.onTap,
    this.semanticLabel,
    this.tooltip,
    this.animate = true,
  });

  final IconData icon;
  final Color color;
  final double size;
  final IconTileVariant variant;

  /// Position dans une liste, pour décaler l'apparition en cascade.
  final int index;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? tooltip;

  /// `false` pour poser la tuile sans apparition (ex. : recomposition d'une
  /// liste déjà visible).
  final bool animate;

  static const Duration entranceDuration = Duration(milliseconds: 420);
  static const Duration cascadeStep = Duration(milliseconds: 40);

  /// Au-delà, l'attente devient perceptible ; on plafonne le décalage.
  static const int maxCascadeIndex = 12;

  @override
  State<IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<IconTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _started = false;
  bool _hovered = false;
  bool _pressed = false;

  int get _clampedIndex => widget.index.clamp(0, IconTile.maxCascadeIndex);

  /// Le décalage de cascade est intégré dans la durée du contrôleur (via un
  /// `Interval`) plutôt que dans un `Timer` : un Timer ne planifie pas de
  /// frame, donc `pumpAndSettle` rendrait la main avant l'apparition.
  Duration get _totalDuration =>
      IconTile.entranceDuration + IconTile.cascadeStep * _clampedIndex;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: _totalDuration);
  }

  bool _reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) || motionReduced.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || _reduced(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  double get _radius => widget.size >= 56 ? 16 : 14;

  double get _iconSize => (widget.size * 0.5).roundToDouble();

  Color _darken(Color c, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced(context);
    final motionDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 160);
    final filled = widget.variant == IconTileVariant.filled;
    final color = widget.color;

    final double delayFraction = _totalDuration.inMilliseconds == 0
        ? 0
        : (IconTile.cascadeStep * _clampedIndex).inMilliseconds /
            _totalDuration.inMilliseconds;
    final scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(delayFraction, 1, curve: Curves.easeOutBack),
      ),
    );
    final fade = CurvedAnimation(
      parent: _entrance,
      curve: Interval(delayFraction, 1, curve: Curves.easeOut),
    );

    final List<BoxShadow> shadows;
    if (filled) {
      shadows = [
        BoxShadow(
          color: color.withValues(alpha: _hovered ? 0.38 : 0.25),
          blurRadius: _hovered ? 18 : 12,
          offset: Offset(0, _hovered ? 8 : 4),
        ),
      ];
    } else {
      shadows = _hovered
          ? [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ]
          : const [];
    }

    final Widget icon = PhosphorIcon(
      widget.icon,
      size: _iconSize,
      color: filled ? Colors.white : color,
      duotoneSecondaryColor: filled ? Colors.white : color,
      duotoneSecondaryOpacity: filled ? 0.45 : 0.35,
      semanticLabel: widget.semanticLabel,
    );

    Widget tile = AnimatedContainer(
      duration: motionDuration,
      curve: Curves.easeOut,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: filled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, _darken(color)],
              )
            : null,
        color: filled ? null : color.withValues(alpha: 0.14),
        boxShadow: shadows,
      ),
      child: Center(child: icon),
    );

    if (widget.tooltip != null) {
      tile = Tooltip(message: widget.tooltip!, child: tile);
    }

    // Survol : translation −2 px, exprimée en fraction de la hauteur pour
    // AnimatedSlide.
    tile = AnimatedSlide(
      duration: motionDuration,
      curve: Curves.easeOut,
      offset: _hovered ? Offset(0, -2 / widget.size) : Offset.zero,
      child: AnimatedScale(
        duration: motionDuration,
        curve: Curves.easeOut,
        scale: _pressed ? 0.94 : 1,
        child: tile,
      ),
    );

    if (widget.onTap != null) {
      tile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: tile,
      );
    }

    tile = MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: tile,
    );

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: tile),
    );
  }
}
