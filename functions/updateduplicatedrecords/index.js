import pg from "pg";
const { Client } = pg;

/**
 * Describe Mergeduplicatedrecords here.
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
    const { recordSyncIds, object = "Account", fields } = event.data;
    validateField("recordSyncIds", recordSyncIds);
    validateField("fields", fields);
    const { records: recordSyncs } = await context.org.dataApi.query(
      `SELECT Id, Source_Record__c,Target_Record__c FROM Record_Sync__c WHERE Id IN ('${recordSyncIds.join(
        "','"
      )}')`
    );
    const uow = context.org.dataApi.newUnitOfWork();
    for (let i = 0; i < recordSyncs.length; i++) {
      const recordSync = recordSyncs[i].fields;
      const recordSyncToUpdate = {
        type: "Record_Sync__c",
        fields: {
          id: recordSync.id
        }
      };
      try {
        const { rows: records } = await dbClient.query(
          `SELECT id,${fields.toLowerCase()} FROM "salesforce".${object} WHERE sfid='${
            recordSync.source_record__c
          }';`
        );
        if (!records.length) {
          continue;
        }
        const sourceRecord = records[0];
        // We need to update the target record with values from source record.
        sourceRecord.id = recordSync.target_record__c;
        const recordToUpdate = {
          type: object,
          fields: sourceRecord
        };
        recordSyncToUpdate.fields.Status__c = "Updated";
        // Remove null values
        Object.keys(recordToUpdate.fields).forEach((key) => {
          if (recordToUpdate.fields[key] == null) {
            delete recordToUpdate.fields[key];
          }
        });
        uow.registerUpdate(recordToUpdate);
        uow.registerUpdate(recordSyncToUpdate);
      } catch (error) {
        logger.error(error.message);
        recordSyncToUpdate.fields.Status__c = "Failed";
        await context.org.dataApi.update(recordSyncToUpdate);
      }
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
