importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js");

// Bilgileri firebase_options.dart dosyasındaki "web" kısmından al
firebase.initializeApp({
  apiKey: "AIzaSyChOTHvk3b-9sK6V13WQUaSrv9mhHCcqrQ",
  authDomain: "tesvikavcisi-ef866.firebaseapp.com",
  projectId: "tesvikavcisi-ef866",
  storageBucket: "tesvikavcisi-ef866.appspot.com",
  messagingSenderId: "268638465842",
  appId: "1:268638465842:web:fa154b6066fe46489a712b"
});

const messaging = firebase.messaging();