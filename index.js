module.exports = process.env.BOTER_COV
    ? require('./lib-cov/boter')
    : require('./lib/boter');
