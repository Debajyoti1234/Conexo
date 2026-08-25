/* Conexo — Firebase Cloud Messaging service worker (Web push).
 *
 * Handles BACKGROUND / CLOSED-tab web notifications and notification clicks.
 * Foreground (focused tab) notifications are shown by the Flutter app instead,
 * so there is exactly one notification per message (no duplicates).
 *
 * Firebase is used for FCM TRANSPORT ONLY. The values below are PUBLIC Firebase
 * Web config (safe to ship, not secrets). Replace the __PLACEHOLDER__ values
 * with the Firebase Console → Project settings → your Web app config. The
 * messagingSenderId/projectId/storageBucket/authDomain are already filled from
 * the existing project (conexoapp-8eeb2); only apiKey and appId are Console-only.
 *
 * Service workers cannot read Dart dart-defines, so these must be present here
 * for background push to work. Until apiKey/appId are filled, background web
 * push is inactive; the rest of Conexo Web is unaffected.
 */

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBTSq-7yw3A0-qF8R6wunjc0gckxedcl3E',
  appId: '1:733658775964:web:d3dc6df3f9f6a132f5c859',
  messagingSenderId: '733658775964',
  projectId: 'conexoapp-8eeb2',
  authDomain: 'conexoapp-8eeb2.firebaseapp.com',
  storageBucket: 'conexoapp-8eeb2.firebasestorage.app',
});

console.log('IOS_WEB_FCM_SW service_worker_loaded');

const messaging = firebase.messaging();
console.log('IOS_WEB_FCM_SW messaging_initialized firebase_initialized=true');

// Background messages. The Edge Function sends a `notification` + `data`
// payload; the browser normally auto-renders the `notification` block, so we
// only add an explicit render here as a safeguard, reusing the SAME payload.
messaging.onBackgroundMessage(function (payload) {
  console.log('IOS_WEB_FCM_SW background_message_received');
  const n = payload.notification || {};
  const d = payload.data || {};
  console.log(
    'IOS_WEB_FCM_SW notification_payload_present=' + (!!payload.notification) +
    ' data_payload_present=' + (!!payload.data)
  );
  const title = n.title || d.title || 'Conexo';
  const options = {
    body: n.body || d.body || 'You have a new message',
    icon: 'assets/logo/conexo_logo2.png',
    badge: 'assets/logo/conexo_logo2.png',
    // Collapse repeat notifications for the same conversation.
    tag: d.conversation_id || undefined,
    // Routing-only data (no secrets, no tokens, no message bodies beyond what
    // the notification already shows).
    data: {
      type: d.type || '',
      conversation_id: d.conversation_id || '',
      plan_id: d.plan_id || '',
    },
  };
  console.log('IOS_WEB_FCM_SW show_notification_started');
  return self.registration.showNotification(title, options).then(function () {
    console.log('IOS_WEB_FCM_SW show_notification_success');
  }).catch(function (e) {
    console.log('IOS_WEB_FCM_SW show_notification_failed ' + e);
  });
});

// Notification click: focus an existing Conexo tab (it will route internally
// via onMessageOpenedApp/getInitialMessage) or open the app. We pass only the
// routing identifiers in the URL hash; the app must authenticate before it can
// load the conversation, so no private data is exposed here.
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const d = (event.notification && event.notification.data) || {};
  const params = new URLSearchParams();
  if (d.type) params.set('type', d.type);
  if (d.conversation_id) params.set('conversation_id', d.conversation_id);
  if (d.plan_id) params.set('plan_id', d.plan_id);
  const target = '/?' + params.toString() + '#notification';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      for (const client of clientList) {
        if ('focus' in client) {
          if ('postMessage' in client) {
            client.postMessage({ conexoNotificationClick: true, data: d });
          }
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(target);
    })
  );
});
