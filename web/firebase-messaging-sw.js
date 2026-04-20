self.addEventListener('install', (event) => {
  self.skipWaiting(); // activate immediately so FCM is ready without waiting for old SW to unload
});

importScripts('https://www.gstatic.com/firebasejs/10.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.3.0/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "AIzaSyDJGN1oGmrLRFnyJL3PMj2G_-hyJeKywnE", // identifier, not secret
  authDomain: "level-up-a3181.firebaseapp.com",
  projectId: "level-up-a3181",
  storageBucket: "level-up-a3181.firebasestorage.app",
  messagingSenderId: "722650087969",
  appId: "1:722650087969:web:2b812c5bb0a2c30bc8d960",
  measurementId: "G-MKLS3JS034"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  // if the message has a notification payload, the browser auto-displays it
  if (payload.notification) return;

  const notificationTitle = 'Level Up! Reminder';
  const notificationOptions = {
    body: payload.data?.body || '',
    icon: 'favicon-512.png',
    data: payload.data,
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});