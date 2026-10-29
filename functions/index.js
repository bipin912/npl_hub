
const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");

setGlobalOptions({maxInstances: 10});

initializeApp();


// Temporary setup check. This does not award or modify points.
exports.checkPointsBackend = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "You must sign in to check the points backend.",
    );
  }

  return {
    ready: true,
    message: "NPL Community points backend is connected.",
  };
});
