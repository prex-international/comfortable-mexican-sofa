# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "simplecov"

# In CI envoronment I don't want to send coverage report for system tests that
# obviously don't cover everything 100%
unless ENV["SKIP_COV"]
  require "coveralls"
  Coveralls.wear!("rails")
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.command_name "Unit Tests"
  SimpleCov.start do
    add_filter "lib/tasks"
    add_filter "lib/generators"
    add_filter "lib/comfortable_mexican_sofa/engine.rb "
  end
end

SimpleCov.start "rails"

require_relative "../config/environment"

require "rails/test_help"
require "rails/generators"
require "minitest/unit"
require "mocha/setup"
require "minitest/reporters"

reporter_options = { color: true }
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]

Rails.backtrace_cleaner.remove_silencers!

class ActiveSupport::TestCase
  include ActionDispatch::TestProcess

  fixtures :all

  setup :reset_config,
        :reset_locale

  # resetting default configuration
  def reset_config
    ComfortableMexicanSofa.configure do |config|
      config.cms_title            = "ComfortableMexicanSofa CMS Engine"
      config.admin_auth           = "ComfortableMexicanSofa::AccessControl::AdminAuthentication"
      config.admin_authorization  = "ComfortableMexicanSofa::AccessControl::AdminAuthorization"
      config.public_auth          = "ComfortableMexicanSofa::AccessControl::PublicAuthentication"
      config.public_authorization = "ComfortableMexicanSofa::AccessControl::PublicAuthorization"
      config.admin_route_redirect = ""
      config.enable_seeds         = false
      config.seeds_path           = File.expand_path("db/cms_seeds", Rails.root)
      config.revisions_limit      = 25
      config.locales              = {
        "en" => "English",
        "es" => "Español"
      }
      config.admin_locale         = nil
      config.admin_cache_sweeper  = nil
      config.allow_erb            = false
      config.allowed_helpers      = nil
      config.allowed_partials     = nil
      config.allowed_templates    = nil
      config.hostname_aliases     = nil
      config.reveal_cms_partials  = false
      config.public_cms_path      = nil
      config.page_to_json_options = { methods: [:content], except: [:content_cache] }
    end
    ComfortableMexicanSofa::AccessControl::AdminAuthentication.username = "username"
    ComfortableMexicanSofa::AccessControl::AdminAuthentication.password = "password"
  end

  def reset_locale
    I18n.default_locale = :en
    I18n.locale         = :en
  end

  # Example usage:
  #   assert_has_errors_on @record, :field_1, :field_2
  def assert_has_errors_on(record, *fields)
    unmatched = record.errors.attribute_names - fields.flatten
    assert unmatched.blank?, "#{record.class} has errors on '#{unmatched.join(', ')}'"
    unmatched = fields.flatten - record.errors.attribute_names
    assert unmatched.blank?, "#{record.class} doesn't have errors on '#{unmatched.join(', ')}'"
  end


  def assert_no_select(selector, value = nil)
    assert_select(selector, text: value, count: 0)
  end

  # Capturing STDOUT into a string
  def with_captured_stout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end

end

class ActionDispatch::IntegrationTest

  # Attaching http_auth stuff with request. Example use:
  #   r :get, '/cms-admin/pages'
  def r(method, path, options = {})
    headers = options[:headers] || {}
    headers["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic.encode_credentials(
      ComfortableMexicanSofa::AccessControl::AdminAuthentication.username,
      ComfortableMexicanSofa::AccessControl::AdminAuthentication.password
    )
    options[:headers] = headers
    send(method, path, **options)
  end

  def with_routing
    yield ComfortableMexicanSofa::Application.routes
  ensure
    ComfortableMexicanSofa::Application.routes_reloader.reload!
  end

end

class ActionView::TestCase

  # When testing view helpers we don't actually have access to request. So
  # here's a fake one.
  class FakeRequest

    attr_accessor :host_with_port, :fullpath

    def initialize
      @host_with_port = "www.example.com"
      @fullpath       = "/"
    end

  end

  setup do
    @request = FakeRequest.new
  end

  def request
    @request ||= FakeRequest.new
  end

  # Expected and actual are wrapped in a root tag to ensure proper XML structure.
  def assert_xml_equal(expected, actual)
    expected_xml = Nokogiri::XML("<test-xml>\n#{expected}\n</test-xml>", &:noblanks)
    actual_xml   = Nokogiri::XML("<test-xml>\n#{actual}\n</test-xml>", &:noblanks)

    equivalent = EquivalentXml.equivalent?(expected_xml, actual_xml)
    assert equivalent, -> {
      # using a lambda because diffing is expensive
      Diffy::Diff.new(
        sort_attributes(expected_xml.root).to_xml(indent: 2),
        sort_attributes(actual_xml.root).to_xml(indent: 2)
      ).to_s
    }
  end

private

  def sort_attributes(doc)
    return if doc.blank?
    doc.dup.traverse do |node|
      if node.is_a?(Nokogiri::XML::Element)
        attributes = node.attribute_nodes.sort_by(&:name)
        attributes.each do |attribute|
          node.delete(attribute.name)
          node[attribute.name] = attribute.value
        end
      end
      node
    end
  end

end

class Rails::Generators::TestCase

  setup :prepare_destination,
        :prepare_files

  destination File.expand_path("../tmp", File.dirname(__FILE__))

  def prepare_files
    config_path = File.join(destination_root, "config")
    routes_path = File.join(config_path, "routes.rb")
    app_path    = File.join(config_path, "application.rb")
    FileUtils.mkdir_p(config_path)
    FileUtils.touch(routes_path)
    File.write(routes_path, <<~RUBY)
      Test::Application.routes.draw do
      end
    RUBY
    File.write(app_path, <<~RUBY)
      module TestApp
        class Application < Rails::Application
        end
      end
    RUBY
  end

  def read_file(filename)
    File.read(
      File.join(
        File.expand_path("fixtures/generators", File.dirname(__FILE__)),
        filename
      )
    )
  end

end

# In order to run system tests ensure that chrome-driver is installed.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase

  Capybara.enable_aria_label = true

  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  teardown :assert_no_javascript_errors

  # Visiting path and passing in BasicAuth credentials at the same time
  # I have no idea how to set headers here.
  def visit_p(path)
    username = ComfortableMexicanSofa::AccessControl::AdminAuthentication.username
    password = ComfortableMexicanSofa::AccessControl::AdminAuthentication.password
    visit("http://#{username}:#{password}@#{Capybara.server_host}:#{Capybara.server_port}#{path}")
  end

  def assert_no_javascript_errors
    assert_empty page.driver.browser.manage.logs.get(:browser)
      .select { |e| e.level == "SEVERE" && e.message.present? }.map(&:message).to_a
  end

end
