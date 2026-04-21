// HTML renderer for GET /oauth/authorize. The browser loads this page,
// signs the user in with Firebase Auth (Google popup), and POSTs back to
// /oauth/authorize/complete to finalize the code grant.
//
// Firebase web config values are not secrets — they are embedded in every
// Firebase web app and are safe to hardcode. Source: lib/firebase_options.dart.

const FIREBASE_CONFIG = {
  apiKey: "AIzaSyCJ8L4vZX9mGOkmZQEPfnuy3v3c7orXCqM",
  authDomain: "biovolt.firebaseapp.com",
  projectId: "biovolt",
  appId: "1:551736633719:web:3b30db4fdc4c90927c9972",
  messagingSenderId: "551736633719",
};

const FIREBASE_SDK_VERSION = "10.14.1";

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;",
  })[c]);
}

function renderAuthorizePage({
  clientName,
  clientId,
  redirectUri,
  codeChallenge,
  codeChallengeMethod,
  state,
  scope,
}) {
  const oauthParams = {
    client_id: clientId,
    redirect_uri: redirectUri,
    code_challenge: codeChallenge,
    code_challenge_method: codeChallengeMethod,
    state: state,
    scope: scope,
  };

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Authorize ${escapeHtml(clientName)} — BioVolt</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #0a0e1a;
    --card: #141926;
    --border: #1f2937;
    --text: #e8ecf4;
    --muted: #8a94a8;
    --accent: #14b8a6;
    --accent-hover: #0f9e8a;
    --danger: #ef4444;
  }
  * { box-sizing: border-box; }
  html, body {
    margin: 0; padding: 0;
    background: var(--bg);
    color: var(--text);
    font-family: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 14px;
    line-height: 1.55;
    min-height: 100vh;
  }
  body {
    display: flex; align-items: center; justify-content: center;
    padding: 24px;
  }
  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 32px 28px;
    width: 100%;
    min-width: 380px;
    max-width: 480px;
  }
  .brand {
    font-weight: 700;
    font-size: 20px;
    letter-spacing: 0.02em;
    color: var(--accent);
    margin: 0 0 4px;
  }
  .brand::after {
    content: '';
    display: inline-block;
    width: 6px; height: 6px;
    background: var(--accent);
    border-radius: 50%;
    margin-left: 6px;
    vertical-align: middle;
    animation: pulse 2s infinite;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.35; }
  }
  .tagline {
    color: var(--muted);
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    margin: 0 0 28px;
  }
  h1 {
    font-size: 16px;
    font-weight: 500;
    margin: 0 0 8px;
    color: var(--text);
  }
  h1 strong { color: var(--accent); font-weight: 700; }
  .subtle {
    color: var(--muted);
    margin: 0 0 20px;
    font-size: 13px;
  }
  .consent {
    background: rgba(20, 184, 166, 0.05);
    border: 1px solid rgba(20, 184, 166, 0.2);
    border-radius: 8px;
    padding: 14px 16px;
    margin: 16px 0 24px;
  }
  .consent .heading {
    color: var(--muted);
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    margin: 0 0 8px;
  }
  .consent ul {
    margin: 0; padding: 0;
    list-style: none;
  }
  .consent li {
    font-size: 12.5px;
    color: var(--text);
    padding: 3px 0;
  }
  .consent li::before {
    content: '›';
    color: var(--accent);
    margin-right: 8px;
    font-weight: 700;
  }
  .consent li.write {
    color: var(--accent);
  }
  .disclaimer {
    color: var(--muted);
    font-size: 11.5px;
    line-height: 1.5;
    margin: 0 0 24px;
  }
  .btn {
    display: block;
    width: 100%;
    padding: 12px 16px;
    background: var(--accent);
    color: #0a0e1a;
    border: none;
    border-radius: 6px;
    font-family: inherit;
    font-size: 14px;
    font-weight: 700;
    cursor: pointer;
    transition: background 0.15s ease;
    letter-spacing: 0.02em;
  }
  .btn:hover:not(:disabled) { background: var(--accent-hover); }
  .btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .cancel {
    display: block;
    text-align: center;
    margin-top: 14px;
    color: var(--muted);
    text-decoration: none;
    font-size: 12px;
  }
  .cancel:hover { color: var(--text); }
  #status {
    margin-top: 14px;
    font-size: 12px;
    text-align: center;
    min-height: 16px;
  }
  .status-info { color: var(--muted); }
  .status-error { color: var(--danger); }
  .meta {
    margin-top: 24px;
    padding-top: 16px;
    border-top: 1px solid var(--border);
    color: var(--muted);
    font-size: 11px;
  }
  .meta code {
    color: var(--text);
    background: rgba(255,255,255,0.04);
    padding: 1px 5px;
    border-radius: 3px;
  }
