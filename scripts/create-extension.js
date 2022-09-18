require("dotenv").config();
const pg = require("pg");
const { Client } = pg;

async function createExtension() {
  const DATABASE_URL = process.env.DATABASE_URL;
  if (!DATABASE_URL) {
    throw new Error("DATABASE_URL is not set");
  }

  const client = new Client({
    connectionString: DATABASE_URL,
    ssl: {
      rejectUnauthorized: false
    }
  });
  await client.connect();
  await client.query("CREATE EXTENSION IF NOT EXISTS pg_trgm;");
}

createExtension()
  .then(() => process.exit(0))
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
