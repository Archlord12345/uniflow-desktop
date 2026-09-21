import 'dart:convert';

/// Page web de participation, servie par le poste hôte aux navigateurs du
/// réseau local.
///
/// Un participant sans application UniFlow ouvre le lien diffusé par l'hôte
/// (`http://<adresse de l'hôte>:<port>/join/<CODE>`), saisit son nom et entre
/// dans la salle : la page demande un jeton à l'API de jonction du même poste
/// puis se connecte au serveur média avec le bundle `livekit-client` servi lui
/// aussi par l'hôte. Rien n'est chargé depuis Internet : la page doit
/// fonctionner dans une salle sans connexion.
///
/// Le HTML est produit en Dart plutôt que lu dans un fichier : le code de la
/// réunion, son titre et son identifiant y sont injectés, et la page se teste
/// sans le moteur Flutter.
///
/// Limite connue : sur une adresse `http://` autre que `localhost`, les
/// navigateurs refusent l'accès à la caméra et au micro (contexte non
/// sécurisé). La page le détecte et bascule en « écoute » — le participant voit
/// et entend, sans publier — en l'expliquant clairement. Lever cette limite
/// demande de servir la page en HTTPS avec un certificat local.
class ConferenceJoinPage {
  const ConferenceJoinPage._();

  /// Chemin du bundle JavaScript servi par l'hôte.
  static const String clientScriptPath = '/assets/livekit-client.umd.js';

  /// Chemin, dans les ressources de l'application, du bundle à servir.
  static const String clientScriptAsset =
      'assets/conference_web/livekit-client.umd.js';

  /// Page pour la réunion [roomId] : le code est pré-rempli, le titre affiché.
  /// Quand [roomId] est `null`, aucune réunion ne correspond au code de
  /// l'adresse (ou il n'y en avait pas) : la page laisse saisir le code.
  static String render({
    String? roomId,
    String? roomName,
    String? code,
    String? hostName,
  }) {
    // Le JSON est inséré dans un <script> : un nom de réunion contenant
    // « </script> » refermerait la balise et le reste deviendrait du HTML.
    // Les chevrons et l'esperluette passent en échappements JSON, que le
    // navigateur relit tels quels.
    final config = jsonEncode({
      'roomId': roomId,
      'roomName': roomName,
      'code': code,
      'hostName': hostName,
    })
        .replaceAll('<', r'\u003c')
        .replaceAll('>', r'\u003e')
        .replaceAll('&', r'\u0026');
    final title = _escape(roomName ?? 'Réunion UniFlow');
    return '''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="color-scheme" content="dark">
<title>$title — UniFlow</title>
<style>
$_css
</style>
</head>
<body>
<header class="bar">
  <div class="brand"><span class="logo">$_logoSvg</span><span>Uni<b>Flow</b> <small>· réunion</small></span></div>
  <div class="bar-right">
    <span id="room-title" class="room-title"></span>
    <span id="count" class="pill" hidden>0 participant</span>
  </div>
</header>

<main id="lobby" class="lobby">
  <form id="join-form" class="card" autocomplete="on">
    <h1 id="lobby-title">Rejoindre la réunion</h1>
    <p id="lobby-host" class="muted"></p>
    <label>Votre nom
      <input id="name" name="name" required maxlength="60" placeholder="Prénom Nom" autocomplete="name">
    </label>
    <label id="code-field">Code de la réunion
      <input id="code" name="code" required maxlength="8" placeholder="AB12CD" autocapitalize="characters" autocomplete="off" spellcheck="false">
    </label>
    <p id="insecure" class="notice" hidden>
      Cette adresse est en <code>http://</code> : le navigateur n'autorise ni la caméra ni le micro.
      Vous suivrez la réunion en <b>écoute</b> (image et son de la salle). Pour parler ou montrer votre
      caméra, utilisez l'application UniFlow de bureau.
    </p>
    <p id="error" class="error" role="alert" hidden></p>
    <button id="join" type="submit" class="primary">Entrer dans la salle</button>
    <p class="fine">Réunion hébergée sur le réseau local par le poste de l'hôte. Aucune donnée ne sort de la salle.</p>
  </form>
</main>

<main id="stage" class="stage" hidden>
  <section id="grid" class="grid" aria-live="polite"></section>
  <footer class="controls">
    <button id="mic" class="ctl" title="Micro" aria-pressed="false">$_micSvg<span>Micro</span></button>
    <button id="cam" class="ctl" title="Caméra" aria-pressed="false">$_camSvg<span>Caméra</span></button>
    <button id="leave" class="ctl leave" title="Quitter">$_leaveSvg<span>Quitter</span></button>
  </footer>
</main>

<div id="ended" class="lobby" hidden>
  <div class="card">
    <h1>Réunion quittée</h1>
    <p id="ended-reason" class="muted">Vous avez quitté la réunion.</p>
    <button id="rejoin" class="primary" type="button">Revenir</button>
  </div>
</div>

<script>window.UNIFLOW_ROOM = $config;</script>
<script src="$clientScriptPath"></script>
<script>
$_script
</script>
</body>
</html>
''';
  }

