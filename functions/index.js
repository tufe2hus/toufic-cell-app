const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

initializeApp();

exports.setUserPassword = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to change account passwords.");
  }

  const callerSnapshot = await getFirestore()
    .collection("users")
    .doc(request.auth.uid)
    .get();
  const caller = callerSnapshot.data();
  if (!callerSnapshot.exists || caller?.role !== "admin" || caller.isActive === false) {
    throw new HttpsError(
      "permission-denied",
      "Only an active admin can change account passwords.",
    );
  }

  const { targetUid, newPassword } = request.data ?? {};
  if (
    typeof targetUid !== "string" ||
    targetUid.length === 0 ||
    typeof newPassword !== "string" ||
    newPassword.length < 6 ||
    newPassword.length > 128
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Choose an existing account and a password between 6 and 128 characters.",
    );
  }

  const targetSnapshot = await getFirestore()
    .collection("users")
    .doc(targetUid)
    .get();
  if (!targetSnapshot.exists) {
    throw new HttpsError("not-found", "The selected application account was not found.");
  }

  try {
    await getAuth().updateUser(targetUid, { password: newPassword });
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new HttpsError(
        "not-found",
        "The selected Firebase Authentication account was not found.",
      );
    }
    console.error("Failed to update an account password.", error.code ?? error);
    throw new HttpsError("internal", "Could not update the account password.");
  }

  return { updated: true };
});
