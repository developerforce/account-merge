const { prompt } = require('enquirer');
const sh = require('shelljs');

const userInputPrompt = async () => {
    const basicInfo = await promptBasicInfo();
    return basicInfo;
};

const promptBasicInfo = async () => {
    return await prompt([
        {
            type: 'input',
            name: 'source',
            message: 'Source Org User'
        },
        {
            type: 'input',
            name: 'target',
            message: 'Target Org User'
        },
        {
            type: 'input',
            name: 'database_url',
            message: 'Database URL'
        }
    ]);
};

module.exports = {
    userInputPrompt
};
