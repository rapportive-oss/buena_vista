module BuenaVista
  module ViewHelpers
    # For html_escape
    include ERB::Util

    # An array of "disjunctive" characters which imply some degree of separation between the text
    # preceding and the text following it. "Conjunctive" characters like ampersand and plus are
    # not included in this list, because we would rather keep expressions like "a & b" together,
    # if we can.
    DISJUNCTIVE_CHARS = %w(/ \\ ~ | . < > : ; - = # _) + [
      "\xC2\xA6",     "\xC2\xAB",     "\xC2\xB7",     "\xC2\xBB",     # broken bar, &laquo;, middle dot, &raquo;
      "\xE2\x80\x90", "\xE2\x80\x91", "\xE2\x80\x92", "\xE2\x80\x93", # hyphen, non-breaking hyphen, figure dash, en dash
      "\xE2\x80\x94", "\xE2\x80\x95", "\xE2\x80\x96", "\xE2\x80\xA2", # em dash, horizontal bar, double bar, bullet
      "\xE2\x80\xA3", "\xE2\x80\xB9", "\xE2\x80\xBA"                  # triangular bullet, &lsaquo;, &rsaquo;
    ]

    # Regex matching disjunctive characters with whitespace on either side.
    DISJUNCTIVE_CHARS_REGEX = /\s+(#{DISJUNCTIVE_CHARS.map{|char| Regexp.escape(char) }.join('|')})+\s+/

    # Matches stuff which looks like the start of a sentence.
    SENTENCE_START_REGEX = /\s+[\(\[\{<'"]+\w/

    # Matches stuff which looks like the end of a sentence.
    SENTENCE_END_REGEX = /\w[\.,!\?\)\]\}>'"]+\s+/

    # Mapping of different types of string split regexes to their properties. The cost is an additive
    # quantity, not multiplicative (i.e. you could add a constant to all of the costs, and still get the
    # same behaviour; the reference point of zero is chosen arbitrarily), and its unit is percentage
    # of the target string length. The intuition is as follows: compare two split types, e.g.
    # sentence boundary vs. word boundary. The difference in cost is 40, which means that we'd be willing
    # to exceed or fall short of the target length by up to 40% in order to get a sentence boundary split
    # rather than a word boundary split.
    SPLIT_TYPES = {
      SENTENCE_START_REGEX    => {:cost => 0,  :split => :before, :description => 'sentence boundary'},
      SENTENCE_END_REGEX      => {:cost => 0,  :split => :after,  :description => 'sentence boundary'},
      DISJUNCTIVE_CHARS_REGEX => {:cost => 10, :split => :before, :description => 'disjunctive punctuation'},
      / / => {:cost => 40, :split => :before, :description => 'word boundary'},
      /./ => {:cost => 90, :split => :before, :description => 'mid-word'}
    }


    # Splits text into two parts: a visible part and a hidden part. Useful in situations
    # where we only want to show the beginning of some text by default, and a link for
    # expanding it to display more. See specs for usage.
    #
    # Tries to find a human-friendly point to split the string by defining a cost function,
    # calculating the cost of different split positions and types, and choosing the one with
    # the lowest cost. For example, a split at a sentence boundary has a much lower cost
    # than a split in the middle of a word. The cost is calculated as follows:
    #
    #   cost = split_type[:cost] + 100 * (target_length - result_length).abs / target_length
    #
    # where +result_length+ is the length of the string you'd end up with if you choose that
    # particular split type.
    #
    # Example: we want to truncate the following string to 70 characters. Naively cutting off
    # after exactly 70 chars gives:
    #
    #   "Customer Feedback 2.0 - Harness the ideas of your customers. Build gre"
    #
    # Wow, isn't that ugly? We want to do better. The following split points are considered:
    #
    #   "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products."    cost = (split type cost)  + distance * 100 / target_length
    #                         ^                                       ^    ^   ^  ^        ^--- cost = (sentence boundary cost) + 13 * 100 / 70 = 18.6
    #                         |                                       |    |   |  `------------ cost = (word boundary cost)     + 4  * 100 / 70 = 45.7
    #                         |                                       |    |   `--------------- cost = (mid-word split cost)    + 1  * 100 / 70 = 91.4
    #                         |                                       |    `------------------- cost = (word boundary cost)     + 5  * 100 / 70 = 47.1
    #                         |                                       `------------------------ cost = (sentence boundary cost) + 10 * 100 / 70 = 14.3
    #                         `---------------------------------------------------------------- cost = (disjunctive char cost)  + 50 * 100 / 70 = 81.4
    #
    # In this case, the lowest-cost split is at the sentence boundary before the word "Build".
    #
    # If a list of string blocks is passed in, the target length is applied to the concatenation
    # of those blocks, and the boundary between two blocks has the same split cost as a
    # sentence boundary.
    def truncate_text(string_or_list_of_strings, options, &block)
      string_or_list_of_strings ||= []
      blocks = string_or_list_of_strings.kind_of?(Array) ? string_or_list_of_strings : [string_or_list_of_strings]

      options.assert_valid_keys(:length, :whitespace)
      total_target_length = target_length = options[:length] or raise ArgumentError, "Please specify a :length option"

      whitespace = (options[:whitespace] || :normalize).to_sym

      first_block = true

      # Observe that because the boundary between two blocks has the same cost constant as a sentence
      # boundary, and it is lower than the cost constant of any other type of split, there can never be
      # a lower-cost split point on the other side of a block boundary. Therefore it is safe to
      # consider each block in isolation.
      blocks.map do |block|
        block = block.to_s
        block = block.gsub(/\s+/, ' ').strip if whitespace == :normalize

        if block.empty? && whitespace == :normalize # Strip out empty strings?
          nil

        elsif block.size <= target_length # Below the limit
          target_length -= block.size
          yield block, ''

        elsif target_length == 0 # Already reached the limit
          yield '', block

        else
          # Try each type of split, and calculate the cost; then pick the type with the lowest cost.
          split_choices = SPLIT_TYPES.map do |regex, split_type|
            try_split_type(regex, split_type, block, target_length, total_target_length, first_block)
          end.compact.flatten.sort do |type1, type2|
            type1[:cost] <=> type2[:cost]
          end

          if $DEBUG
            puts "Splitting choices:"
            split_choices.each do |choice|
              puts "    \033[0;31mCost #{choice[:cost]}\033[0m for #{choice[:description]} split: \033[0;36m#{choice[:before]}\033[0m|\033[0;34m#{choice[:after]}\033[0m"
            end
          end

          target_length = 0 # After we've done one split, never split any subsequent text block
          best_split = split_choices.first
          yield best_split[:before], best_split[:after]

        end.tap { first_block = false }
      end.compact
    end


    # Convenience method for rendering truncated text as HTML. See specs for usage.
    def display_truncated_text(text, options)
      truncate_options = {:length => options.delete(:length), :whitespace => options.delete(:whitespace)}
      any_hidden = false

      options = {
        :block_tag => "p",
        :more => "\xE2\x80\xA6", # Ellipsis character in UTF-8
        :truncated_text => {:class => 'truncated'}
      }.merge(options)

      if options[:truncated_text].kind_of?(Hash) && options[:truncated_text][:class]
        truncated_attributes = " class=\"#{options[:truncated_text][:class]}\""
      end

      truncate_text(text, truncate_options) do |visible, hidden|
        any_hidden ||= hidden.present?
        {
          :visible => visible.present?,
          :html => [
            html_escape(visible),
            (visible.present? || hidden.blank?) ? nil : html_escape(hidden),
            (visible.blank?   || hidden.blank?) ? nil : (
              truncated_attributes ? "<span#{truncated_attributes}>#{html_escape(hidden)}</span>" : nil
            )
          ].compact
        }

      end.tap do |blocks|
        if any_hidden && options[:more]
          last_visible_html = blocks.select{|block| block[:visible] }.last[:html]
          if truncated_attributes
            last_visible_html.insert(1, "<a href=\"#\" class=\"expand-truncated\">#{html_escape(options[:more])}</a>")
          else
            last_visible_html.insert(1, html_escape(options[:more]))
          end
        end

      end.map do |block|
        if block[:visible]
          if options[:block_tag]
            "<#{options[:block_tag]}>#{block[:html].join}</#{options[:block_tag]}>"
          else
            block[:html].join
          end
        elsif options[:block_tag] && truncated_attributes
          "<#{options[:block_tag]}#{truncated_attributes}>#{block[:html].join}</#{options[:block_tag]}>"
        end
      end.compact.join
    end

    private

    def try_split_type(regex, split_type, text, target_length, total_target_length, first_block)
      # pos1 is a split position before the target position. Get the two strings into which
      # we would split if we split at pos1.
      before_pos1, after_pos1, pos1_separator, strictly_after_pos1 =
        if split_type[:split] == :before
          split_before_match(text, regex, target_length)
        elsif split_type[:split] == :after
          split_after_match(text, regex, target_length)
        end

      # pos2 is the first split position *after* the target position.
      # Get the two strings into which we would split if we split at pos2.
      before_pos2, after_pos2 =
        if !(pos2_match = strictly_after_pos1.match(regex))
          [text, '']
        elsif split_type[:split] == :before
          [before_pos1 + pos1_separator + pos2_match.pre_match, pos2_match.to_s + pos2_match.post_match]
        elsif split_type[:split] == :after
          [before_pos1 + pos2_match.pre_match + pos2_match.to_s, pos2_match.post_match]
        end

      # Return both pos1 and pos2 split points. The sorting below will choose the better one.
      [].tap do |choices|
        # pos1 split point; reject empty before string (to avoid truncating everything)
        unless first_block && before_pos1.blank?
          choices << {
            :before => before_pos1, :after => after_pos1, :description => split_type[:description],
            :cost => split_type[:cost] + 100 * (target_length - before_pos1.size) / total_target_length
          }
        end

        # pos2 split point
        choices << {
          :before => before_pos2, :after => after_pos2, :description => split_type[:description],
          :cost => split_type[:cost] + 100 * (before_pos2.size - target_length) / total_target_length
        }
      end
    end

    # Searches for matches of `regex` within `text` and returns four strings:
    # 1. all the text before a match; 2. the matched text itself plus everything thereafter;
    # 3. just the matched text; 4. everything after the matched text, not including the matched text.
    # The split position is the last match in `text` which obeys the condition that
    # the length of the first returned string must not be longer than `limit`.
    # If regex isn't found, returns ['', text, '', text].
    def split_before_match(text, regex, limit)
      raise ArgumentError, "limit should be less than text length" if limit >= text.size
      before, separator, after = '', '', text

      while true
        match = after.match(regex)
        break if !match || before.size + separator.size + match.pre_match.size > limit
        before << separator << match.pre_match
        separator = match.to_s
        after = match.post_match
      end
      [before, separator + after, separator, after]
    end

    # Searches for matches of `regex` within `text` and returns four strings:
    # 1. all the text before a match plus the matched text itself; 2. everything thereafter;
    # 3. just the matched text; 4. everything after the matched text, not including the matched text.
    # The split position is the last match in `text` which obeys the condition that
    # the length of the first returned string must not be longer than `limit`.
    # If regex isn't found, returns ['', text, '', text].
    def split_after_match(text, regex, limit)
      raise ArgumentError, "limit should be less than text length" if limit >= text.size
      before, after = '', text

      while true
        match = after.match(regex)
        break if !match || before.size + match.pre_match.size > limit
        before << match.pre_match << match.to_s
        after = match.post_match
      end
      [before, after, match.to_s, after]
    end
  end
end
