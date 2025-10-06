const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin using default credentials
// Make sure you're logged in with: firebase login
admin.initializeApp({
  projectId: 'uriel-academy-41fb0'
});

const db = admin.firestore();

// RME Questions Data (1999 BECE)
const rmeQuestionsData = {
  "year": 1999,
  "subject": "Religious And Moral Education - RME",
  "q1": {
    "question": "According to Christian teaching, God created man and woman on the",
    "possibleAnswers": [
      "A. 1st day",
      "B. 2nd day", 
      "C. 3rd day",
      "D. 5th day",
      "E. 6th day"
    ]
  },
  "q2": {
    "question": "Palm Sunday is observed by Christians to remember the",
    "possibleAnswers": [
      "A. birth and baptism of Christ",
      "B. resurrection and appearance of Christ",
      "C. joyful journey of Christ into Jerusalem",
      "D. baptism of the Holy Spirit",
      "E. last supper and sacrifice of Christ"
    ]
  },
  "q3": {
    "question": "God gave Noah and his people the rainbow to remember",
    "possibleAnswers": [
      "A. the floods which destroyed the world",
      "B. the disobedience of the idol worshippers",
      "C. that God would not destroy the world with water again",
      "D. the building of the ark",
      "E. the usefulness of the heavenly bodies"
    ]
  },
  "q4": {
    "question": "All the religions in Ghana believe in",
    "possibleAnswers": [
      "A. Jesus Christ",
      "B. the Bible",
      "C. the Prophet Muhammed",
      "D. the Rain god",
      "E. the Supreme God"
    ]
  },
  "q5": {
    "question": "The Muslim prayers observed between Asr and Isha is",
    "possibleAnswers": [
      "A. Zuhr",
      "B. Jumu'ah",
      "C. Idd",
      "D. Subhi",
      "E. Maghrib"
    ]
  },
  "q6": {
    "question": "The Islamic practice where wealthy Muslims cater for the needs of the poor and needy is",
    "possibleAnswers": [
      "A. Hajj",
      "B. Zakat",
      "C. Ibrahr",
      "D. Mahr",
      "E. Talaq"
    ]
  },
  "q7": {
    "question": "Prophet Muhammed's twelfth birthday is important because",
    "possibleAnswers": [
      "A. there was Prophecy about his future",
      "B. Halimah returned him to his parents",
      "C. Amina passed away",
      "D. his father died",
      "E. Abdul Mutalib died"
    ]
  },
  "q8": {
    "question": "Muslim's last respect to the dead is by",
    "possibleAnswers": [
      "A. offering Janazah",
      "B. burial with a coffin",
      "C. dressing the corpse in suit",
      "D. sacrificing a ram",
      "E. keeping the corpse in the mortuary"
    ]
  },
  "q9": {
    "question": "Festivals are celebrated every year in order to",
    "possibleAnswers": [
      "A. make the people happy",
      "B. thank the gods for a successful year",
      "C. adore a new year",
      "D. punish the wrong doers in the community",
      "E. initiate the youth into adulthood"
    ]
  },
  "q10": {
    "question": "The burial of pieces of hair, fingernails and toenails of a corpse at his hometown signifies that",
    "possibleAnswers": [
      "A. there is life after death",
      "B. the spirit has contact with the living",
      "C. lesser gods want the spirit",
      "D. witches are powerful in one's hometown",
      "E. everyone must be buried in his hometown"
    ]
  },
  "q11": {
    "question": "Mourners from cemetery wash their hands before entering funeral house again to",
    "possibleAnswers": [
      "A. break relations with the dead",
      "B. show that they are among the living",
      "C. announce their return from the cemetery",
      "D. cleanse themselves from any curse",
      "E. enable them shake hands with the other mourners"
    ]
  },
  "q12": {
    "question": "Bringing forth children shows that man is",
    "possibleAnswers": [
      "A. sharing in God's creation",
      "B. taking God's position",
      "C. trying to be like God",
      "D. feeling self-sufficient",
      "E. controlling God's creation"
    ]
  },
  "q13": {
    "question": "Among the Asante farming is not done on Thursday because",
    "possibleAnswers": [
      "A. the soil becomes fertile on this day",
      "B. farmers have to rest on this day",
      "C. wild animals come out on this day",
      "D. it is specially reserved for the ancestors",
      "E. it is the day of the earth goddess"
    ]
  },
  "q14": {
    "question": "Which of the following months is also a special occasion on the Islamic Calendar?",
    "possibleAnswers": [
      "A. Rajab",
      "B. Ramadan",
      "C. Sha'ban",
      "D. Shawal",
      "E. Safar"
    ]
  },
  "q15": {
    "question": "The act of going round the Ka'ba seven times during the Hajj teaches",
    "possibleAnswers": [
      "A. bravery",
      "B. cleanliness",
      "C. humility",
      "D. endurance",
      "E. honesty"
    ]
  },
  "q16": {
    "question": "It is believed that burying the dead with money helps him to",
    "possibleAnswers": [
      "A. pay his debtors in the spiritual world",
      "B. pay for his fare to cross the river to the other world",
      "C. pay the ancestors for welcoming him",
      "D. take care of his needs",
      "E. remove any curse on the living"
    ]
  },
  "q17": {
    "question": "Blessed are the merciful for they shall",
    "possibleAnswers": [
      "A. see God",
      "B. obtain mercy",
      "C. inherit the earth",
      "D. be called the children of God",
      "E. be comforted"
    ]
  },
  "q18": {
    "question": "Eid-Ul-Fitr celebration teaches Muslims to",
    "possibleAnswers": [
      "A. submit to Allah",
      "B. give alms",
      "C. sacrifice themselves to God",
      "D. endure hardship",
      "E. appreciate God's mercy"
    ]
  },
  "q19": {
    "question": "The rite of throwing stones at the pillars during the Hajj signifies",
    "possibleAnswers": [
      "A. exercising of the body",
      "B. victory over the devil",
      "C. preparing to fight the enemies",
      "D. security of the holy place",
      "E. beginning of the pilgrimage"
    ]
  },
  "q20": {
    "question": "The essence of the Muslim fast of Ramadan is to",
    "possibleAnswers": [
      "A. keep the body fit",
      "B. save food",
      "C. make one become used to hunger",
      "D. guard against evil",
      "E. honour the poor and needy"
    ]
  },
  "q21": {
    "question": "The animal which is proverbially known to make good use of its time is the",
    "possibleAnswers": [
      "A. bee",
      "B. ant",
      "C. tortoise",
      "D. hare",
      "E. serpent"
    ]
  },
  "q22": {
    "question": "People normally save money in order to",
    "possibleAnswers": [
      "A. use their income wisely",
      "B. help the government to generate more revenue",
      "C. be generous to people",
      "D. prepare for the future",
      "E. avoid envious friends"
    ]
  },
  "q23": {
    "question": "Which of the following practices may cause sickness?",
    "possibleAnswers": [
      "A. throwing rubbish anyhow",
      "B. boiling untreated water",
      "C. washing fruits before eating",
      "D. cooking food properly",
      "E. washing hands before eating"
    ]
  },
  "q24": {
    "question": "One may contract a disease through the following means except",
    "possibleAnswers": [
      "A. eating contaminated food",
      "B. drinking polluted water",
      "C. breathing polluted air",
      "D. sleeping in a ventilated room",
      "E. living in overcrowded place"
    ]
  },
  "q25": {
    "question": "The youth can best help in the development of the nation through",
    "possibleAnswers": [
      "A. politics",
      "B. education",
      "C. entertainment",
      "D. farming",
      "E. trading"
    ]
  },
  "q26": {
    "question": "One of the aims of youth organization is to protect the youth from",
    "possibleAnswers": [
      "A. their parents",
      "B. their teachers",
      "C. immoral practices",
      "D. responsible parenthood",
      "E. peer pressure"
    ]
  },
  "q27": {
    "question": "Youth camps are organized purposely for the youth to",
    "possibleAnswers": [
      "A. fend for themselves",
      "B. find their parents",
      "C. learn to socialize",
      "D. run away from household chores",
      "E. form study groups"
    ]
  },
  "q28": {
    "question": "It is a bad habit to use one's leisure time in",
    "possibleAnswers": [
      "A. reading a story book",
      "B. telling stories",
      "C. playing games",
      "D. gossiping about friends",
      "E. learning a new skill"
    ]
  },
  "q29": {
    "question": "Hard work is most often crowned with",
    "possibleAnswers": [
      "A. success",
      "B. jealousy",
      "C. hatred",
      "D. failure",
      "E. favour"
    ]
  },
  "q30": {
    "question": "One of the child's responsibilities in the home is to",
    "possibleAnswers": [
      "A. sweep the compound",
      "B. provide his clothing",
      "C. pay the school fees",
      "D. pay the hospital fees",
      "E. provide his food"
    ]
  },
  "q31": {
    "question": "Which of the following is not the reason for contributing money in the church?",
    "possibleAnswers": [
      "A. provide school building",
      "B. building of hospitals",
      "C. paying the priest",
      "D. making the elders rich",
      "E. helping the poor and the needy"
    ]
  },
  "q32": {
    "question": "The traditional saying that 'one finger cannot pick a stone' means",
    "possibleAnswers": [
      "A. it is easier for people to work together",
      "B. a crab cannot give birth to a bird",
      "C. patience is good but hard to practice",
      "D. poor people have no friends",
      "E. one should take care of the environment"
    ]
  },
  "q33": {
    "question": "Kente weaving is popular among the",
    "possibleAnswers": [
      "A. Asante",
      "B. Kwahu",
      "C. Fante",
      "D. Akwapim",
      "E. Ewe"
    ]
  },
  "q34": {
    "question": "One of the rights of the child is the right",
    "possibleAnswers": [
      "A. to work on his plot",
      "B. to education",
      "C. to sweeping the classroom",
      "D. to attend school regularly",
      "E. to obey school rules"
    ]
  },
  "q35": {
    "question": "Which of the following is not taught in religious youth organization?",
    "possibleAnswers": [
      "A. serving God and nation",
      "B. leading a disciplined life",
      "C. loving one's neighbor as one's self",
      "D. being law abiding",
      "E. using violence to demand rights"
    ]
  },
  "q36": {
    "question": "Cleanliness is next to",
    "possibleAnswers": [
      "A. health",
      "B. wealth",
      "C. godliness",
      "D. happiness",
      "E. success"
    ]
  },
  "q37": {
    "question": "Good citizens have all these qualities except",
    "possibleAnswers": [
      "A. patriotism",
      "B. tolerance",
      "C. honesty",
      "D. selfishness",
      "E. obedience"
    ]
  },
  "q38": {
    "question": "Respect for other people's property teaches one to",
    "possibleAnswers": [
      "A. be liked by all",
      "B. become wealthy",
      "C. avoid trouble",
      "D. be trusted",
      "E. become popular"
    ]
  },
  "q39": {
    "question": "A stubborn child is one who",
    "possibleAnswers": [
      "A. does not go to school",
      "B. plays truancy",
      "C. does not respect others",
      "D. does not do his homework",
      "E. is the one who does not obey his parents"
    ]
  },
  "q40": {
    "question": "The traditional healer does not normally charge high fees because",
    "possibleAnswers": [
      "A. they are in the subsistence economy",
      "B. they use cowries for diagnosis",
      "C. local herbs and plants are used",
      "D. it will weaken the power of the medicine",
      "E. of the extended family relationship"
    ]
  }
};

