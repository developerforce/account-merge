"use strict";
const sh = require("shelljs");
const chalk = require("chalk");
const pg = require("pg");
const { Client } = pg;
const log = console.log;
const { userInputPrompt } = require("./get-user-input");

(async () => {
  try {
    log("");
    log(chalk.bold("*** Please provide the following information: "));

    const input = await userInputPrompt();
    log("");

    // Delete and Upsert Accounts in both orgs
    if (input.source) {
      sh.exec(
        `sfdx force:apex:execute -f scripts/apex/delete-accounts.apex -u ${input.source}`,
        { silent: true }
      );
      sh.exec(
        `sfdx force:data:bulk:upsert -i Id -f data/Source.csv -s Account -u ${input.source}`
      );
    }
    if (input.target) {
      sh.exec(
        `sfdx force:apex:execute -f scripts/apex/delete-accounts.apex -u ${input.target}`,
        { silent: true }
      );
      sh.exec(
        `sfdx force:data:bulk:upsert -i Id -f data/Target.csv -s Account -u ${input.target}`
      );
    }

    if (input.database_url) {
      const client = new Client({
        connectionString: input.database_url,
        ssl: {
          rejectUnauthorized: false
        }
      });
      await client.connect();
      await client.query(`DELETE FROM "salesforce".account;`);
    }
    process.exit(0);
  } catch (error) {
    log(error);
    process.exit(1);
  }
})();
