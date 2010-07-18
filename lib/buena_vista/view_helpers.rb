module BuenaVista
  module ViewHelpers
    # For html_escape
    include ERB::Util

    # Splits text into two parts: a visible part and a hidden part. Useful in situations
    # where we only want to show the beginning of some text by default, and a link for
    # expanding it to display more. See specs for usage.
    def truncate_text(string_or_list_of_strings, options, &block)
      string_or_list_of_strings ||= []
      strings = string_or_list_of_strings.kind_of?(Array) ? string_or_list_of_strings : [string_or_list_of_strings]

      options.assert_valid_keys(:length)
      max_length = options[:length] or raise ArgumentError, "Please specify a :length option"

      # The cost factor is multiplied with the distance from the ideal split position.
      #
      # "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products."
      #                       ^                                       ^    ^   ^---- cost = (mid-word split cost)        * 1  = 100
      #                       |                                       |    `-------- cost = (word boundary cost)         * 5  = 50
      #                       |                                       `------------- cost = (sentence boundary cost)     * 10 = 10
      #                       `----------------------------------------------------- cost = (punctuation separator cost) * 50 = 100
      #
      # In this case, the sentence boundary split carries the lowest cost.

      common_separators = %w(/ \\ ~ | . < > : ; - = # _) + ["\xC2\xA6", "\xC2\xAB", "\xC2\xB7", "\xC2\xBB",
        "\xE2\x80\x90", "\xE2\x80\x91", "\xE2\x80\x92", "\xE2\x80\x93", "\xE2\x80\x94", "\xE2\x80\x95",
        "\xE2\x80\x96", "\xE2\x80\xA2", "\xE2\x80\x94", "\xE2\x80\xB9", "\xE2\x80\xBA"]

      common_separator_regex = /\s+(#{common_separators.map{|char| Regexp.escape(char) }.join('|')})+\s/

      split_types = {
        /\w[\.,!\?\)\]\}>'"]+\s+/ => {:cost => 1, :split => :after},  # sentence boundary
        /\s+[\(\[\{<'"]+\w/       => {:cost => 1, :split => :before}, # sentence boundary
        common_separator_regex    => {:cost => 2, :split => :before}, # punctuation surrounded by space
        / / => {:cost => 8,   :split => :before}, # word boundary
        /./ => {:cost => 100, :split => :before}  # mid-word
      }

      # Searches for matches of `regex` within `text` and returns two strings:
      # 1. all the text before a match; 2. the matched text itself plus everything thereafter.
      # The split position is the last match in `text` which obeys the condition that
      # the length of the first returned string must not be longer than `limit`.
      # If regex isn't found, returns ['', text].
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
        [before, separator + after]
      end

      # Searches for matches of `regex` within `text` and returns two strings:
      # 1. all the text before a match plus the matched text itself; 2. everything thereafter.
      # The split position is the last match in `text` which obeys the condition that
      # the length of the first returned string must not be longer than `limit`.
      # If regex isn't found, returns ['', text].
      def split_after_match(text, regex, limit)
        raise ArgumentError, "limit should be less than text length" if limit >= text.size
        before, after = '', text

        while true
          match = after.match(regex)
          break if !match || before.size + match.pre_match.size > limit
          before << match.pre_match << match.to_s
          after = match.post_match
        end
        [before, after]
      end

      first_block = true

      strings.map do |text|
        if text.size <= max_length # Below the limit
          max_length -= text.size
          yield text, ''

        elsif max_length == 0 # Already reached the limit
          yield '', text

        else
          # Try each type of split, and calculate the cost; then pick the type with the lowest cost.
          split = split_types.map do |regex, options|
            before, after = if options[:split] == :before
              split_before_match(text, regex, max_length)
            else
              split_after_match(text, regex, max_length)
            end

            # If the regex wasn't found in the first block of text, we skip this split type
            # (otherwise we'd end up with before='' in many cases). However, in subsequent
            # blocks we can treat the start of the block like a sentence boundary.
            unless first_block && before.blank?
              {:before => before, :after => after, :cost => options[:cost] * (max_length - before.size + 1) }
            end
          end.compact.sort{|type1, type2| type1[:cost] <=> type2[:cost] }.first

          max_length = 0 # After we've done one split, declare that we've reached the limit
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
  end
end
