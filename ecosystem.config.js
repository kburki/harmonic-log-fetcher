// pm2 config for the Harmonic log fetcher
// Location: /home/kburki/KTOO/Harmonic/ecosystem.config.js
//
// Replaces these crontab lines:
//   0 * * * *    fetch_harmonic_logs.sh -r -n 10   (hourly, recent files only)
//   0 */3 * * *  fetch_harmonic_logs.sh            (every 3 hours, full collection)
//
// The hourly quick fetch skips the hours when the full collection runs
// (0, 3, 6, 9, 12, 15, 18, 21) so the two never run at the same time.
// The full collection gets the recent files anyway.
//
// Both jobs run, exit, and show as "stopped" in `pm2 ls` until their next run.
// Start:  pm2 start ecosystem.config.js     Logs: pm2 logs harmonic-recent / harmonic-full

const HARMONIC_DIR = '/home/kburki/KTOO/Harmonic';
const SCRIPT = `${HARMONIC_DIR}/fetch_harmonic_logs.sh`;

module.exports = {
  apps: [
    {
      // Hourly: the 10 most recent log files
      name: 'harmonic-recent',
      cwd: HARMONIC_DIR,
      script: SCRIPT,
      interpreter: '/bin/bash',
      args: '-r -n 10',
      autorestart: false,
      cron_restart: '0 1,2,4,5,7,8,10,11,13,14,16,17,19,20,22,23 * * *',
      time: true, // timestamp every log line
    },
    {
      // Every 3 hours: full collection
      name: 'harmonic-full',
      cwd: HARMONIC_DIR,
      script: SCRIPT,
      interpreter: '/bin/bash',
      autorestart: false,
      cron_restart: '0 */3 * * *',
      time: true,
    },
  ],
};
