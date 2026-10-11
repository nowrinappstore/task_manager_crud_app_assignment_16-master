// Sends a test FCM notification that carries task data.
//
// Setup (once):
//   cd tools && npm init -y && npm install firebase-admin
//   Firebase console -> Project settings -> Service accounts -> Generate new private key
//   Save it as tools/serviceAccountKey.json  (DO NOT commit this file!)
//
// Usage:
//   node send_test_notification.js <FCM_TOKEN> <TASK_ID> [high|medium|low] ["Task title"]

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

const [token, taskId, priority = 'medium', taskTitle = 'Complete Flutter Assignment'] =
  process.argv.slice(2);

if (!token || !taskId) {
  console.error('Usage: node send_test_notification.js <FCM_TOKEN> <TASK_ID> [priority] [title]');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

// Android channels created by the app (see NotificationService)
const channelId = { high: 'task_high', medium: 'Class_channel', low: 'task_low' }[priority] || 'Class_channel';

admin
  .messaging()
  .send({
    token,
    notification: {
      title: 'New Task',
      body: `You have a new task: ${taskTitle}`,
    },
    data: { taskId, priority }, // read by the app on tap / in foreground
    android: { priority: 'high', notification: { channelId } },
  })
  .then((id) => console.log('Sent:', id))
  .catch((err) => {
    console.error('Failed:', err);
    process.exit(1);
  });
