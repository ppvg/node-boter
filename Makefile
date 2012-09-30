COFFEE = ./node_modules/.bin/coffee --compile
REPORTER = spec
MOCHA = NODE_ENV=test ./node_modules/.bin/mocha
MOCHA_OPTS = \
	--compilers coffee:coffee-script \
	--require should \
	--colors

build:
	@$(COFFEE) --output lib/ src/

test: build
	@$(MOCHA) --reporter $(REPORTER) $(MOCHA_OPTS)

monitor:
	@$(MOCHA) --reporter min $(MOCHA_OPTS) \
	--watch --growl

coverage: instrument
	@BOTER_COV=1 $(MOCHA) $(MOCHA_OPTS) \
	--reporter html-cov > lib-cov/report.html

instrument: build
	@rm -rf ./lib-cov
	@jscoverage ./lib ./lib-cov

.PHONY: build test monitor coverage instrument

# vim: noet:st=4:sw=4
