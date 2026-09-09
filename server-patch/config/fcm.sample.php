<?php
/**
 * Firebase service account, for sending push notifications.
 *
 * Copy to config/fcm.php and fill in from the JSON key downloaded at
 * Firebase Console > Project settings > Service accounts > Generate new
 * private key. config/fcm.php is gitignored: the private key must never be
 * committed. Without this file push_service.php logs and does nothing, which
 * is a safe state, not a broken one.
 */
return [
    'project_id'   => 'your-firebase-project-id',
    'client_email' => 'firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com',
    // Paste the "private_key" value verbatim, newlines and all.
    'private_key'  => "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
];
