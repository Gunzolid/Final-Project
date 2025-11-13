// functions/index.js (ใช้ V2 ทั้งหมด)

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
// Import เพิ่มเติมสำหรับ Auth Admin SDK
const {getAuth} = require("firebase-admin/auth");

// Initialize Firebase Admin SDK (ครั้งเดียว)
try {
  initializeApp();
} catch (e) {/* App already initialized */}
const db = getFirestore();
const authAdmin = getAuth(); // Initialize Auth Admin SDK

const kCustomPriorityOrder = [
  1, 2, 3, 27, 28, 29, 4, 30, 5, 31, 6, 32, 7, 33, 8, 34, 9, 35, 10, 36, 11,
  37, 12, 38, 13, 39, 40, 41, 42, 14, 15, 16, 43, 17, 44, 18, 45, 19, 46, 20,
  47, 21, 48, 22, 49, 23, 50, 24, 51, 25, 52, 26,
];

exports.recommendAndHold = onCall(async (request) => {
  const {uid, holdSeconds = 900} = request.data;
  if (!uid) {
    throw new HttpsError(
        "invalid-argument",
        "The function must be called with a valid user UID.",
    );
  }

  const result = await db.runTransaction(async (transaction) => {
    // Check existing hold
    const existingHoldQuery = db.collection("parking_spots").where("hold_by", "==", uid);
    const existingHoldSnap = await transaction.get(existingHoldQuery);
    if (!existingHoldSnap.empty) {
      console.log(`User ${uid} already has a held spot.`);
      return {ok: false, reason: "Already has a held spot"};
    }

    // Find available spot
    const availableSpotQuery = db.collection("parking_spots")
        .where("status", "==", "available");
    const availableSpotSnap = await transaction.get(availableSpotQuery);
    if (availableSpotSnap.empty) {
      console.log("No available spots found.");
      return {ok: false, reason: "No available spots"};
    }

    const sortedAvailableDocs = availableSpotSnap.docs
        .slice()
        .sort((a, b) => {
          const aIdRaw = Number.parseInt(a.id, 10);
          const bIdRaw = Number.parseInt(b.id, 10);
          const aId = Number.isNaN(aIdRaw) ? Number.MAX_SAFE_INTEGER : aIdRaw;
          const bId = Number.isNaN(bIdRaw) ? Number.MAX_SAFE_INTEGER : bIdRaw;
          const aRank = kCustomPriorityOrder.indexOf(aId);
          const bRank = kCustomPriorityOrder.indexOf(bId);
          const aPriority = aRank === -1 ? kCustomPriorityOrder.length + aId : aRank;
          const bPriority = bRank === -1 ? kCustomPriorityOrder.length + bId : bRank;
          if (aPriority !== bPriority) {
            return aPriority - bPriority;
          }
          return aId - bId;
        });

    const spotToHold = sortedAvailableDocs[0];
    if (!spotToHold) {
      console.log("No available spots after sorting.");
      return {ok: false, reason: "No available spots"};
    }

    const holdExpiresAt = new Date(Date.now() + holdSeconds * 1000);
    transaction.update(spotToHold.ref, {
      status: "held",
      hold_by: uid,
      hold_until: holdExpiresAt,
    });

    console.log(`Spot ${spotToHold.id} held by ${uid}.`);
    return {
      ok: true,
      docId: spotToHold.id,
      id: spotToHold.data().id,
      hold_expires_at: holdExpiresAt.toISOString(),
    };
  });
  return result;
});

/**
 * V2 Firestore Trigger: Cleans up hold info when a spot is taken.
 */
exports.onSpotTaken = onDocumentUpdated("parking_spots/{spotId}", async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();

  const statusChanged = beforeData.status !== afterData.status;
  const isNowTaken = afterData.status === "occupied" || afterData.status === "unavailable";
  const wasHeld = beforeData.hold_by != null;

  if (statusChanged && isNowTaken && wasHeld) {
    console.log(`Spot ${event.params.spotId} is ${afterData.status}. Clearing hold.`);
    return event.data.after.ref.update({
      hold_by: null,
      hold_until: null,
    });
  }
  return null;
});

/**
 * V2 Firestore Trigger: Ensures Firestore email matches Auth email on user doc update.
 */
exports.syncAuthEmailToFirestoreOnUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const userId = event.params.userId;
  const firestoreEmail = event.data.after.data().email;

  try {
    const userRecord = await authAdmin.getUser(userId);
    const authEmail = userRecord.email;

    // ถ้า Email ใน Firestore ไม่ตรงกับใน Auth ให้เขียนทับด้วยค่าจาก Auth
    if (firestoreEmail !== authEmail && authEmail) {
      console.log(`Firestore email for ${userId} (${firestoreEmail}) doesn't match Auth email (${authEmail}). Updating Firestore.`);
      return event.data.after.ref.update({email: authEmail});
    }
  } catch (error) {
    console.error(`Error fetching Auth record or updating Firestore for user ${userId}:`, error);
  }
  return null; // No update needed or error occurred
});
