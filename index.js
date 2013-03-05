module.exports = process.env.BOTER_COV
    ? require('./lib-cov/')
    : require('./lib/');