  static String _escape(String value) => const HtmlEscape().convert(value);

  static const String _css = '''
:root{--navy:#151e32;--blue:#1e3a8a;--blue-2:#2d4fa8;--teal:#0d9488;--bg:#0b1020;--card:#121a2e;--line:rgba(255,255,255,.08);--text:#e6e9f2;--muted:#9aa3b8;--red:#dc2626}
*{box-sizing:border-box}html,body{height:100%}
body{margin:0;background:radial-gradient(1200px 600px at 20% -10%,#1e3a8a55,transparent),var(--bg);color:var(--text);font:15px/1.5 Inter,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;display:flex;flex-direction:column;min-height:100dvh}
.bar{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:12px 18px;border-bottom:1px solid var(--line);background:#0b1020cc;backdrop-filter:blur(8px);position:sticky;top:0;z-index:2}
.brand{display:flex;align-items:center;gap:10px;font-weight:800;letter-spacing:.2px}.brand b{color:#7dd3fc}.brand small{color:var(--muted);font-weight:500}
.logo{display:inline-flex;width:28px;height:28px;border-radius:8px;background:#fff;align-items:center;justify-content:center;padding:4px}
.bar-right{display:flex;align-items:center;gap:10px;min-width:0}.room-title{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:40vw}
.pill{font-size:12px;font-weight:700;padding:4px 10px;border-radius:999px;background:#ffffff14;border:1px solid var(--line)}
.lobby{flex:1;display:grid;place-items:center;padding:24px}
.card{width:min(440px,100%);background:var(--card);border:1px solid var(--line);border-radius:18px;padding:26px;box-shadow:0 20px 60px #00000066;animation:rise .35s ease-out}
@keyframes rise{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
h1{font-size:22px;margin:0 0 6px}.muted{color:var(--muted);margin:0 0 18px}
label{display:block;font-size:13px;font-weight:600;color:var(--muted);margin:12px 0}
input{display:block;width:100%;margin-top:6px;padding:12px 14px;border-radius:12px;border:1px solid var(--line);background:#0b1020;color:var(--text);font:inherit;font-size:16px}
input:focus{outline:2px solid var(--blue-2);border-color:transparent}#code{letter-spacing:3px;text-transform:uppercase;font-weight:800}
button{font:inherit;cursor:pointer}
.primary{width:100%;margin-top:16px;padding:13px;border:0;border-radius:12px;background:linear-gradient(135deg,var(--blue),var(--blue-2));color:#fff;font-weight:800;font-size:15px;transition:transform .12s,filter .12s}
.primary:hover{filter:brightness(1.08)}.primary:active{transform:scale(.98)}.primary[disabled]{opacity:.6;cursor:progress}
.notice{font-size:13px;background:#f59e0b1a;border:1px solid #f59e0b55;color:#fcd34d;border-radius:12px;padding:10px 12px;margin:10px 0 0}
.error{font-size:13px;background:#dc26261a;border:1px solid #dc262655;color:#fca5a5;border-radius:12px;padding:10px 12px;margin:10px 0 0}
.fine{font-size:12px;color:var(--muted);margin:14px 0 0;text-align:center}
.stage{flex:1;display:flex;flex-direction:column;min-height:0}
.grid{flex:1;display:grid;gap:10px;padding:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,280px),1fr));align-content:center}
.tile{position:relative;aspect-ratio:16/9;background:#0f172a;border-radius:16px;overflow:hidden;border:2px solid transparent;transition:border-color .2s;display:grid;place-items:center}
.tile.speaking{border-color:var(--teal)}.tile video{width:100%;height:100%;object-fit:cover;background:#000}
.tile .avatar{width:72px;height:72px;border-radius:50%;background:linear-gradient(135deg,var(--blue),var(--teal));display:grid;place-items:center;font-weight:800;font-size:26px}
.tile .name{position:absolute;left:10px;bottom:10px;background:#0b1020cc;padding:4px 10px;border-radius:999px;font-size:12.5px;font-weight:600;display:flex;gap:6px;align-items:center;max-width:calc(100% - 20px);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tile .name svg{width:14px;height:14px;flex:none}.tile.local .name::after{content:"(vous)";color:var(--muted);font-weight:500}
.controls{display:flex;justify-content:center;gap:12px;padding:12px 16px calc(12px + env(safe-area-inset-bottom));border-top:1px solid var(--line);background:#0b1020cc}
.ctl{display:flex;flex-direction:column;align-items:center;gap:4px;min-width:82px;padding:10px 12px;border-radius:14px;border:1px solid var(--line);background:#ffffff0f;color:var(--text);font-size:12px;font-weight:600}
.ctl svg{width:22px;height:22px}.ctl[aria-pressed="true"]{background:#fff;color:var(--navy)}.ctl.off{background:#dc26262e;color:#fca5a5}
.ctl.leave{background:var(--red);color:#fff;border-color:transparent}.ctl[disabled]{opacity:.45;cursor:not-allowed}
@media (max-width:520px){.room-title{display:none}.card{padding:20px}}
''';