</style>
</head>
<body>
<div class="card">
  <p class="brand">BioVolt</p>
  <p class="tagline">bioelectric dashboard</p>

  <h1><strong>${escapeHtml(clientName)}</strong> wants to access your BioVolt health data</h1>
  <p class="subtle">Sign in to authorize this connection.</p>

  <div class="consent">
    <p class="heading">${escapeHtml(clientName)} will be able to:</p>
    <ul>
      <li>Read your biometric sessions (heart rate, HRV, GSR, sleep)</li>
      <li>Read your active protocols and cycle history</li>
      <li>Read your bloodwork and biomarker history</li>
      <li>Read your fasting state and meal timing</li>
      <li>Read your health journal entries</li>
      <li class="write">Add new entries to your health journal</li>
    </ul>
  </div>

  <p class="disclaimer">
    BioVolt will never share your data with anyone else. You can revoke
    access anytime from your BioVolt account settings.
  </p>

  <button id="signin" class="btn" type="button">Sign in with Google</button>
  <a id="cancel" class="cancel" href="#">Cancel</a>
  <div id="status"></div>

  <div class="meta">
    redirect → <code>${escapeHtml(redirectUri)}</code>
  </div>
</div>

<script type="module">
import { initializeApp } from "https://www.gstatic.com/firebasejs/${FIREBASE_SDK_VERSION}/firebase-app.js";
import { getAuth, GoogleAuthProvider, signInWithPopup } from "https://www.gstatic.com/firebasejs/${FIREBASE_SDK_VERSION}/firebase-auth.js";

const firebaseConfig = ${JSON.stringify(FIREBASE_CONFIG)};
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const provider = new GoogleAuthProvider();

const OAUTH_PARAMS = ${JSON.stringify(oauthParams)};

const statusEl = document.getElementById('status');
const signInBtn = document.getElementById('signin');
const cancelLink = document.getElementById('cancel');

cancelLink.href = (() => {
  const u = new URL(OAUTH_PARAMS.redirect_uri);
  u.searchParams.set('error', 'access_denied');
  if (OAUTH_PARAMS.state) u.searchParams.set('state', OAUTH_PARAMS.state);
  return u.toString();
})();

signInBtn.addEventListener('click', async () => {
  statusEl.textContent = 'Signing in…';
  statusEl.className = 'status-info';
  signInBtn.disabled = true;
  try {
    const cred = await signInWithPopup(auth, provider);
    const idToken = await cred.user.getIdToken();
    const response = await fetch('/oauth/authorize/complete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken, ...OAUTH_PARAMS }),
    });
    if (!response.ok) {
      const err = await response.json().catch(() => ({}));
      throw new Error(err.error_description || err.error || 'Authorization failed');
    }
    const { redirect } = await response.json();
    window.location.href = redirect;
  } catch (e) {
    statusEl.textContent = e.message || 'Sign-in failed';
    statusEl.className = 'status-error';
    signInBtn.disabled = false;
  }
});
</script>
</body>
</html>`;
}

module.exports = { renderAuthorizePage, escapeHtml };
