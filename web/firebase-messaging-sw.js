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

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'LevelUp Reminder';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: payload.notification?.icon || '/favicon-192.png',
    data: payload.data,
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
