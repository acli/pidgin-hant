#!/usr/bin/ruby -K0

require 'getoptlong'

STATE_MSGID        = 1
STATE_MSGSTR       = 2
STATE_MSGID_PLURAL = 3
STATE_MSGSTR_PLURAL= 4
STATE_OTHER        = 0

list_untranslated_p = nil
list_fuzzy_p = nil
verbose_p = nil

state = STATE_OTHER
@@fuzzy_p = nil
@@plural_p = nil
@@plural_index = nil
@@notes = nil
@@directives = nil
@@msgid = nil
@@msgstr = nil
@@strings = {}
@@string_fuzzy_p = {}
@@string_notes = {}
@@string_directives = {}

def flush
   if !@@msgid.nil? && !@@msgstr.nil?
      @@strings[@@msgid] = @@msgstr
      @@string_notes[@@msgid] = @@notes unless @@notes.nil?
      @@string_directives[@@msgid] = @@directives unless @@directives.nil?
      @@string_fuzzy_p[@@msgid] = true if @@fuzzy_p
      @@notes = @@directives = @@fuzzy_p = @@plural_p = @@msgid = @@msgstr = nil
   end
end

MAX_WIDTH = 64
def present( s )
   it = ''
   a = s.split(/\\n/)
   0.upto(a.length - 2) {|i| a[i] += "\\n" }
   a.each {|x|
      0.step(x.length, MAX_WIDTH) {|y|
	 it += "\"" + x[y...y+MAX_WIDTH] + "\"\n"
      }
   }
   return it
end

opts = GetoptLong.new(
   [ '--dont-wrap',     GetoptLong::NO_ARGUMENT ],
   [ '--fuzzy',         GetoptLong::NO_ARGUMENT ],
   [ '--untranslated',  GetoptLong::NO_ARGUMENT ],
   [ '--verbose', '-v', GetoptLong::NO_ARGUMENT ]
)

opts.each do |opt, arg|
   case opt
   when '--fuzzy'
      list_fuzzy_p = true
   when '--untranslated'
      list_untranslated_p = true
   when '--verbose'
      verbose_p = true
   when '--dont-wrap'
      MAX_WIDTH=65535
   end
end

loop {
   s = gets
   $stderr.puts "state=#{state.inspect}, s=#{s.inspect}" if verbose_p
break if s.nil?
   s.chop!
   if s !~ /^"(.*)\"$/ && state == STATE_MSGSTR_PLURAL && @@msgstr[@@plural_index].length == 0
      $stderr.puts "Warning: blank plural string msgstr[#{@@plural_index}] for #{@@msgid.inspect}"
   end
   if s =~ /^# (?:FIXME|NOTE|XXX)/
      if @@notes.nil?
	 @@notes = s
      else
	 @@notes += "\n" + s
      end
   elsif s =~ /^#,/
      flush
      @@directives = s
      @@fuzzy_p = true if s =~ /fuzzy/
   elsif s =~ /^msgid\s+\"(.*)\"\s*$/
      flush
      @@msgid = $1
      state = STATE_MSGID
   elsif s =~ /^msgid_plural\s+\"(.*)\"\s*$/
      flush
      @@msgid = $1
      @@plural_p = true
      @@plural_index = nil
      state = STATE_MSGID_PLURAL
   elsif s =~ /^msgstr\s+\"(.*)\"\s*$/
      @@msgstr = $1
      state = STATE_MSGSTR
   elsif s =~ /^msgstr\[(\d+)\]\s+\"(.*)\"\s*$/
      raise "msgstr[] found for non-plural msgid" unless @@plural_p
      @@plural_index = $1.to_i
      @@msgstr = [] if @@msgstr.nil? && @@plural_p
      @@msgstr[@@plural_index] = $2
      state = STATE_MSGSTR_PLURAL
   elsif s =~ /^msgid/
      $stderr.puts "Warning: unparsable msgid line (#{s})"
   elsif s =~ /^msgstr/
      $stderr.puts "Warning: unparsable msgstr line (#{s})"
   elsif s =~ /^msgstr/
      $stderr.puts "Warning: unparsable msgstr line (#{s})"
   elsif s =~ /^"(.*)\"$/
      case state
      when STATE_MSGID, STATE_MSGID_PLURAL
	 @@msgid = "" if @@msgid.nil?
	 @@msgid += $1
      when STATE_MSGSTR
	 @@msgstr = "" if @@msgstr.nil?
	 @@msgstr += $1
      when STATE_MSGSTR_PLURAL
	 @@msgstr[@@plural_index] = "" if @@msgstr[@@plural_index].nil?
	 @@msgstr[@@plural_index] += $1
      else
	 raise "Invalid continuation"
      end
   elsif s =~ /^\s*#/ || s =~ /^\s*$/
      flush
      state = STATE_OTHER
   else
      $stderr.puts "Warning: unknown line (#{s})"
      flush
      state = STATE_OTHER
   end
}

flush

list_all_p = (list_fuzzy_p.nil? && list_untranslated_p.nil? )
@@strings.sort.each { |a|
   msgid, msgstr = a
   if list_all_p
      puts @@string_notes[msgid] unless @@string_notes[msgid].nil?
   end
   if msgstr.kind_of?( String )
      if list_all_p || (list_fuzzy_p && @@string_fuzzy_p[msgid]) \
		    || (list_untranslated_p && @@strings[msgid].length == 0)

	 puts @@string_directives[msgid] unless @@string_directives[msgid].nil?
	 puts "msgid #{ present(msgid) }"
	 puts "msgstr #{ present(msgstr) }"
      end
   else
      first_p = true
      i = 0
      msgstr.each {|s|
	 if list_all_p || (list_fuzzy_p && @@string_fuzzy_p[msgid]) \
		       || (list_untranslated_p && s.length == 0)

	    if first_p
	       first_p = false
	       puts "msgid_plural #{ present(msgid) }"
	       puts @@string_directives[msgid] unless @@string_directives[msgid].nil?
	    end
	    puts "msgstr[#{ i }] #{ present(s) }"
	 end
	 i += 1
      }
   end
   puts "" if list_all_p
}
