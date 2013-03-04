module.exports = process.env.BOTER_COV
    ? require('./lib-cov/Boter')
    : require('./lib/Boter');
