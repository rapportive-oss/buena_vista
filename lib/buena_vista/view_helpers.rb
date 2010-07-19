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

    # Mapping of different types of string split regexes to their properties.
    SPLIT_TYPES = {
      SENTENCE_START_REGEX    => {:cost => 1, :split => :before, :description => 'sentence boundary'},
      SENTENCE_END_REGEX      => {:cost => 1, :split => :after,  :description => 'sentence boundary'},
      DISJUNCTIVE_CHARS_REGEX => {:cost => 2, :split => :before, :description => 'disjunctive punctuation'},
      / / => {:cost => 15,  :split => :before, :description => 'word boundary'},
      /./ => {:cost => 100, :split => :before, :description => 'mid-word'}
    }


    # Splits text into two parts: a visible part and a hidden part. Useful in situations
    # where we only want to show the beginning of some text by default, and a link for
    # expanding it to display more. See specs for usage.
    #
    # Tries to find a human-friendly point to split the string by defining a cost function,
    # calculating the cost of different split positions and types, and choosing the one with
    # the lowest cost. For example, a split at a sentence boundary has a much lower cost factor
    # than a split in the middle of a word. The cost factor is multiplied by the distance from
    # the ideal split position.
    #
    # Example: we want to truncate the following string to 70 characters. Naively cutting off
    # after exactly 70 chars gives:
    #
    #   "Customer Feedback 2.0 - Harness the ideas of your customers. Build gre"
    #
    # Wow, isn't that ugly? We want to do better. The following split points are considered:
    #
    #   "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products."    cost = (cost factor) * (distance + 1)
    #                         ^                                       ^    ^   ^  ^        ^--- cost = (sentence boundary cost) * 13 = 13
    #                         |                                       |    |   |  `------------ cost = (word boundary cost)     * 4  = 32
    #                         |                                       |    |   `--------------- cost = (mid-word split cost)    * 1  = 100
    #                         |                                       |    `------------------- cost = (word boundary cost)     * 5  = 50
    #                         |                                       `------------------------ cost = (sentence boundary cost) * 10 = 10
    #                         `---------------------------------------------------------------- cost = (disjunctive char cost)  * 50 = 100
    #
    # In this case, the lowest-cost split is at the sentence boundary before the word "Build".
    #
    # If a list of string blocks is passed in, the target length is applied to the concatenation
    # of those blocks, and the boundary between two blocks has the same split cost factor as a
    # sentence boundary.
    def truncate_text(string_or_list_of_strings, options, &block)
      string_or_list_of_strings ||= []
      blocks = string_or_list_of_strings.kind_of?(Array) ? string_or_list_of_strings : [string_or_list_of_strings]

      options.assert_valid_keys(:length)
      target_length = options[:length] or raise ArgumentError, "Please specify a :length option"

      first_block = true

      # Observe that because the boundary between two blocks has the same cost factor as a sentence
      # boundary, and it is lower than the cost factor of any other type of split, there can never be
      # a lower-cost split point on the other side of a block boundary. Therefore it is safe to
      # consider each block in isolation.
      blocks.map do |block|
        if block.size <= target_length # Below the limit
          target_length -= block.size
          yield block, ''

        elsif target_length == 0 # Already reached the limit
          yield '', block

        else
          # Try each type of split, and calculate the cost; then pick the type with the lowest cost.
          split = SPLIT_TYPES.map do |regex, split_type|
            # pos1 is a split position before the target position. Get the two strings into which
            # we would split if we split at pos1.
            before_pos1, after_pos1, pos1_separator, strictly_after_pos1 =
              if split_type[:split] == :before
                split_before_match(block, regex, target_length)
              elsif split_type[:split] == :after
                split_after_match(block, regex, target_length)
              end

            # pos2 is the first split position *after* the target position.
            # Get the two strings into which we would split if we split at pos2.
            before_pos2, after_pos2 =
              if !(pos2_match = strictly_after_pos1.match(regex))
                [block, '']
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
                  :cost => split_type[:cost] * (target_length - before_pos1.size + 1)
                }
              end

              # pos2 split point
              choices << {
                :before => before_pos2, :after => after_pos2, :description => split_type[:description],
                :cost => split_type[:cost] * (before_pos2.size - target_length + 1)
              }
            end
          end.compact.flatten.sort{|type1, type2| type1[:cost] <=> type2[:cost] }.first

          target_length = 0 # After we've done one split, never split any subsequent text block
          yield split[:before], split[:after]

        end.tap { first_block = false }
      end
    end


    # Convenience method for rendering truncated text as HTML. See specs for usage.
    def display_truncated_text(text, options)
      truncate_options = {:length => options.delete(:length)}
      block_tag = options.delete(:block_tag) || 'p'
      more = options.delete(:more) || " \xE2\x80\xA6" # Ellipsis character in UTF-8
      any_hidden = false

      truncate_text(text, truncate_options) do |visible, hidden|
        any_hidden ||= hidden.present?
        {
          :visible => visible.present?,
          :html => [
            html_escape(visible),
            (visible.blank?   && hidden.present?) ? html_escape(hidden) : nil,
            (visible.present? && hidden.present?) ? "<span class=\"truncated\">#{html_escape(hidden)}</span>" : nil
          ].compact
        }
      end.tap do |blocks|
        if any_hidden
          last_visible_html = blocks.select{|block| block[:visible] }.last[:html]
          last_visible_html.insert(1, "<a href=\"#\" class=\"expand-truncated\">#{html_escape(more)}</a>")
        end
      end.map do |block|
        truncated_class = ' class="truncated"' if !block[:visible]
        "<#{block_tag}#{truncated_class}>#{block[:html].join}</#{block_tag}>"
      end.join
    end

    private

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
