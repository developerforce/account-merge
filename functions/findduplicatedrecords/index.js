import pg from "pg";
const { Client } = pg;

/**
 * Describe Findduplicatedaccounts here.
 *
 * The exported method is the entry point for your code when the function is invoked.
 *
 * Following parameters are pre-configured and provided to your function on execution:
 * @param event: represents the data associated with the occurrence of an event, and
 *                 supporting metadata about the source of that occurrence.
 * @param context: represents the connection to Functions and your Salesforce org.
 * @param logger: logging handler used to capture application logs and trace specifically
 *                 to a given execution of a function.
 */

export default async function (event, context, logger) {
  let dbClient;
  try {
    dbClient = await dbConnect();
    const {
      searchFields,
      minimumScore,
      object = "Account",
      targetRecordIds,
      recordSyncRunId
    } = event.data;

    validateField("searchFields", searchFields);
    validateField("minimumScore", minimumScore);
    validateField("targetRecordIds", targetRecordIds);
    validateField("recordSyncRunId", recordSyncRunId);

    const { records: targetRecords } = await context.org.dataApi.query(
      `SELECT Id, ${searchFields} FROM Account WHERE Id IN ('${targetRecordIds.join(
        "','"
      )}')`
    );
    const uow = context.org.dataApi.newUnitOfWork();
    for (let i = 0; i < targetRecords.length; i++) {
      const targetRecord = targetRecords[i].fields;
      const query = buildQuery({
        logger,
        fields: searchFields,
        object,
        record: targetRecord,
        score: minimumScore
      });
      logger.info("QUERY: " + query);
      const { rows: records } = await dbClient.query(query);
      if (!records.length) {
        continue;
      }
      const sourceRecord = records[0];

      const recordSync = {
        type: "Record_Sync__c",
        fields: {
          Target_Record__c: targetRecord.id,
          Source_Record__c: sourceRecord.id,
          Status__c: "Pending",
          Record_Sync_Run__c: recordSyncRunId
        }
      };
      uow.registerCreate(recordSync);
    }
    await context.org.dataApi.commitUnitOfWork(uow);
  } catch (error) {
    logger.error(error.message);
    throw error;
  } finally {
    if (dbClient) {
      await dbClient.end();
    }
  }
}

function buildWhereConditions({ logger, fields, record, score }) {
  const searchFields = fields.split(",");
  const conditions = searchFields.map((field) => {
    const value = record[field] ? record[field].replaceAll("'", "''") : null;
    return value ? `SIMILARITY(${field}, '${value}') >= ${score}` : "";
  });
  return conditions.filter((c) => c !== "").join(" AND ");
}
function buildQuery({ logger, fields, object, record, score }) {
  const whereConditions = buildWhereConditions({
    logger,
    fields,
    record,
    score
  });
  return `SELECT sfid as Id,${fields} FROM "salesforce".${object} WHERE ${whereConditions} LIMIT 1;`;
}
async function dbConnect() {
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
  return client;
}

function validateField(field, value) {
  if (!value) throw new Error(`Please provide ${field}`);
}
