global.sandbox = require('sandboxed-module');
global.sinon = require('sinon');
global.chai = require('chai');
global.expect = chai.expect;
global.should = chai.should();

var sinonChai = require('sinon-chai');
chai.use(sinonChai);

global.mocks = require('./mocks');
global.libPath = process.env.BOTER_COV
  ? '../lib-cov/'
  : '../lib/';
