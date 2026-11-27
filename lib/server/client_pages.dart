// File: lib/server/client_pages.dart
// Placeholder player pages, served until the Flutter Web client exists.
// Each page connects to its player's WebSocket, shows the welcome and
// phase messages (see net/client_protocol.dart), and reconnects when the
// connection drops.

import '../net/client_protocol.dart';

const _style = '''
  body { margin: 0; padding: 24px 16px; background: #0E1114; color: #E8EAEC;
         font-family: system-ui, sans-serif; }
  .eyebrow { color: #F28A1E; font-size: 12px; letter-spacing: 2px;
             font-weight: 600; text-transform: uppercase; }
  h1 { margin: 4px 0 16px; font-size: 28px; text-transform: uppercase; }
  .card { background: #1B2127; border: 1px solid #2A3139;
          border-left: 4px solid #F28A1E; padding: 12px 16px; margin: 12px 0; }
  .dim { color: #9AA3AB; font-size: 14px; }
  .dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%;
         background: #E0503F; margin-right: 8px; }
  .dot.on { background: #7FD6A4; }
  a { color: #F28A1E; font-size: 20px; }
''';

String playerPage(int player) {
  final socketPath = ClientPaths.playerSocket(player);
  return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Player ${player + 1}</title>
<style>$_style</style>
</head>
<body>
<div class="eyebrow" id="skirmish">Combat Helper</div>
<h1>Player ${player + 1}</h1>
<div class="card">
  <div class="dim">Lance</div>
  <div id="lance">&mdash;</div>
</div>
<div class="card">
  <div><span class="dot" id="dot"></span><span id="status">Connecting&hellip;</span></div>
  <div class="dim" id="phase"></div>
</div>
<p class="dim">Placeholder page. The player controls come later.</p>
<script>
const phases = {
  ${ServerMessages.phaseLobby}: 'Waiting for the host to start the game.',
  ${ServerMessages.phasePlaying}: 'The game has started.',
};
function connect() {
  const ws = new WebSocket('ws://' + location.host + '$socketPath');
  ws.onopen = () => {
    document.getElementById('dot').classList.add('on');
    document.getElementById('status').textContent = 'Connected';
  };
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.type === '${ServerMessages.typeWelcome}') {
      document.getElementById('skirmish').textContent = m.skirmishName;
      document.getElementById('lance').textContent = m.lanceName || 'No lance';
    } else if (m.type === '${ServerMessages.typePhase}') {
      document.getElementById('phase').textContent = phases[m.phase] || m.phase;
    }
  };
  ws.onclose = () => {
    document.getElementById('dot').classList.remove('on');
    document.getElementById('status').textContent = 'Reconnecting…';
    setTimeout(connect, 2000);
  };
}
connect();
</script>
</body>
</html>
''';
}

/// Links to every player's page, for anyone who opens the bare address.
String indexPage(int playerCount) =>
    '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Combat Helper</title>
<style>$_style</style>
</head>
<body>
<div class="eyebrow">Combat Helper</div>
<h1>Pick your seat</h1>
${[for (var i = 0; i < playerCount; i++) '<p><a href="${ClientPaths.playerPage(i)}">Player ${i + 1}</a></p>'].join('\n')}
</body>
</html>
''';
