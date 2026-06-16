#!/bin/bash
# Deploy Firestore security rules to Firebase.
# Run this once after adding PvP to your project.
#
# Prerequisites:
#   npm install -g firebase-tools
#   firebase login

set -e
cd "$(dirname "$0")/.."

echo "==> Deploying Firestore rules..."
firebase deploy --only firestore:rules
echo "==> Done! PvP rooms are now accessible."
