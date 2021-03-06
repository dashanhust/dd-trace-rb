require 'ddtrace/contrib/rails/rails_helper'
require 'ddtrace/contrib/rails/framework'
require 'ddtrace/contrib/rails/middlewares'
require 'ddtrace/contrib/rack/middlewares'

RSpec.describe 'Rails application' do
  before(:each) { skip 'Test not compatible with Rails < 4.0' if Rails.version < '4.0' }
  include_context 'Rails test application'

  let(:tracer) { ::Datadog::Tracer.new(writer: FauxWriter.new) }

  let(:routes) { { '/' => 'test#index' } }
  let(:controllers) { [controller] }

  let(:controller) do
    stub_const('TestController', Class.new(ActionController::Base) do
      def index
        head :ok
      end
    end)
  end

  RSpec::Matchers.define :have_kind_of_middleware do |expected|
    match do |actual|
      while actual
        return true if actual.class <= expected
        without_warnings { actual = actual.instance_variable_get(:@app) }
      end
      false
    end
  end

  before(:each) do
    Datadog.configure do |c|
      c.tracer hostname: ENV.fetch('TEST_DDAGENT_HOST', 'localhost')
      c.use :rails, rails_options if use_rails
    end
  end

  let(:use_rails) { true }
  let(:rails_options) { { tracer: tracer } }

  describe 'with Rails integration #middleware option' do
    context 'set to true' do
      let(:rails_options) { super().merge(middleware: true) }

      it { expect(app).to have_kind_of_middleware(Datadog::Contrib::Rack::TraceMiddleware) }
      it { expect(app).to have_kind_of_middleware(Datadog::Contrib::Rails::ExceptionMiddleware) }
    end

    context 'set to false' do
      let(:rails_options) { super().merge(middleware: false) }
      after(:each) { Datadog.configuration[:rails][:middleware] = true }

      it { expect(app).to_not have_kind_of_middleware(Datadog::Contrib::Rack::TraceMiddleware) }
      it { expect(app).to_not have_kind_of_middleware(Datadog::Contrib::Rails::ExceptionMiddleware) }
    end
  end
end
