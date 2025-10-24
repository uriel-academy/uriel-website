import fs from "fs";
import path from "path";
import { glob } from "glob";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import admin from "firebase-admin";

const argv = yargs(hideBin(process.argv))
  .option("data", { type: "string", demandOption: true, describe: "Directory containing JSON files" })
  .option("project", { type: "string", describe: "GCP projectId (optional)" })
  .option("questions-collection", { type: "string", default: "bece_ict" })
  .option("answers-collection", { type: "string", default: "bece_ict_answers" })
  .option("start-year", { type: "number", default: 2011 })
  .option("end-year", { type: "number", default: 2022 })
  .option("merge", { type: "boolean", default: false })
  .option("dry-run", { type: "boolean", default: false })
  .strict()
  .help()
  .argv;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error("ERROR: GOOGLE_APPLICATION_CREDENTIALS is not set.");
  process.exit(1);
}
if (!fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
  console.error("ERROR: Service account file not found at GOOGLE_APPLICATION_CREDENTIALS path.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: argv.project || undefined,
});

const db = admin.firestore();

function readJSON(p) {
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function validateQuestions(obj, year) {
  const errors = [];
  const mustFields = ["year", "variant", "subject", "multiple_choice", "essay"];
  for (const f of mustFields) if (!(f in obj)) errors.push(`Missing field '${f}'`);

  if (obj.year !== year) errors.push(`'year' mismatch: file has ${obj.year}, expected ${year}`);

  const mc = obj.multiple_choice || {};
  for (let i = 1; i <= 40; i++) {
    const k = `q${i}`;
    if (!(k in mc)) {
      errors.push(`Missing ${k}`);
      continue;
    }
    const q = mc[k];
    if (typeof q.question !== "string") errors.push(`${k}.question must be string`);
    if (!Array.isArray(q.possibleAnswers) || q.possibleAnswers.length !== 4) {
      errors.push(`${k}.possibleAnswers must be array of length 4`);
    } else {
      q.possibleAnswers.forEach((opt, idx) => {
        if (typeof opt !== "string") errors.push(`${k}.possibleAnswers[${idx}] must be string`);
      });
    }
  }
  return errors;
}

function validateAnswers(obj, year) {
  const errors = [];
  if (obj.year !== year) errors.push(`'year' mismatch: file has ${obj.year}, expected ${year}`);
  if (!obj.multiple_choice || typeof obj.multiple_choice !== "object") {
    errors.push("multiple_choice missing or not an object");
  } else {
    for (let i = 1; i <= 40; i++) {
      const k = `q${i}`;
      if (!(k in obj.multiple_choice)) errors.push(`answers missing ${k}`);
    }
  }
  return errors;
}

function findFilesForYear(dir, year) {
  const q = glob.sync(path.join(dir, `bece_ict_${year}_questions.json`));
  const a = glob.sync(path.join(dir, `bece_ict_${year}_answers.json`));
  return { q: q[0], a: a[0] };
}

async function writeInBatches(ops) {
  const limit = 450;
  for (let i = 0; i < ops.length; i += limit) {
    const batch = db.batch();
    ops.slice(i, i + limit).forEach(({ ref, data, merge }) => batch.set(ref, data, { merge }));
    await batch.commit();
  }
}

(async () => {
  const ops = [];
  for (let year = argv["start-year"]; year <= argv["end-year"]; year++) {
    const { q, a } = findFilesForYear(argv.data, year);
    if (!q && !a) {
      console.warn(`Skipping ${year}: no files found.`);
      continue;
    }

    if (q) {
      const qObj = readJSON(q);
      const qErrors = validateQuestions(qObj, year);
      if (qErrors.length) {
        console.error(`Validation errors in ${path.basename(q)}:\n - ${qErrors.join("\n - ")}`);
        process.exit(1);
      }
      const qRef = db.collection(argv["questions-collection"]).doc(String(year));
      ops.push({ ref: qRef, data: qObj, merge: argv.merge });
    } else {
      console.warn(`No questions file for ${year}`);
    }

    if (a) {
      const aObj = readJSON(a);
      const aErrors = validateAnswers(aObj, year);
      if (aErrors.length) {
        console.error(`Validation errors in ${path.basename(a)}:\n - ${aErrors.join("\n - ")}`);
        process.exit(1);
      }
      const aRef = db.collection(argv["answers-collection"]).doc(String(year));
      ops.push({ ref: aRef, data: aObj, merge: argv.merge });
    } else {
      console.warn(`No answers file for ${year}`);
    }
  }

  console.log(`Planned operations: ${ops.length}`);
  if (argv["dry-run"]) {
    console.log("Dry-run complete. No writes performed.");
    process.exit(0);
  }

  await writeInBatches(ops);
  console.log("Import complete.");
  process.exit(0);
})().catch(err => {
  console.error(err);
  process.exit(1);
});
