all: reports zh_HK.po


zh_HK.po: zh_TW.po tw2hk.pl
	./tw2hk.pl < $< > zh_HK.tmp && mv zh_HK.tmp $@


reports: fuzzies.out untranslated.out

fuzzies.out: zh_TW.po distill.rb
	./distill.rb --fuzzy --dont-wrap < $< > $@

untranslated.out: zh_TW.po distill.rb
	./distill.rb --untranslated --dont-wrap < $< > $@

.PHONEY: all reports
.DELETE_ON_ERRORS:
