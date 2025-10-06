const { exec } = require('child_process');

// Use Firebase CLI to call the setAdminRole function
const email = 'studywithuriel@gmail.com';

console.log(`🚀 Setting super admin role for: ${email}`);

const command = `firebase functions:shell --project uriel-academy-41fb0`;

console.log('💡 You can now run this command in the Firebase Functions shell:');
console.log(`setAdminRole({email: "${email}"})`);
console.log('');
console.log('Or run this command directly:');
console.log(`firebase functions:call setAdminRole --data='{"email":"${email}"}' --project uriel-academy-41fb0`);