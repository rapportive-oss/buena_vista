require 'spec_helper'

describe BuenaVista::ViewHelpers do
  include BuenaVista::ViewHelpers

  describe '#truncate_text' do

    # Convenience method which returns a list of [visible, hidden] pairs passed to
    # truncate_text's block parameter
    def truncation_pairs(text, options)
      [].tap do |seen_pairs|
        truncate_text(text, options) do |visible, hidden|
          seen_pairs << [visible, hidden]
        end
      end
    end

    it "should require a :length option" do
      lambda { truncate_text('hello world', {}) }.should raise_error(ArgumentError)
    end


    describe "when passed a string" do
      it "should return a single-element list containing the block's return value" do
        result = truncate_text('hello world', :length => 30) {|visible, hidden| " -- #{visible} -- " }
        result.should == [' -- hello world -- ']
      end

      describe "if the string is shorter than the target length" do
        it "should pass the string to the block's first parameter" do
          truncation_pairs('hello world', :length => 100).should == [['hello world', '']]
        end
      end

      describe "if the string is longer than the target length" do
        it "should cope with short target lengths" do
          truncation_pairs("badgers must win!", :length => 10).should == [["badgers must", " win!"]]
        end

        it "should split at a sentence boundary at less-than-target position, if appropriate" do
          truncation_pairs(
            "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products. Turn customers into champions.",
            :length => 70
          ).should == [[
            "Customer Feedback 2.0 - Harness the ideas of your customers. ",
            "Build great products. Turn customers into champions."
          ]]
        end

        it "should split at a sentence boundary at more-than-target position, if appropriate" do
          truncation_pairs(
            "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products. Turn customers into champions.",
            :length => 73
          ).should == [[
            "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products. ",
            "Turn customers into champions."
          ]]
        end

        it "should split before hyphens at less-than-target position, if appropriate" do
          truncation_pairs(
            "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products. Turn customers into champions.",
            :length => 30
          ).should == [[
            "Customer Feedback 2.0",
            " - Harness the ideas of your customers. Build great products. Turn customers into champions."
          ]]
        end

        it "should split before hyphens at more-than-target position, if appropriate" do
          truncation_pairs(
            "Customer Feedback 2.0 - Harness the ideas of your customers. Build great products. Turn customers into champions.",
            :length => 16
          ).should == [[
            "Customer Feedback 2.0",
            " - Harness the ideas of your customers. Build great products. Turn customers into champions."
          ]]
        end

        it "should split before pipe characters, if appropriate" do
          truncation_pairs(
            "Customer Feedback 2.0 | Harness the ideas of your customers | Build great products | Turn customers into champions",
            :length => 30
          ).should == [[
            "Customer Feedback 2.0",
            " | Harness the ideas of your customers | Build great products | Turn customers into champions"
          ]]
        end

        it "should split between words if there is no sentence boundary nearby" do
          truncation_pairs(
            "Customer Feedback 2.0 Harness the ideas of your customers Build great products Turn customers into champions",
            :length => 31
          ).should == [[
            "Customer Feedback 2.0 Harness",
            " the ideas of your customers Build great products Turn customers into champions"
          ]]
        end

        it "should split within words if unavoidable" do
          truncation_pairs("This is so supercalifragilisticexpialidocioussupercalifragilisticexpialidocious", :length => 32).should == [
            ["This is so supercalifragilistice", "xpialidocioussupercalifragilisticexpialidocious"]
          ]
        end
      end
    end


    describe "when passed a list of string blocks" do
      before :each do
        @example = [
          "Uservoice communities are the easiest way to turn customer feedback into action:",
          "Get Started Free accounts and trials. Sign up in 60 seconds.",
          "Join companies & organizations of all sizes that already depend on UserVoice for feedback."
        ]
      end

      it "should return a list of block return values" do
        result = truncate_text(@example, :length => 1000) do |visible, hidden|
          visible[0...9]
        end
        result.should == ['Uservoice', 'Get Start', 'Join comp']
      end

      it "should split at the previous block boundary, if appropriate" do
        truncation_pairs(@example, :length => 158).should == [
          ["Uservoice communities are the easiest way to turn customer feedback into action:", ""],
          ["Get Started Free accounts and trials. Sign up in 60 seconds.", ""],
          ["", "Join companies & organizations of all sizes that already depend on UserVoice for feedback."]
        ]
      end

      it "should split at the next block boundary, if appropriate" do
        truncation_pairs(@example, :length => 131).should == [
          ["Uservoice communities are the easiest way to turn customer feedback into action:", ""],
          ["Get Started Free accounts and trials. Sign up in 60 seconds.", ""],
          ["", "Join companies & organizations of all sizes that already depend on UserVoice for feedback."]
        ]
      end

      it "should split at a sentence boundary within a block, if appropriate" do
        truncation_pairs(@example, :length => 125).should == [
          ["Uservoice communities are the easiest way to turn customer feedback into action:", ""],
          ["Get Started Free accounts and trials. ", "Sign up in 60 seconds."],
          ["", "Join companies & organizations of all sizes that already depend on UserVoice for feedback."]
        ]
      end

      it "should split between words if there is no sentence boundary nearby" do
        truncation_pairs(@example, :length => 35).should == [
          ["Uservoice communities are the easiest", " way to turn customer feedback into action:"],
          ["", "Get Started Free accounts and trials. Sign up in 60 seconds."],
          ["", "Join companies & organizations of all sizes that already depend on UserVoice for feedback."]
        ]
      end
    end
  end



  describe "#display_truncated_text" do
    it "should wrap text in a paragraph by default" do
      display_truncated_text("hello world", :length => 100).should == "<p>hello world</p>"
    end

    it "should allow the wrapper tag to be overridden" do
      display_truncated_text("hello world", :length => 100, :block_tag => 'h1').should == "<h1>hello world</h1>"
    end

    it "should allow the wrapper tag to be omitted" do
      display_truncated_text("hello world", :length => 100, :block_tag => false).should == "hello world"
    end

    it "should HTML-escape input text" do
      display_truncated_text("a < b & c", :length => 100).should == "<p>a &lt; b &amp; c</p>"
    end

    describe "when truncating a string" do
      before(:each) { @html = display_truncated_text("hello. world.", :length => 8) }

      it "should put the truncated text in a span with class=truncated" do
        @html.should include('<span class="truncated">world.</span>')
      end

      it "should add a default link for showing the truncated text" do
        # Parse the string to avoid making assumptions about attribute ordering
        link = Hpricot(@html).search('//a').first
        link.should_not be_nil
        link.attributes['class'].should == 'expand-truncated'
      end

      it "should allow the 'more' link text to be configured" do
        display_truncated_text("hello. world.", :length => 8, :more => 'More >').should include('More &gt;')
      end

      it "should allow the 'more' link text to be omitted" do
        result = display_truncated_text("hello. world.", :length => 8, :more => nil)
        result.should == '<p>hello. <span class="truncated">world.</span></p>'
      end

      it "should allow the truncated text to be omitted completely" do
        result = display_truncated_text("hello. world.", :length => 8, :truncated_text => false)
        result.should == "<p>hello. \xE2\x80\xA6</p>"
      end

      it "should allow the truncated text's CSS class to be overridden" do
        result = display_truncated_text("hello. world.", :length => 8, :truncated_text => {:class => 'hidden'})
        result.should include('<span class="hidden">world.</span>')
      end
    end

    describe "when displaying a list of strings without truncation" do
      it "should wrap each string in a wrapper tag" do
        display_truncated_text(%w(hello world), :length => 100).should == "<p>hello</p><p>world</p>"
      end
    end

    describe "when truncating a list of strings between two strings" do
      before(:each) do
        @html = display_truncated_text(%w(hello hello wonderful world), :length => 14, :block_tag => 'div')
      end

      it "should add class=truncated to all truncated paragraphs" do
        @html.should_not include('<div class="truncated">hello</div>')
        @html.should include('<div class="truncated">wonderful</div>')
        @html.should include('<div class="truncated">world</div>')
      end

      it "should add a link for showing the truncated text to the last visible paragraph" do
        link = Hpricot(@html).search("//div[@class != 'truncated']").last.search('a').first
        link.should_not be_nil
        link.attributes['class'].should == 'expand-truncated'
      end

      it "should not create a span with class=truncated" do
        @html.should_not include('<span class="truncated">')
      end

      it "should allow the truncated text to be omitted completely" do
        result = display_truncated_text(%w(hello world), :length => 5, :truncated_text => false, :more => false)
        result.should == '<p>hello</p>'
      end

      it "should allow the truncated text's CSS class to be overridden" do
        result = display_truncated_text(%w(hello world), :length => 5, :truncated_text => {:class => 'hidden'})
        result.should include('<p class="hidden">world</p>')
      end
    end

    describe "when truncating a list of strings in the middle of a string" do
      before(:each) do
        @html = display_truncated_text(['hello hello, wonderful', 'world'], :length => 14, :block_tag => 'div')
      end

      it "should add class=truncated to all completely truncated paragraphs" do
        @html.should_not include('<div class="truncated">hello')
        @html.should include('<div class="truncated">world</div>')
      end

      it "should wrap the truncated part in a span with class=truncated" do
        @html.should include('<span class="truncated">wonderful</span>')
      end

      it "should add a link for showing the truncated text to the last visible paragraph" do
        link = Hpricot(@html).search("//div[@class != 'truncated']").last.search('a').first
        link.should_not be_nil
        link.attributes['class'].should == 'expand-truncated'
      end
    end
  end
end
