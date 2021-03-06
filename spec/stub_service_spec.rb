require 'faraday'
require 'json'

RSpec.describe "Running the stub service" do

  let(:port) { "1237" }

  let(:faraday) do
    Faraday.new(:url => "http://localhost:#{port}") do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.response :logger do | logger |
        def logger.debug *args; end
      end
    end
  end

  let(:stub_service_options) do
    { port: port }
  end

  context "when the path has backslashes" do
    let(:pact_file_path) { File.absolute_path("test/pact.json").gsub("/", "\\") }

    it "starts up the stub service with the specified pact file" do
      with_process(stub_service_process(pact_file_path, stub_service_options)) do
        wait_for_mock_service_to_start(faraday, {})
        expect_successful_request(faraday, :get,  "/")
      end
    end
  end


  context "when the path has spaces" do
    let(:pact_file_path) { File.absolute_path("spec/support/directory with spaces/pact.json") }

    it "starts up the stub service with the specified pact file" do
      with_process(stub_service_process(pact_file_path, stub_service_options)) do
        wait_for_mock_service_to_start(faraday, {})
        expect_successful_request(faraday, :get,  "/")
      end
    end
  end
end
