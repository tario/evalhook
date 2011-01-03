require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler visitor" do

  class X
    def foo

    end
  end

  def self.visitor_it(code, name)
    it name do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      hh.evalhook(code)
    end
  end

  visitor_it "x.foo", "should capture single method call"

  it "should capture inside method" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      hh.evalhook("
        def bar(x)
          x.foo
        end
        "
      )
      bar(x)

  end

  it "should capture inside class" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      hh.evalhook("
        class Y2
          def bar(x)
            x.foo
          end
        end
        "
      )

      y2 = Y2.new
      y2.bar(x)

  end

end
