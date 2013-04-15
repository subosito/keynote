# encoding: UTF-8

require "helper"
require "fileutils"

module Keynote
  describe Inline do
    class InlineUser
      extend Keynote::Inline
      inline :erb

      def simple_template
        erb
        # Here's some math: <%= 2 + 2 %>
      end

      def ivars
        @greetee = "world"
        erb
        # Hello <%= @greetee %>!
      end

      def locals_from_hash
        erb local: "H"
        # Local <%= local %>
      end

      def locals_from_binding
        local = "H"
        erb binding
        # Local <%= local %>
      end

      def method_calls
        erb
        # <%= locals_from_hash %>
        # <%= locals_from_binding %>
      end
    end

    before do
      Keynote::Inline::TiltCache.reset
    end

    it "should render a template" do
      InlineUser.new.simple_template.strip.must_equal "Here's some math: 4"
    end

    it "should see instance variables from the presenter" do
      InlineUser.new.ivars.strip.must_equal "Hello world!"
    end

    it "should see locals passed in as a hash" do
      InlineUser.new.locals_from_hash.strip.must_equal "Local H"
    end

    it "should see locals passed in as a binding" do
      InlineUser.new.locals_from_binding.strip.must_equal "Local H"
    end

    it "should be able to call other methods from the same object" do
      InlineUser.new.method_calls.strip.squeeze(" ").must_equal "Local H Local H"
    end

    it "should see updates after the file is reloaded" do
      instance = InlineUser.new

      instance.simple_template.strip.must_equal "Here's some math: 4"

      Keynote::Inline::TiltCache.
        any_instance.stubs(:read_template).returns("HELLO")

      instance.simple_template.strip.must_equal "Here's some math: 4"

      FileUtils.touch __FILE__

      instance.simple_template.must_equal "HELLO"
    end
  end
end