// Correct answers
const correctAnswers = {
  "q1": "E",
  "q2": "C",
  "q3": "C",
  "q4": "E",
  "q5": "E",
  "q6": "B",
  "q7": "A",
  "q8": "A",
  "q9": "B",
  "q10": "B",
  "q11": "D",
  "q12": "A",
  "q13": "E",
  "q14": "B",
  "q15": "C",
  "q16": "B",
  "q17": "B",
  "q18": "E",
  "q19": "B",
  "q20": "D",
  "q21": "B",
  "q22": "D",
  "q23": "A",
  "q24": "D",
  "q25": "B",
  "q26": "C",
  "q27": "C",
  "q28": "D",
  "q29": "A",
  "q30": "A",
  "q31": "D",
  "q32": "A",
  "q33": "E",
  "q34": "B",
  "q35": "E",
  "q36": "C",
  "q37": "B",
  "q38": "C",
  "q39": "A",
  "q40": "C"
};

async function importRMEQuestions() {
  try {
    console.log('Starting RME questions import...');
    
    const batch = db.batch();
    let importedCount = 0;
    
    // Import each question
    for (let i = 1; i <= 40; i++) {
      const questionKey = `q${i}`;
      const questionData = rmeQuestionsData[questionKey];
      const correctAnswer = correctAnswers[questionKey];
      
      if (!questionData || !correctAnswer) {
        console.warn(`Missing data for question ${i}`);
        continue;
      }
      
      const questionDoc = {
        id: `rme_1999_q${i}`,
        questionText: questionData.question,
        type: 'multipleChoice',
        subject: 'religiousMoralEducation',
        examType: 'bece',
        year: '1999',
        section: 'A',
        questionNumber: i,
        options: questionData.possibleAnswers,
        correctAnswer: correctAnswer,
        explanation: `This is question ${i} from the 1999 BECE RME exam.`,
        marks: 1,
        difficulty: 'medium',
        topics: ['Religious And Moral Education', 'BECE', '1999'],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
        createdBy: 'system_import',
        isActive: true,
        metadata: {
          source: 'BECE 1999',
          importDate: admin.firestore.Timestamp.now(),
          verified: true
        }
      };
      
      const docRef = db.collection('questions').doc(questionDoc.id);
      batch.set(docRef, questionDoc);
      importedCount++;
      
      console.log(`Prepared question ${i}: ${questionData.question.substring(0, 50)}...`);
    }
    
    // Commit the batch
    await batch.commit();
    console.log(`✅ Successfully imported ${importedCount} RME questions to Firestore!`);
    
    // Update metadata
    await db.collection('app_metadata').doc('content').set({
      availableYears: admin.firestore.FieldValue.arrayUnion('1999'),
      availableSubjects: admin.firestore.FieldValue.arrayUnion('Religious And Moral Education - RME'),
      lastUpdated: admin.firestore.Timestamp.now(),
      rmeQuestionsImported: true,
      rmeQuestionsCount: importedCount
    }, { merge: true });
    
    console.log('✅ Updated content metadata');
    console.log('🎉 RME import completed successfully!');
    
  } catch (error) {
    console.error('❌ Error importing RME questions:', error);
  } finally {
    process.exit(0);
  }
}

// Run the import
importRMEQuestions();