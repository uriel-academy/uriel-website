// Direct test of Cloud Functions locally
const https = require('https');

const testGetSchoolAggregates = () => {
  const data = JSON.stringify({
    data: {
      schoolName: 'Ave Maria'
    }
  });

  const options = {
    hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
    port: 443,
    path: '/getSchoolAggregates',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': data.length
    }
  };

  console.log('Testing getSchoolAggregates...');
  const req = https.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    
    let body = '';
    res.on('data', (d) => {
      body += d;
    });
    
    res.on('end', () => {
      console.log('Response:', body);
      console.log('\n---\n');
      testGetSchoolStudents();
    });
  });

  req.on('error', (error) => {
    console.error('Error:', error);
    testGetSchoolStudents();
  });

  req.write(data);
  req.end();
};

const testGetSchoolStudents = () => {
  const data = JSON.stringify({
    data: {
      school: 'Ave Maria',
      pageSize: 10,
      includeCount: true
    }
  });

  const options = {
    hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
    port: 443,
    path: '/getSchoolStudents',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': data.length
    }
  };

  console.log('Testing getSchoolStudents...');
  const req = https.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    
    let body = '';
    res.on('data', (d) => {
      body += d;
    });
    
    res.on('end', () => {
      console.log('Response:', body);
      process.exit(0);
    });
  });

  req.on('error', (error) => {
    console.error('Error:', error);
    process.exit(1);
  });

  req.write(data);
  req.end();
};

testGetSchoolAggregates();
