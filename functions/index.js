const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Triggered when a user's status changes in Realtime Database.
 * Updates the corresponding user's `online` field in Firestore.
 */
exports.onStatusChange = functions.database
  .ref('/status/{uid}')
  .onWrite(async (change, context) => {
    const status = change.after.val();
    const uid = context.params.uid;

    if (status === 'online' || status === 'offline') {
      const online = status === 'online';
      await admin
        .firestore()
        .doc(`users/${uid}`)
        .set({ online }, { merge: true });
    }

    return null;
  });
