#!/usr/bin/perl -w
#
# WARNING
# =======
# This is just an experiment to see if this is even feasible.
# Don't use this. Don't even try.
#
# NOTE
# ====
# This version supports backreferences in the replacement strings.
# Backreferences can be written either as $1 or \1. You must make
# sure that there's only one quoted group in any source string that
# uses backreferences..

# $Id$
######################################################################
# This script converts a finished Hong Kong Chinese translation
# into Hong Kong flavoured written Cantonese. No AI here, that
# is a university research topic and much more difficult than corresponding
# English one.
#
# To use this script, one should use it as a filter, instead of appending
# file name as argument (since for some reason any chinese in comment
# would be converted into garbage, should be fixed later):
#
#     hk2yue.pl < zh_HK.po > yue_HK.po
#
# In case of multiple choice, you will be prompted for an answer. But
# only existing choices are accepted for now, translators can't type
# their own.
#
######################################################################
# Some special case handling:
#
# 1. In user-defined comment before each msgid, if translator places
# 
#     # yue_HK: msgstr "blah blah blah"
#
# then this translation will be used instead of automatically convered
# one. Useful when automatic conversion doesn't work well, or
# translator doesn't want to be prompted again for that string.
#
# 2. If following special string is added in comment before file header:
#
#     # yue_HK:blah:blah2:
#     (notice the colons! there is no space in between!)
#
# this means 'blah' will be globally converted to 'blah2' throughout the
# whole file. Useful when translator were prompted too many times for
# one specific word. But _really_ make sure such word has only one
# possible meaning before using this!
# And the per-string choice documented above overrides this global choice.
#
######################################################################
# (c) 2020 by Ambrose Li <ambrose.li@gmail.com>
#
# Based on Taiwan Chinese -> Hong Kong Chinese conversion script
# (c) 2008, 2020 by Ambrose Li <ambrose.li@gmail.com>
# (c) 2005, 06, 07 Abel Cheung <abelcheung [AT] gmail [DOT] com>
#
# Based on American -> British English conversion script written by:
# (c) 2000 Abigail Brady
#     2002 Bastien Nocera
#
# Released under the GNU General Public Licence, either version 2
# or at your option, any later version
#
# NO WARRANTY!

require 5.8.0;
use strict;
use utf8;
use open qw( :encoding(UTF-8) :std );
use charnames qw( :full :short );
use feature "unicode_strings";
use POSIX qw(strftime);
use Term::ReadLine;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $mode = 0;
my $rl = Term::ReadLine->new("String Replacement");

my $msg_id = "";
my $msg_str = "";
my $force_msg_str = "";
my %remembered_choice = ();

my $是 = '(?:是(?!(?:非|日)))';
my $的 = '(?:(?<!(?:目|之))的(?!確))';

my @verbs = qw(
	中斷
	交談
	使用
	修改
	停用
	傳輸
	傳送
	允許
	兼容
	出現
	出示
	分組
	加入
	取消
	同意
	咇
	回應
	執行
	够
	夠
	大於
	存在
	安裝
	完成
	容許
	寫
	感受
	拒絕
	拖曳
	指定
	捕捉
	提供
	支援
	收到
	改正
	明白
	服務
	清除
	瀏覽
	登入
	發出
	發生
	相符
	知道
	要求
	記住
	設定
	設定
	認同
	請求
	超出
	超過
	輸入
	送來
	送出
	連線
	達到
	違反
	選取
	選擇
	選用
	遺失
	邀請
	閒置
	關閉
	附加
	隱身
	離開
	顯示
	飲醉
    );

my @counters = qw(
	份
	個
	張
	種
	項
    );

my @pronouns = qw(
	我哋
	我
	你哋
	你
	佢哋
	佢
    );

