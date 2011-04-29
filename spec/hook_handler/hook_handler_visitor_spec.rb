require "rubygems"
require "evalhook"

describe EvalHook::HookHandler, "hook handler visitor" do

  class X
    def foo

    end

    def bar(*x)

    end
  end

  def self.visitor_it(code, name)
    it name do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      hh.evalhook(code)

      entry_point(x)
    end
  end

  it "should capture inside method" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      hh.evalhook("
        def bar(x)
          x.foo
        end
        ", binding)
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
        ", binding
      )

      y2 = Y2.new
      y2.bar(x)

  end

  it "should capture inside class and yield" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method)
      hh.should_receive(:handle_method).with(X,x,:foo)

      hh.evalhook("
        class Y3
          def bar_(x)
            yield(x)
          end

          def bar(x)
            bar_(x) do |x_|
              x_.foo
            end
          end
        end
        ", binding
      )

      y3 = Y3.new
      y3.bar(x)

  end

  it "should capture inside a proc" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(Kernel, anything(),:proc)
      hh.should_receive(:handle_method).with(X,x,:foo)

      c = nil
      hh.evalhook("
          c = proc do |x| x.foo end
        ", binding
      )
      c.call(x)

  end

  it "should capture inside parameters" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)
      hh.should_receive(:handle_method).with(X,x,:bar)

      c = nil
      hh.evalhook("
          x.bar(x.foo)
        ", binding
      )
  end

  it "should capture in global assignment" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      c = nil
      hh.evalhook("
          $a = x.foo
        ", binding
      )
  end

  it "should capture in constant assignment" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      c = nil
      hh.evalhook("
          TESTCONSTANTA = x.foo
        ", binding
      )
  end

  it "should capture in dxstr system calls" do
      x = X.new
      hh = EvalHook::HookHandler.new

      hh.should_receive(:handle_method).with(X,x,:foo)

      c = nil
      hh.evalhook("
          `\#{x.foo}`
        ", binding
      )
  end

end
