const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Send push notification on new connection request
exports.sendNotificationOnConnectionRequest = functions.firestore
  .document('connectionRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const toUserId = data.to;
    const userSnap = await admin.firestore().collection('users').doc(toUserId).get();
    const fcmToken = userSnap.data().fcmToken;
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'New Connection Request',
          body: 'You have a new connection request!',
        },
        data: {
          type: 'connection_request',
          from: data.from,
        },
      });
    }
  }); 