  static const String _script = r'''
(function () {
  'use strict';
  var cfg = window.UNIFLOW_ROOM || {};
  var LK = window.LivekitClient;
  var $ = function (id) { return document.getElementById(id); };
  var lobby = $('lobby'), stage = $('stage'), ended = $('ended'), grid = $('grid');
  var nameInput = $('name'), codeInput = $('code'), errorBox = $('error'), joinBtn = $('join');
  var micBtn = $('mic'), camBtn = $('cam'), leaveBtn = $('leave'), countPill = $('count');
  var canPublish = window.isSecureContext && !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
  var room = null, tiles = {};

  // Le nom est gardé d'une fois sur l'autre : un étudiant qui recharge la
  // page ne doit pas le retaper. L'identité aussi, pour que la feuille de
  // présence le reconnaisse comme la même personne.
  var savedName = localStorage.getItem('uniflow.participant.name') || '';
  var identity = localStorage.getItem('uniflow.participant.identity');
  if (!identity) {
    identity = 'web-' + Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
    localStorage.setItem('uniflow.participant.identity', identity);
  }
  nameInput.value = savedName;

  if (cfg.roomName) { $('room-title').textContent = cfg.roomName; $('lobby-title').textContent = cfg.roomName; }
  $('lobby-host').textContent = cfg.hostName ? 'Réunion animée par ' + cfg.hostName + '.' : (cfg.roomId ? '' : 'Saisissez le code communiqué par l\'hôte.');
  if (cfg.code) { codeInput.value = cfg.code; }
  if (cfg.roomId && cfg.code) { $('code-field').hidden = true; }
  if (!canPublish) { $('insecure').hidden = false; }
  if (!LK) { showError('Le module de visioconférence n\'a pas pu être chargé depuis le poste hôte.'); joinBtn.disabled = true; }

  function showError(message) { errorBox.textContent = message; errorBox.hidden = !message; }

  function initials(label) {
    var parts = (label || '?').trim().split(/\s+/).slice(0, 2);
    return parts.map(function (p) { return p.charAt(0).toUpperCase(); }).join('') || '?';
  }

  function updateCount() {
    var n = room ? room.remoteParticipants.size + 1 : 0;
    countPill.textContent = n + ' participant' + (n > 1 ? 's' : '');
    countPill.hidden = !room;
  }

  function tileFor(participant) {
    var key = participant.identity;
    var tile = tiles[key];
    if (!tile) {
      tile = document.createElement('div');
      tile.className = 'tile' + (participant.isLocal ? ' local' : '');
      tile.innerHTML = '<div class="avatar"></div><div class="name"></div>';
      grid.appendChild(tile);
      tiles[key] = tile;
    }
    var label = participant.name || participant.identity;
    tile.querySelector('.avatar').textContent = initials(label);
    var nameEl = tile.querySelector('.name');
    var muted = !participant.isMicrophoneEnabled;
    nameEl.innerHTML = (muted ? MIC_OFF : '') + '<span></span>';
    nameEl.querySelector('span').textContent = label + (participant.isLocal ? ' ' : '');
    tile.classList.toggle('speaking', !!participant.isSpeaking);
    return tile;
  }

  function attachVideo(participant) {
    var tile = tileFor(participant);
    var existing = tile.querySelector('video');
    var pub = participant.getTrackPublication(LK.Track.Source.Camera);
    var track = pub && pub.track && !pub.isMuted ? pub.track : null;
    if (!track) {
      var share = participant.getTrackPublication(LK.Track.Source.ScreenShare);
      track = share && share.track ? share.track : null;
    }
    if (existing) { existing.remove(); }
    if (track) {
      var video = track.attach();
      video.muted = true;
      video.playsInline = true;
      if (participant.isLocal) { video.style.transform = 'scaleX(-1)'; }
      tile.insertBefore(video, tile.firstChild);
    }
  }

  function attachAudio(participant) {
    if (participant.isLocal) return;
    participant.audioTrackPublications.forEach(function (pub) {
      if (pub.track && !pub.track.attachedElements.length) {
        var el = pub.track.attach();
        el.style.display = 'none';
        document.body.appendChild(el);
      }
    });
  }

  function refresh(participant) { tileFor(participant); attachVideo(participant); attachAudio(participant); updateCount(); }

  function removeTile(participant) {
    var tile = tiles[participant.identity];
    if (tile) { tile.remove(); delete tiles[participant.identity]; }
    updateCount();
  }

  function renderAll() {
    refresh(room.localParticipant);
    room.remoteParticipants.forEach(refresh);
  }

  function setControls() {
    var local = room && room.localParticipant;
    var mic = !!(local && local.isMicrophoneEnabled);
    var cam = !!(local && local.isCameraEnabled);
    micBtn.setAttribute('aria-pressed', String(mic)); micBtn.classList.toggle('off', !mic);
    camBtn.setAttribute('aria-pressed', String(cam)); camBtn.classList.toggle('off', !cam);
    micBtn.disabled = camBtn.disabled = !canPublish;
    micBtn.title = canPublish ? (mic ? 'Couper le micro' : 'Activer le micro') : 'Indisponible en http (contexte non sécurisé)';
    camBtn.title = canPublish ? (cam ? 'Couper la caméra' : 'Activer la caméra') : micBtn.title;
  }

  async function join(event) {
    if (event) event.preventDefault();
    showError('');
    var name = nameInput.value.trim();
    var code = codeInput.value.trim().toUpperCase();
    if (!name) { showError('Indiquez votre nom : il figure sur la feuille de présence.'); return; }
    if (!code) { showError('Le code de la réunion est requis.'); return; }
    localStorage.setItem('uniflow.participant.name', name);
    joinBtn.disabled = true; joinBtn.textContent = 'Connexion…';
    try {
      var roomId = cfg.roomId;
      if (!roomId) {
        // Sans identifiant dans la page (code saisi à la main), l'hôte le
        // retrouve à partir du code.
        var lookup = await fetch('/rooms/by-code/' + encodeURIComponent(code));
        var found = await lookup.json();
        if (!lookup.ok) throw new Error(found.error || 'Réunion introuvable.');
        roomId = found.roomId; cfg.roomName = found.roomName;
        $('room-title').textContent = cfg.roomName || '';
      }
      var url = '/rooms/' + encodeURIComponent(roomId) + '/join?code=' + encodeURIComponent(code)
        + '&identity=' + encodeURIComponent(identity) + '&name=' + encodeURIComponent(name);
      var response = await fetch(url);
      var ticket = await response.json();
      if (!response.ok) throw new Error(ticket.error || 'La jonction a été refusée.');

      room = new LK.Room({ adaptiveStream: true, dynacast: true });
      room
        .on(LK.RoomEvent.ParticipantConnected, refresh)
        .on(LK.RoomEvent.ParticipantDisconnected, removeTile)
        .on(LK.RoomEvent.TrackSubscribed, function (_t, _p, participant) { refresh(participant); })
        .on(LK.RoomEvent.TrackUnsubscribed, function (_t, _p, participant) { refresh(participant); })
        .on(LK.RoomEvent.TrackMuted, function (_p, participant) { refresh(participant); setControls(); })
        .on(LK.RoomEvent.TrackUnmuted, function (_p, participant) { refresh(participant); setControls(); })
        .on(LK.RoomEvent.LocalTrackPublished, function () { refresh(room.localParticipant); setControls(); })
        .on(LK.RoomEvent.LocalTrackUnpublished, function () { refresh(room.localParticipant); setControls(); })
        .on(LK.RoomEvent.ActiveSpeakersChanged, function () { room.remoteParticipants.forEach(tileFor); tileFor(room.localParticipant); })
        .on(LK.RoomEvent.ParticipantNameChanged, function (_n, participant) { tileFor(participant); })
        .on(LK.RoomEvent.Disconnected, function (reason) { leaveStage(reason); });

      await room.connect(ticket.serverUrl, ticket.token);
      lobby.hidden = true; ended.hidden = true; stage.hidden = false;
      renderAll(); setControls();
      if (canPublish) {
        try { await room.localParticipant.enableCameraAndMicrophone(); }
        catch (e) { showStageNotice('Caméra ou micro refusés par le navigateur : vous êtes en écoute.'); }
        refresh(room.localParticipant); setControls();
      }
    } catch (error) {
      showError(error && error.message ? error.message : 'Connexion impossible.');
      if (room) { try { await room.disconnect(); } catch (e) {} room = null; }
    } finally {
      joinBtn.disabled = false; joinBtn.textContent = 'Entrer dans la salle';
    }
  }

  function showStageNotice(message) {
    var el = document.createElement('div');
    el.className = 'notice'; el.style.margin = '0 12px'; el.textContent = message;
    stage.insertBefore(el, grid);
    setTimeout(function () { el.remove(); }, 8000);
  }

  function leaveStage(reason) {
    Object.keys(tiles).forEach(function (k) { tiles[k].remove(); });
    tiles = {};
    document.querySelectorAll('body > audio').forEach(function (a) { a.remove(); });
    stage.hidden = true; ended.hidden = false;
    // Codes DisconnectReason du protocole LiveKit : 3 arrêt du serveur (l'hôte a
    // coupé la réunion), 4 participant retiré, 5 salle supprimée.
    var reasons = { 3: 'L\'hôte a terminé la réunion.', 4: 'Vous avez été retiré de la réunion.', 5: 'L\'hôte a terminé la réunion.' };
    $('ended-reason').textContent = reasons[reason] || 'Vous avez quitté la réunion.';
    room = null; updateCount();
  }

  micBtn.addEventListener('click', async function () {
    if (!room || !canPublish) return;
    try { await room.localParticipant.setMicrophoneEnabled(!room.localParticipant.isMicrophoneEnabled); } catch (e) { showStageNotice('Micro indisponible : ' + e.message); }
    setControls(); refresh(room.localParticipant);
  });
  camBtn.addEventListener('click', async function () {
    if (!room || !canPublish) return;
    try { await room.localParticipant.setCameraEnabled(!room.localParticipant.isCameraEnabled); } catch (e) { showStageNotice('Caméra indisponible : ' + e.message); }
    setControls(); refresh(room.localParticipant);
  });
  leaveBtn.addEventListener('click', async function () { if (room) { await room.disconnect(); } else { leaveStage(); } });
  $('rejoin').addEventListener('click', function () { ended.hidden = true; lobby.hidden = false; });
  $('join-form').addEventListener('submit', join);
  window.addEventListener('pagehide', function () { if (room) room.disconnect(); });

  var MIC_OFF = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-.4 1.5M9 9v2a3 3 0 0 0 5.1 2.1M19 11a7 7 0 0 1-11 5.7M5 11a7 7 0 0 0 .3 2M12 18v3M3 3l18 18"/></svg>';
})();
''';

  static const String _logoSvg =
      '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path d="M4 4h6v9a2 2 0 1 0 4 0V4h6v9a8 8 0 1 1-16 0z" fill="#1e3a8a"/></svg>';
  static const String _micSvg =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>';
  static const String _camSvg =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3z"/></svg>';
  static const String _leaveSvg =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4M10 17l5-5-5-5M15 12H3"/></svg>';
}
