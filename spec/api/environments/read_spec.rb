# Copyright: Copyright (c) 2012 Opscode, Inc.
# License: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'pedant/rspec/auth_headers_util'
require 'pedant/rspec/environment_util'
require 'pedant/rspec/search_util'
require 'pedant/rspec/role_util'

describe "Environments API Endpoint", :environments do
  include Pedant::RSpec::EnvironmentUtil
  include Pedant::RSpec::SearchUtil
  include Pedant::RSpec::AuthHeadersUtil

  # include roles for testing w/ environments roles method
  include Pedant::RSpec::RoleUtil

  def self.ruby?
    Pedant::Config.ruby_environment_endpoint?
  end

  # Deal with subtly different error messages/codes in one place

  let(:new_environment_name) { 'pedant_testing_environment' }
  let(:non_existent_environment_name) { 'pedant_dummy_environment' }

  let(:requestor) { admin_user }

  context 'GET' do
    let(:request_method) { :GET }

    context 'with no additional environments' do
      context 'GET /environments' do
        let(:request_url) { api_url "/environments" }
        let(:expected_response) { ok_exact_response }
        let(:success_message) { { "_default" => api_url("/environments/_default") } }

        should_respond_with 200
      end

      context 'GET /environments/_default' do
        let(:request_url) { api_url '/environments/_default' }
        let(:expected_response) { ok_exact_response }
        let(:success_message) do
          {
            "name" => "_default",
            "description" => "The default Chef environment",
            "cookbook_versions" => {},
            "json_class" => "Chef::Environment",
            "chef_type" => "environment",
            "default_attributes" => {},
            "override_attributes" => {}
          }
        end

        should_respond_with 200, 'and the default environment'
      end

      it 'should respond to cookbook versions'


      context 'with a non-existant environment' do
        let(:request_url) { api_url "/environments/#{non_existent_environment_name}" }
        let(:expected_response) { resource_not_found_exact_response }
        let(:not_found_error_message) { cannot_load_nonexistent_env_msg }

        should_respond_with 404
      end # with non-existant environment
    end # with no additional environments

    context 'with non-default environments' do
      before(:each) { add_environment(admin_user, full_environment(new_environment_name)) }
      after(:each)  { delete_environment(admin_user, new_environment_name) }

      context 'GET /environments' do
        let(:request_url) { api_url "/environments" }
        let(:expected_response) { ok_exact_response }
        let(:success_message) do
          {
            "_default"           => api_url("/environments/_default"),
            new_environment_name => api_url("/environments/#{new_environment_name}")
          }
        end

        should_respond_with 200, 'and an index of all the available environments'
      end # GET /environments

      pending 'GET /environments open-source permissions', :platform => :open_source

      context 'GET /environments/:environment' do
        let(:request_url) { api_url "/environments/#{new_environment_name}" }
        let(:expected_response) { ok_exact_response }
        let(:success_message) { full_environment(new_environment_name) }

        should_respond_with 200, 'and the environment'
      end # GET /environment/:environments

      context 'GET /environments/<name>' do
        let(:request_method) { :GET }
        let(:request_url)    { api_url "/environments/#{environment_name}" }

        let(:environment_name) { new_environment_name }

        context 'when handling authentication headers' do
          # Unconverted Auth Header DSL
          let(:method) { request_method }
          let(:url)    { request_url }
          let(:body)   { nil }

          let(:response_should_be_successful) do
            response.
              should look_like({
              :status => 200,
              :body_exact => full_environment(new_environment_name)
            })
          end
          let(:success_user) { admin_user }
          let(:failure_user) { outside_user }

          include_context 'handles authentication headers correctly'
        end

        context 'when the environment does not exist' do
          let(:environment_name) { 'doesnotexistatall' }
          let(:expected_response) { resource_not_found_response }
          should_respond_with 404
        end
      end

      context 'search' do
        before(:each) do
          # Create the environment
          @response = post(api_url("/environments"),
                           admin_user,
                           :payload => full_environment(new_environment_name))
        end

        def search_returns_environment(query)
          search_should_return(
            :type => "environment",
            :query => query,
            :results => [full_environment(new_environment_name)])
        end

        # FIXME: two pending tests below actually work, but the
        # queries also return the _default environment. This is
        # correct behavior, so we need to use a different result
        # matcher.
        it 'can be searched for by name' do
          search_returns_environment("name:#{new_environment_name}")
        end
        it 'can be searched for by description' do
          search_returns_environment("description:Behold*")
        end
        it 'can be searched for by JSON class', :pending => true do
          search_returns_environment("json_class:Chef*")
        end
        it 'can be searched for by cookbook versions' do
          search_returns_environment("cookbook_versions:ultimatecookbook")
        end
        it 'can be searched for by chef type', :pending => true do
          search_returns_environment("chef_type:environment")
        end
        it 'can be searched for by default attribute' do
          search_returns_environment("default_attributes:defaultattr")
        end
        it 'can be searched for by override attribute' do
          search_returns_environment("override_attributes:overrideattr")
        end
      end
    end # with non-default environments

  end # GET
end # Environments API endpoint