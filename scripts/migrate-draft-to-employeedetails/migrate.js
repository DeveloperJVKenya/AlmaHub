#!/usr/bin/env node
/**
 * One-time migration: move every Draft/{id} document (and its DailyHours
 * subcollection) into EmployeeDetails/{id}, then delete the Draft copy.
 *
 * Part of consolidating the app's two-collection onboarding design (Draft +
 * EmployeeDetails) into a single EmployeeDetails collection, where the
 * existing `status` field ('draft'/'submitted'/'approved'/'rejected') is the
 * only completeness signal. Both collections already use the same
 * name-based document-ID scheme (see hr_employee_onboarding_screen.dart
 * `_buildDocumentId`), so no ID remapping is needed — this is a straight
 * copy-verify-delete per document.
 *
 * Usage:
 *   node migrate.js            # dry run — reads and logs only, writes nothing
 *   node migrate.js --execute  # actually performs the migration
 *
 * Requires Application Default Credentials for an account with Firestore
 * access to the target project (already confirmed working via
 * `gcloud auth application-default print-access-token`).
 */

const admin = require('firebase-admin');

const PROJECT_ID = 'almahub-1fc5a';
const EXECUTE = process.argv.includes('--execute');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});

const db = admin.firestore();

async function migrateDoc(draftDoc) {
  const id = draftDoc.id;
  const data = draftDoc.data();

  const dailyHoursSnap = await db
    .collection('Draft')
    .doc(id)
    .collection('DailyHours')
    .get();

  console.log(
    `  [${id}] status=${data.status || 'draft'} dailyHoursDocs=${dailyHoursSnap.size}`
  );

  if (!EXECUTE) {
    return { id, ok: true, dailyHours: dailyHoursSnap.size };
  }

  try {
    // 1. Write the main doc into EmployeeDetails (merge — never clobber an
    //    existing EmployeeDetails doc with the same ID, though none should
    //    exist per the survey confirming Draft/EmployeeDetails IDs don't
    //    collide today).
    const targetRef = db.collection('EmployeeDetails').doc(id);
    await targetRef.set(data, { merge: true });

    // 2. Copy DailyHours subcollection docs.
    if (dailyHoursSnap.size > 0) {
      const batch = db.batch();
      dailyHoursSnap.docs.forEach((d) => {
        batch.set(targetRef.collection('DailyHours').doc(d.id), d.data(), {
          merge: true,
        });
      });
      await batch.commit();
    }

    // 3. Verify the write landed before deleting anything.
    const verify = await targetRef.get();
    if (!verify.exists) {
      throw new Error('post-write verification failed: target doc missing');
    }

    // 4. Only now delete the Draft copy (subcollection first, then the doc).
    if (dailyHoursSnap.size > 0) {
      const delBatch = db.batch();
      dailyHoursSnap.docs.forEach((d) => delBatch.delete(d.ref));
      await delBatch.commit();
    }
    await db.collection('Draft').doc(id).delete();

    console.log(`  [${id}] migrated ✅`);
    return { id, ok: true, dailyHours: dailyHoursSnap.size };
  } catch (err) {
    console.error(`  [${id}] FAILED — left in place: ${err.message}`);
    return { id, ok: false, error: err.message };
  }
}

async function main() {
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Mode: ${EXECUTE ? 'EXECUTE (will write/delete)' : 'DRY RUN (read-only)'}`);
  console.log('');

  const draftSnap = await db.collection('Draft').get();
  console.log(`Found ${draftSnap.size} Draft documents.\n`);

  if (draftSnap.size === 0) {
    console.log('Nothing to migrate.');
    return;
  }

  const results = [];
  for (const doc of draftSnap.docs) {
    results.push(await migrateDoc(doc));
  }

  const migrated = results.filter((r) => r.ok);
  const failed = results.filter((r) => !r.ok);
  const totalDailyHours = results.reduce((sum, r) => sum + (r.dailyHours || 0), 0);

  console.log('\n── Summary ──────────────────────────────');
  console.log(`Total Draft docs found:  ${draftSnap.size}`);
  console.log(`${EXECUTE ? 'Migrated' : 'Would migrate'}:              ${migrated.length}`);
  console.log(`Failed:                  ${failed.length}`);
  console.log(`DailyHours docs moved:   ${totalDailyHours}`);
  if (failed.length > 0) {
    console.log('\nFailed documents (left untouched in Draft):');
    failed.forEach((r) => console.log(`  - ${r.id}: ${r.error}`));
  }
  if (!EXECUTE) {
    console.log('\nThis was a dry run — no data was written or deleted.');
    console.log('Re-run with --execute to perform the migration for real.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Migration script crashed:', err);
    process.exit(1);
  });
