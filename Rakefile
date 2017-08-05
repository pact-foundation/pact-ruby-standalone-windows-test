require 'openssl'

LOCAL_PACKAGE_LOCATION = "tmp/pact.zip".freeze
# Simulate a Windows environment on Mac by giving it an empty cert_store
SSL_OPTIONS = {ca_file: 'cacert.pem', cert_store: OpenSSL::X509::Store.new}.freeze

def windows?
  (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
end

def github_access_token
  ENV.fetch('GITHUB_ACCESS_TOKEN')
end

def get_latest_release_asset_url release_asset_name_regexp
  require 'octokit'
  stack = Faraday::RackBuilder.new do |builder|
    builder.response :logger do | logger |
      logger.filter(/(Authorization: )(.*)/,'\1[REMOVED]')
      def logger.debug *args; end
    end
    builder.use Octokit::Response::RaiseError
    builder.adapter Faraday.default_adapter
  end
  Octokit.middleware = stack

  repository_slug = 'pact-foundation/pact-ruby-standalone'

  client = Octokit::Client.new(access_token: github_access_token)
  client.connection_options[:ssl] = SSL_OPTIONS
  release =  client.latest_release repository_slug
  release_assets = client.release_assets release.url
  zip = release_assets.find { | release_asset | release_asset.name =~ release_asset_name_regexp }
  zip.url
end

def download_release_asset url, file_path
  require 'faraday'

  faraday = Faraday.new(:url => url, :ssl => SSL_OPTIONS) do |faraday|
    faraday.adapter Faraday.default_adapter
    faraday.response :logger do | logger |
      logger.filter(/(Authorization: )(.*)/,'\1[REMOVED]')
      def logger.debug *args; end
    end
  end

  response = faraday.get do | request |
    request.headers['Accept'] = 'application/octet-stream'
    request.headers['Authorization'] = "token #{github_access_token}"
  end
  raise "Expected response status 302 but got #{response.status}" unless response.status == 302

  faraday = Faraday.new(:url => response.headers['Location'], :ssl => SSL_OPTIONS)
  response = faraday.get
  raise "Error downloading release" unless response.status == 200

  puts "Writing file #{file_path}"
  File.open(file_path, "wb") { |file| file << response.body }
  puts "Finished writing file #{file_path}"
end

def unzip_package path
  require 'zip'
  require 'pathname'

  puts "Unzipping #{path}"
  Zip::File.open(path) do |zip_file|
    zip_file.each do |entry|
      entry.extract(File.join("tmp", entry.name))
    end
  end
  puts "Finished unzipping #{path}"
end

def build_process cmd_parts, cwd = nil
  require 'childprocess'
  logger = Logger.new($stdout)
  logger.level = Logger::INFO
  ChildProcess.logger = logger
  process = ChildProcess.build(*cmd_parts)
  process.cwd = cwd if cwd
  process.leader = true if windows? # not sure if we need this
  process.io.inherit!
  process
end

def mock_service_process
  if windows?
    build_process ["cmd.exe", "/c","pact-mock-service.bat", "service", "-p", "1235"], "tmp/pact/bin"
  else
    # Manually downloaded and extracted, for local testing
    build_process ["./pact-mock-service", "service", "-p", "1235"], "osx/pact/bin"
  end
end

def test_provider_process
  if windows?
    build_process ["cmd.exe", "/c","bundle", "exec", "rackup", "-p", "1236", "test/config.ru"]
  else
    build_process ["ruby", "-S", "bundle", "exec", "rackup", "-p", "1236", "test/config.ru"]
  end
end

def pact_verifier_command
  suffix = "verify --pact-urls #{File.absolute_path("test/pact.json")} --provider-base-url http://localhost:1236"
  if windows?
    "cd tmp/pact/bin && cmd.exe /c pact-provider-verifier.bat #{suffix}"
  else
    # Manually downloaded and extracted, for local testing
    "cd osx/pact.old/bin && ./pact-provider-verifier #{suffix}"
  end
end

def mock_service_start_command port
  suffix = "start -p #{port}"
  if windows?
    "cd tmp/pact/bin && cmd.exe /c pact-mock-service.bat #{suffix}"
  else
    # Manually downloaded and extracted, for local testing
    "cd osx/pact/bin && ./pact-mock-service #{suffix}"
  end
end

def mock_service_stop_command port
  suffix = "stop -p #{port}"
  if windows?
    "cd tmp/pact/bin && cmd.exe /c pact-mock-service.bat #{suffix}"
  else
    # Manually downloaded and extracted, for local testing
    "cd osx/pact/bin && ./pact-mock-service #{suffix}"
  end
end

def with_process process, clean_env = true
  if clean_env
    Bundler.with_clean_env do
      process.start
    end
  else
    process.start
  end
  yield
ensure
  process.stop if process && process.alive?
end

def test_mock_service
  require 'faraday'

  with_process(mock_service_process) do
    sleep 2
    make_http_request_to_mock_service 1235
  end
end

def test_mock_service_start_and_stop
  require 'faraday'

  Bundler.with_clean_env do
    echo_and_execute "pwd"
    echo_and_execute(mock_service_start_command(1237))
  puts "blah"
  end


  make_http_request_to_mock_service(1237)

  Bundler.with_clean_env do
    echo_and_execute(mock_service_stop_command(1237))
  end
end

def test_verifier
  require 'faraday'
  with_process(test_provider_process, false) do
    sleep 2

    Bundler.with_clean_env do
      output = echo_and_execute(pact_verifier_command)
      raise "pact-provider-verifier did not run as expected" unless output.include?("1 interaction, 0 failures")
    end
  end
end

def make_http_request_to_mock_service port
  require 'faraday'
  response = Faraday.get("http://localhost:#{port}", nil, {'X-Pact-Mock-Service' => 'true'})
  puts response.body
  raise "#{response.status} #{response.body}" unless response.status == 200
end

def echo_and_execute command
  puts command
  `#{command}`.tap{ | output | puts output}
end

desc 'Download latest pact-X.X.X-win32.zip'
task :download_latest_release do |t, args |
  begin
    require 'fileutils'
    FileUtils.rm_rf "tmp"
    FileUtils.mkdir_p "tmp"

    url = get_latest_release_asset_url /win.*zip/
    download_release_asset url, LOCAL_PACKAGE_LOCATION

  rescue StandardError => e
    # Appveyor doesn't display stderr in a helpful way, need to manually print error
    puts "#{e.class} #{e.message} #{e.backtrace.join("\n")}"
    raise e
  end
end

desc 'Unzip package'
task :unzip_package do
  unzip_package LOCAL_PACKAGE_LOCATION
end

desc 'Test windows batch file'
task :test_mock_service do
  begin
    puts "Testing pact-mock-service"
    test_mock_service
  rescue StandardError => e
    # Appveyor doesn't display stderr in a helpful way, need to manually print error
    puts "#{e.class} #{e.message} #{e.backtrace.join("\n")}"
    raise e
  end
end

desc 'Test windows batch file'
task :test_mock_service_start_and_stop do
  begin
    puts "Testing pact-mock-service start and stop"
    test_mock_service_start_and_stop
  rescue StandardError => e
    # Appveyor doesn't display stderr in a helpful way, need to manually print error
    puts "#{e.class} #{e.message} #{e.backtrace.join("\n")}"
    raise e
  end
end

desc 'Test windows pact verifier batch file'
task :test_verifier do
  begin
    puts "Testing pact-provider-verifier"
    test_verifier
  rescue StandardError => e
    # Appveyor doesn't display stderr in a helpful way, need to manually print error
    puts "#{e.class} #{e.message} #{e.backtrace.join("\n")}"
    raise e
  end
end

task :test => [:test_mock_service, :test_verifier] # :test_verifier disabled for now, don't have time to debug why it isn't working
task :default => [:download_latest_release, :unzip_package, :test]