my @nouns = qw(
	D-BUS
	Farsight2
	Farstream
	GStreamer
	ID
	IPC
	IRC
	JID
	Pidgin
	TinyURL
	webcam
	上限
	下列
	下面
	主機
	主題
	交談
	人數
	代理伺服器
	伺服器
	伺服器端
	使用
	使用者
	來訊
	保證
	個人資料
	備註
	傳輸
	傳送
	內容
	函數
	分組顯示方法
	列表
	剪貼簿
	功能
	功能
	加密法
	動作
	協定
	即時訊息
	參數
	名字
	名稱
	呢度
	嘢
	回應
	回捲緩衝區
	圖示
	地址
	地方
	域名
	好友
	安裝
	密碼
	對話視窗
	帳號
	情況
	指令
	捕捉事件
	描述
	擾動
	支援
	改正
	方式
	方法
	日期
	日誌
	時間
	服務
	標準錯誤輸出
	標題
	模組
	檔案
	欄位
	清單
	瀏覽器
	特別字符
	狀態
	登入
	目錄
	空位
	系統
	終端機
	網名
	網址
	網域
	網絡
	網頁
	羣組
	聊天室
	表情
	訊息
	設定
	認證
	說明
	請求
	證書
	證書鍊
	資料庫
	資訊
	轉碼器
	通知
	通訊協定
	速率
	連線
	選項
	錯誤訊息
	閒置時間
	除錯選項
	電子郵件
	項目
	頻道
	顏色
	麥克風
    );

my @adjectives = qw(
	其他
	各種
	唯讀
	所有
	新
	有版權
	正確
	無效
	現有
	相關
	空
	空白
	自動
	離線
    );

my @adverbs = qw(
	自動
	重新
    );

# Convert a word list into a regexp matching any of the specified words
sub mkre (@) {
    return sprintf('(?:%s)', join('|', reverse sort {
	    my $det_a = $1 if $a =~ /^(?:[\(\):\?]|「)*(.*)/;
	    my $det_b = $1 if $b =~ /^(?:[\(\):\?]|「)*(.*)/;
	    return lc $det_a cmp lc $det_b || $det_a cmp $det_b;
	} @_));
}

# Convert ugly \s*\s* sequences into a single \s*
sub slightly_simplify ($) {
    my($re) = @_;
    $re =~ s/(\\s\*)+/$1/g;
    return $re;
}

# Given a tag and a regexp, insert the comment in front of the regexp
sub tagre ($$) {
    my($tag, $re) = @_;
    $tag =~ s/[\(\)]//sg;
    $re = slightly_simplify $re;
    return "(?:(?#$tag)$re)";
}

