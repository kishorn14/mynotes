// web/firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD9G7YmLrDfOp5rPJwu3LPkmAa_c0kO6-c",
  authDomain: "kishor-first-app.firebaseapp.com",
  projectId: "kishor-first-app",
  storageBucket: "kishor-first-app.appspot.com",
  messagingSenderId: "604306921005",
  appId: "1:604306921005:web:b5c5b84e2285a1b7024aa4",
  measurementId: "G-L6YP5WN0MR"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'Background Message';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png'
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
