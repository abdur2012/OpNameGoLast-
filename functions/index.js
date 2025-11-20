// const functions = require('firebase-functions');
// const admin = require('firebase-admin');
// const nodemailer = require('nodemailer');

// admin.initializeApp();
// const db = admin.firestore();

// // Configure transporter using Secrets or env vars.
// // Recommended: use Firebase Functions Secrets and attach them with runWith({ secrets: [...] }).
// // Short-term fallback: read from process.env or legacy functions.config().gmail.
// function createTransporter() {
//   const gmailUser = process.env.GMAIL_USER || ((functions.config() && functions.config().gmail && functions.config().gmail.user) || null);
//   const gmailPass = process.env.GMAIL_PASS || ((functions.config() && functions.config().gmail && functions.config().gmail.pass) || null);

//   if (gmailUser && gmailPass) {
//     return nodemailer.createTransport({
//       service: 'gmail',
//       auth: { user: gmailUser, pass: gmailPass },
//     });
//   }

//   console.warn('Gmail credentials not set. Emails will fail until you set Functions Secrets or config.');
//   return null;
// }

// function generateCode() {
//   return Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit
// }

// exports.sendResetCode = functions.runWith({ secrets: ['GMAIL_USER', 'GMAIL_PASS'] }).https.onCall(async (data, context) => {
//   const nik = (data && data.nik) ? String(data.nik).trim() : null;
//   if (!nik) return { success: false, message: 'NIK diperlukan' };

//   try {
//     const snap = await db.collection('users').where('nik', '==', nik).limit(1).get();
//     if (snap.empty) return { success: false, message: 'NIK tidak ditemukan' };

//     const userDoc = snap.docs[0];
//     const user = userDoc.data();
//     const email = (user && user.email) ? String(user.email).trim() : null;
//     if (!email) return { success: false, message: 'Pengguna tidak memiliki email terdaftar' };

//     const code = generateCode();
//     const now = admin.firestore.Timestamp.now();
//     const expires = admin.firestore.Timestamp.fromMillis(Date.now() + 15 * 60 * 1000); // 15 minutes

//     await db.collection('password_resets').add({
//       nik,
//       email,
//       code,
//       createdAt: now,
//       expiresAt: expires,
//       used: false,
//     });

//     if (!transporter) {
//       return { success: false, message: 'Email transporter belum dikonfigurasi di Functions' };
//     }

//     const transporter = createTransporter();
//     if (!transporter) return { success: false, message: 'Email transporter belum dikonfigurasi di Functions' };

//     const mailOptions = {
//       from: process.env.GMAIL_USER || (functions.config() && functions.config().gmail && functions.config().gmail.user),
//       to: email,
//       subject: 'Kode Verifikasi Reset Password OpNameGo',
//       text: `Kode verifikasi Anda: ${code}. Kode ini berlaku 15 menit. Jika Anda tidak meminta reset, abaikan.`,
//       html: `<p>Hai,</p><p>Kode verifikasi untuk mereset password OpNameGo Anda adalah:</p><h2>${code}</h2><p>Kode ini berlaku 15 menit.</p><p>Jika Anda tidak meminta reset, abaikan email ini.</p>`
//     };

//     await transporter.sendMail(mailOptions);

//     return { success: true, status: 'sent' };
//   } catch (err) {
//     console.error('sendResetCode error', err);
//     return { success: false, message: String(err) };
//   }
// });

// exports.resetPassword = functions.runWith({ secrets: [] }).https.onCall(async (data, context) => {
//   const nik = (data && data.nik) ? String(data.nik).trim() : null;
//   const code = (data && data.code) ? String(data.code).trim() : null;
//   const newPassword = (data && data.newPassword) ? String(data.newPassword) : null;

//   if (!nik || !code || !newPassword) return { success: false, message: 'nik, code, dan newPassword diperlukan' };

//   try {
//     const now = admin.firestore.Timestamp.now();
//     const resetSnap = await db.collection('password_resets')
//       .where('nik', '==', nik)
//       .where('code', '==', code)
//       .where('used', '==', false)
//       .orderBy('createdAt', 'desc')
//       .limit(1)
//       .get();

//     if (resetSnap.empty) return { success: false, message: 'Kode tidak valid atau sudah digunakan' };

//     const resetDoc = resetSnap.docs[0];
//     const resetData = resetDoc.data();
//     if (!resetData.expiresAt || resetData.expiresAt.toMillis() < Date.now()) {
//       return { success: false, message: 'Kode sudah kadaluarsa' };
//     }

//     // find user doc
//     const userSnap = await db.collection('users').where('nik', '==', nik).limit(1).get();
//     if (userSnap.empty) return { success: false, message: 'NIK tidak ditemukan' };

//     const userDocRef = userSnap.docs[0].ref;

//     // Update password (note: your app stores plain text passwords currently; consider hashing)
//     await userDocRef.update({
//       password: newPassword,
//       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//     });

//     // mark reset used
//     await resetDoc.ref.update({ used: true, usedAt: now });

//     return { success: true, status: 'ok' };
//   } catch (err) {
//     console.error('resetPassword error', err);
//     return { success: false, message: String(err) };
//   }
// });


const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  host: "sandbox.smtp.mailtrap.io", // atau smtp.mailtrap.io, smtp.yourdomain.com
  port: 587,
  secure: false,
  auth: {
    user: functions.config().smtp.user,
    pass: functions.config().smtp.pass,
  },
});

exports.sendResetCode = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const code = data.code;

  const mailOptions = {
    from: `"OpnameGo Support" <${functions.config().smtp.user}>`,
    to: email,
    subject: "Kode Reset Password Anda",
    text: `Halo, berikut kode reset password Anda: ${code}`,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log("✅ Email terkirim ke:", email);
    return { success: true };
  } catch (error) {
    console.error("❌ Gagal kirim email:", error);
    return { success: false, message: error.toString() };
  }
});