# Convert a word list into its quoted equivalents, i.e., {x: x → 「x」} where x is any word
sub quotify (@) {
    return map { s/^\s+//; s/\s+$//; "「$_」"; } @_;
}

# Convert a word list into itself unioned with its quoted equivalent
sub quotable (@) {
    return (@_, quotify mkre @_);
}

# Join a bunch of words together, inserting \s* between them where appropriate
# NOTE: if any of these words are actually regexps the behaviour is undefined =P
sub cat (@) {
    my($it, @rest) = @_;
    for my $next (@rest) {
	if ($it =~ /(?:\p{Latin})$/ && $next =~ /^(?:\p{Latin})/) {
	    $it .= '\s+';
	} elsif (!($it =~ /(?:\pP|\p{Han})$/ && $next =~ /^(?:\pP|\p{Han})/)) {
	    $it .= '\s*';
	}
	$it .= $next;
    }
    return $it;
}

my $quoted_thing = '(?:「(?:(?!(?:「|」)).)+」)';
my $valid_beginning_letter = '(?:\p{Latin}|\047|’)';
my $valid_medial_letter = '(?:\p{Latin}|-|–|:|\047|’|\.)';
my $valid_terminal_letter = '(?:\p{Latin}|\047|’)';
my $english_word = "(?:$valid_beginning_letter(?:$valid_medial_letter*$valid_terminal_letter+)?)";
my $placeholder = '(?:\s*%(?:\d+\$)?(?:\d+\.?|\d*\.\d+)?s\s*)';
my $wildcard = mkre($quoted_thing, $english_word, $placeholder);
my $counter = mkre(@counters);
my $determiner = mkre(map { (cat('呢', $_), cat('嗰', $_)); } @counters);
my $noun = tagre('N', sprintf('(?:\s*(?:%s+)\s*)', mkre($wildcard, @nouns, @pronouns)));
my $verb = tagre('V', mkre(quotable @verbs));
my $bare_number = mkre('一', '兩', '\d+\s*');
my $number = cat($bare_number, $counter);
my $adjective = tagre('ADJ', mkre(cat($noun, '嘅'), $wildcard, $determiner, $number, @adjectives));
my $adverb = tagre('A', mkre(map { cat($_, '咁'); } @adjectives, $wildcard, @adverbs));
my $noun_phrase = tagre('NP', "(?:$adjective*$noun+)");
my $verb_phrase = tagre('VP', "(?:$adverb*$verb)");
my $eot = '(?=(?:，|；|：|。|！|？|"))';

print STDERR "noun_phrase = /$noun_phrase/\n";

#
# Replace word with another
#
sub do_trans {
    my ($tf, $tt) = @_;
    $msg_str =~ s{$tf}{
	    my($pat, $it) = @_;
	    if (defined $^N) {
		    my $t = "$^N";
		    $it =~ s/[\\\$]1/$t/;
	    }
	    $it;
    }egp;
}

#
# Provide multiple choice for words
#
sub query_trans {
    # {{{
    my ($tf, @tt) = @_;
    if ( $msg_str =~ m/($tf)/i ) {

	    my $answer;
	    my $i = 0;
	    my $matched_string = $+;

	    # if word conversion is defined in header, just do it, don't ask
	    for my $key (keys %remembered_choice) {

		    # can't compare with $tf, $tf may contain PCRE constructs
		    if ( $matched_string eq $key ) {
			    do_trans ( $tf, $remembered_choice{$key} );
			    return;
		    }
	    }

	    print STDERR "\n" . ('='x75) . "\n${msg_id}\n${msg_str}\n";

	    my $prompt = "0 - Don't modify the string\n";
	    while ($i++ < @tt) {
		    $prompt .= sprintf("%d - Change '%s' to '%s'\n", $i, $matched_string, $tt[$i-1]);
	    }
	    print STDERR $prompt;

	    do {
		    ($answer = $rl->readline( "Please specify your choice (integer only): " )) =~ s/^\s*(\d+)\s*$/$1/;
		     
	    } until ( ($answer =~ m/^\d+$/) && ($answer <= @tt) );
	    if ($answer == 0) {
		    print STDERR "Not changed\n";
	    } else {
		    printf STDERR ("Result: '%s' --> '%s'\n", $matched_string, $tt[$answer-1]);
		    do_trans( $tf, $tt[$answer-1] );
	    }
    }
    # }}}
}

#
# Only apply when transforming po file header
#
sub translate_header() {
    # {{{
    my $curdate = strftime ("%Y-%m-%d %H:%M+0800", localtime());

    $msg_str =~ s/^("PO-Revision-Date: ).*\\n"/$1$curdate\\n"/m;
    #$msg_str =~ s/^("Language-Team: ).*?\\n"/$1Cantonese (Hong Kong) <community\@linuxhall.org>\\n"/ms;
    $msg_str =~ s/^("Language-Team: ).*?\\n"/$1Cantonese (Hong Kong) <https:\/\/www.github.com\/acli\/pidgin-hant>\\n"/ms;
    $msg_str =~ s/^("Language: ).*\\n"/$1yue_HK\\n"/m;
    return;
    # }}}
}

#
# List of words to be transformed
#
sub translate() {
    # {{{

    # order of the words can sometimes be important!

    # Note to Taiwanese readers:
    # 乜 = 物 but no one writes 物
    # 佢 = 渠 but no one writes 渠
    # 冇 = 無 (and some people actually write 無)
    # 咗 = 着 but no one writes 着
    # 喺 = 在 but no one writes 在
    # 嗰 = 個 but no one writes 個

    do_trans(sprintf("(?:$的|之)(%s)", $noun_phrase),				'嘅\1');
    do_trans(sprintf("(%s)$的", mkre(@nouns, @verbs, @adjectives)),		'\1嘅');
    do_trans('他們/她們|他們（她們）|他（她）們|他們|她們|它們',		'佢哋');
    do_trans('他/她|他（她）|(?<!其)他|她|它',					'佢');
    do_trans('誰(?!人)',							'邊個');
    do_trans('這是個',								'呢個係');
    do_trans('這是',								'呢個係');
    do_trans('這樣',								'咁樣');
    do_trans("這($counter)",							'呢\1');
    do_trans('這些',								'呢啲');
    do_trans('有些',								'有啲');
    do_trans('沒有',								'冇');
    do_trans('忘記了',								'唔記得咗');
    do_trans('忘記',								'唔記得');
    do_trans('只在',								'淨係喺');
    do_trans('都是',								'都係');
    do_trans("即$是",								'即係');
    do_trans("或$是",								'或者係');
    #do_trans('還是',								'定係');
    do_trans('亦可',								'都得');
    do_trans('是不是',								'係唔係');
    do_trans('(?<!恕)不是',							'唔係');
    do_trans(sprintf('(%s)不\1', mkre((qw( 會 再 到 自動 同 ), @verbs))),	'\1唔\1');
    do_trans(sprintf('不(%s)', mkre((qw( 會 再 到 自動 同 ), @verbs))),		'唔\1');
    do_trans("(大概|可能)$是",							'\1係');
    do_trans("除非$是",								'除非係');
    do_trans('不為(?!意)',							'唔係');
    do_trans('不可(?!能)(?:以)?',						'唔可以');
    do_trans(sprintf('無法%s到', $verb),					'\1唔到');
    do_trans('(?<!吃)喝',							'飲');
    do_trans('(?<!尋)找',							'搵');
    do_trans('嗶',								'咇');
    do_trans('現在',								'而今');
    do_trans('可在',								'可以喺');
    do_trans('時才',								'嘅時候先至');
    do_trans('這裏',								'呢度');
    do_trans('東西(?!南北|薈萃)',						'嘢');
    do_trans('看見',								'睇見');
    do_trans('一起',								'一齊');

    do_trans(sprintf('這(%s)', $noun_phrase),					'呢個\1');	# XXX this is technically wrong because counters

    do_trans('是否(?:為)?',							'係唔係');
    do_trans(sprintf("(%s)$是", $noun_phrase),					'\1係');
    do_trans(sprintf("$是(%s|%s)", $adjective, $noun),				'係\1');

    # This need to go first
    do_trans(sprintf('正在(%s)', $verb),					'\1緊');
    #do_trans(sprintf('在(%s)(%s)中', $verb, $noun),				'\1緊\2');	# FIXME... hmm this is going to be hard
    do_trans(sprintf('在(%s)中', $verb),					'\1緊');

    # FIXME: These look sound but they're producing strange, unexpected (albeit often correct) behaviour
    do_trans(sprintf('在(%s?%s)之?前', $noun_phrase, $verb_phrase),		'喺\1之前');
    do_trans(sprintf('在(%s?%s)時', $noun_phrase, $verb_phrase),		'喺\1嘅時候');
    do_trans(sprintf('在(%s?%s)之?後', $noun_phrase, $verb_phrase),		'喺\1之後');

    do_trans(sprintf('在(%s?%s)之?前', $verb_phrase, $noun_phrase),		'喺\1之前');
    do_trans(sprintf('在(%s?%s)時', $verb_phrase, $noun_phrase),		'喺\1嘅時候');
    do_trans(sprintf('在(%s?%s)之?後', $verb_phrase, $noun_phrase),		'喺\1之後');

    do_trans(sprintf('不在(%s)', $noun_phrase),					'唔喺\1');
    do_trans(sprintf('(?<!所)在(%s)', $noun_phrase),				'喺\1');

    do_trans(sprintf('(%s)和(?=%s)', $noun_phrase, $noun_phrase),		'\1同');

    # This needs to be near the end
    do_trans(sprintf('(%s)到了(?!(?:解|結))', $verb_phrase),			'\1到');
    do_trans(sprintf('(%s)了(?!(?:解|結))', $verb_phrase),			'\1咗');
    do_trans(sprintf('(%s咗%s%s)咗%s', $verb, $verb, $noun_phrase, $eot),	'\1');
    do_trans("了$eot",								'');

    # }}}
}

#
# Main conversion routine
#
while (<>) {
    # {{{

    if  (/^#/) {

	    # using such comment means yue_HK uses specialized translation,
	    # and shouldn't convert from zh_HK
	    if (m/^#\s*yue_HK:\s*(.*)/i) {

		    if ($mode == 0) {
			    # placing this on po file header means this is a global choice
			    if (m/^#\s*yue_HK:([^:]*):([^:]*):/i) {
				    $remembered_choice{$1} = $2;
			    }
		    } else {
			    # this is a per-string choice
			    $force_msg_str .= $1;
		    }
	    }

	    # header
	    if ($mode == 0) {
		    s/traditional\s+chinese/Chinese \(Hong Kong\)/i;
		    s/chinese\s+\(?(traditional|taiwan)\)?/Chinese \(Hong Kong\)/i;
	    }

	    print;

    } elsif (/^msgctxt/) {
	    print;
    } elsif (/^msgid/) {
	    $msg_id .= $_;
	    $mode = 1;
    } elsif (/^msgstr/) {
	    $msg_str .= $_;
	    $mode = 2;
    } elsif (/^"/) {
	    if ($mode == 1) {
		    $msg_id .= $_;
	    } elsif ($mode == 2) {
		    $msg_str .= $_;
		    # make sure substitution won't fail because of something like
		    # 硬"\n"體
		    $msg_str =~ s/\"\n\"// unless ($msg_id =~ /^msgid ""\n$/);
	    }
    } else {
	    if ($msg_id || $msg_str) {
		    if ($msg_id =~ /^msgid ""\n$/) {
			    translate_header();
		    } else {
			    if ($force_msg_str) {
				    $msg_str = $force_msg_str . "\n";
			    } else {
				    translate();
			    }
			    if ($msg_str =~ /\\n[^"]/) {
				    # 2 passes, to account for situation like \n\n
				    $msg_str =~ s/\\n([^"])/\\n"\n"$1/g;
				    $msg_str =~ s/\\n([^"])/\\n"\n"$1/g;
				    $msg_str =~ s/(msgstr(\[\d+\])? )/$1""\n/g;
			    }
		    }
		    print "$msg_id";
		    print "$msg_str";
		    $msg_id = "";
		    $msg_str = "";
		    $force_msg_str = "";
	    }
	    print $_;
    }
}

# Last message may or may not followed by new line
if ($msg_id || $msg_str) {
    if ($force_msg_str) {
	    $msg_str = $force_msg_str . "\n";
    } else {
	    translate();
    }
    if ($msg_str =~ /\\n[^"]/) {
	    # 2 passes, to account for situation like \n\n
	    $msg_str =~ s/\\n([^"])/\\n"\n"$1/g;
	    $msg_str =~ s/\\n([^"])/\\n"\n"$1/g;
	    $msg_str =~ s/(msgstr(\[\d+\])? )/$1""\n/g;
    }
    print "$msg_id";
    print "$msg_str";
    $msg_id = "";
    $msg_str = "";
    $force_msg_str = "";

    # }}}
}

# ex: sw=4 ts=8 noet ai sm:
