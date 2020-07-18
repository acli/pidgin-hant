zh_HK.po: zh_TW.po tw2hk.pl
	./tw2hk.pl < $< > zh_HK.tmp && mv zh_HK.tmp $@
