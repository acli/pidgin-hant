# vi: set sw=8 ts=8 ai sm noet:

dest_po=../../guifications2/po
gaim_pot=$(dest_po)/guifications.pot

langs=zh_TW zh_HK yue_HK

all: reports $(addsuffix .po,$(filter-out %_TW,$(langs)))

install: all


zh_HK.po: zh_TW.po ../tw2hk.pl
	../tw2hk.pl $< > $@.tmp && mv $@.tmp $@

yue_HK.po: zh_HK.po ../hk2yue.pl
	../hk2yue.pl --show-progress $< > $@.tmp && mv $@.tmp $@

$(dest_po)/%: %
	msgmerge --no-location -o $*.tmp $< $(gaim_pot) && mv -fv $*.tmp $@


reports: fuzzies.out untranslated.out

check:
	for lang in $(langs); do msgfmt --statistics -cvo /dev/null $$lang.po; done

merge: $(gaim_pot)
	for lang in $(langs); do msgmerge -w 9999 -o $$lang.po.new $$lang.po $(gaim_pot) && mv -fv $$lang.po.new $$lang.po.annotated; done
	for lang in $(langs); do msgmerge -w 9999 --no-location -o $$lang.po.new $$lang.po $(gaim_pot) && mv -fv $$lang.po.new $$lang.po; done

install: check $(addprefix $(dest_po)/,$(addsuffix .po,$(langs)))

fuzzies.out: zh_TW.po ../distill.rb
	../distill.rb --fuzzy --dont-wrap < $< > $@

untranslated.out: zh_TW.po ../distill.rb
	../distill.rb --untranslated --dont-wrap < $< > $@

.PHONEY: all install merge reports unnumbered
.DELETE_ON_ERRORS:
