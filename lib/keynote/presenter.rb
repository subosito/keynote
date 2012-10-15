# encoding: UTF-8

module Keynote
  class Presenter
    include Keynote::Rumble

    class << self
      def presents(*objects)
        objects.unshift :view
        attr_reader *objects

        param_list = objects.join(', ')
        ivar_list  = objects.map { |o| "@#{o}" }.join(', ')

        class_eval <<-RUBY
          def initialize(#{param_list})  # def initialize(view, foo)
            #{ivar_list} = #{param_list} #   @view, @foo = view, foo
          end                            # end
        RUBY
      end
    end

    def initialize(view)
      @view = view
    end

    def present(*args)
      Keynote.present(@view, *args)
    end
    alias p present

    def respond_to_missing?(method_name, include_private = true)
      @view.respond_to?(method_name, true)
    end

    def method_missing(method_name, *args, &block)
      if @view.respond_to?(method_name, true)
        @view.send(method_name, *args, &block)
      else
        super
      end
    end
  end
end