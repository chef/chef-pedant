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

require 'pedant/rspec/cookbook_util'

# FIXME  We don't test GET /cookbooks/NAME/VERSION when we have
# any files in the segments.  Thus we're not checking the creation
# of the S3 URLs that should be returned for all the files in the
# cookbook

describe "Cookbooks API endpoint", :cookbooks do
  include Pedant::RSpec::CookbookUtil

  def self.ruby?
    Pedant::Config.ruby_cookbook_endpoint?
  end

  context "GET /cookbooks" do
    let(:url) { cookbook_collection_url }
    let(:request_url) { cookbook_collection_url }
    let(:request_method) { :GET }
    let(:requestor) { admin_user }

    let(:cookbook_collection_url) { api_url("/cookbooks") }
    let(:fetch_cookbook_collection_success_exact_response) do
      {
        :status => 200,
        :body_exact => fetched_cookbooks
      }
    end

    context "without existing cookbooks" do
      let(:expected_response) { fetch_cookbook_collection_success_exact_response }

      # Assert that there are no cookbooks
      let(:fetched_cookbooks) { { } }

      # NOTE:  This test must the first one dealing with cookbooks
      # so that there are no cookbooks existing on the server

      should_respond_with 200, "and an empty collection"

      # Add test to check for empty case with different num_versions
      context 'with a num_versions' do
        let(:expected_response) { bad_request_response }
        let(:request_url) { api_url("/cookbooks?num_versions=#{num_versions}") }
        let(:error_message) { invalid_versions_msg }

        def self.expects_response_of_400_with(message, _value)
          context "with #{message}" do
            let(:num_versions) { _value }
            should_respond_with 400
          end
        end

        expects_response_of_400_with "a negative num_versions", '-1'
        expects_response_of_400_with "a missing num_versions", ''
        expects_response_of_400_with "an invalid num_versions", 'foo'

      end # when requesting with num_versions
    end # without existing cookbooks

    context "with existing cookbooks and multiple versions" do
      let(:expected_response) { fetch_cookbook_success_exact_response }
      let(:request_url) { api_url("/cookbooks?num_versions=#{num_versions}") }

      let(:fetched_cookbook) { cookbook_collection }

      let(:cookbook_name) { "cookbook_name" }
      let(:cookbook_name2) { "cookbook_name2" }
      let(:version1) { "0.0.1" }
      let(:version2) { "0.0.2" }
      let(:cookbooks) do
        {
          cookbook_name => {
            version1 => [],
            version2 => []
          },

          cookbook_name2 => {
            version1 => []
          }
        }
      end

      before(:all) do
        setup_cookbooks(cookbooks)
      end

      after(:all) do
        remove_cookbooks(cookbooks)
      end

      context 'with num_versions set to 0' do
        let(:num_versions) { 0 }
        let(:cookbook_collection) do
          {
            cookbook_name  => { "url" => cookbook_url(cookbook_name) },
            cookbook_name2 => { "url" => cookbook_url(cookbook_name2) }
          }
        end

        it "should respond with cookbook collection with no version" do
          should look_like expected_response
        end
      end # with num_versions set to 0
      let(:cookbook_collection_with_one_version) do
        {
          cookbook_name => {
            "url" => cookbook_url(cookbook_name),
            "versions" =>
              [{ "version" => version2,
                 "url" => cookbook_version_url(cookbook_name,version2) }]},
          cookbook_name2 => {
            "url" => cookbook_url(cookbook_name2),
            "versions" =>
               [{ "version" => version1,
                  "url" => cookbook_version_url(cookbook_name2, version1) }]}
        }
      end

      context 'when num_versions is not set' do
        let(:request_url) { cookbook_collection_url }
        let(:cookbook_collection) { cookbook_collection_with_one_version }

        it 'should return cookbook collection with one version per cookbook' do
          should look_like expected_response
        end
      end # without num_versions

      context 'when num_versions is set to 1' do
        let(:num_versions) { 1 }
        let(:cookbook_collection) { cookbook_collection_with_one_version }

        it 'should return cookbook collection with one version per cookbook' do
          should look_like expected_response
        end
      end

      context 'when num_versions is set to "all"' do
        let(:num_versions) { 'all' }
        let(:cookbook_collection) do
          {
            cookbook_name => {
              "url" => cookbook_url(cookbook_name),
              "versions" => [
                { "version" => version2,
                  "url" => cookbook_version_url(cookbook_name, version2) },
                { "version" => version1,
                  "url" => cookbook_version_url(cookbook_name, version1) } ]},
            cookbook_name2 => {
              "url" => cookbook_url(cookbook_name2),
              "versions" => [
                { "version" => version1,
                  "url" => cookbook_version_url(cookbook_name2, version1) }]}
          }
        end

        it 'should respond with a cookbook collection containing all versions of each cookbook' do
          should look_like expected_response
        end

      end
    end # context returns different results depending on num_versions

    context "with varying numbers of existing cookbooks" do
      let(:expected_response) { fetch_cookbook_success_exact_response }
      let(:request_url) { api_url("/cookbooks?num_versions=all") }

      let(:fetched_cookbook) { cookbook_collection }
      let(:cookbook_name) { "cookbook_name" }
      let(:cookbook_version) { "1.2.3" }

      context 'with a single, existing cookbook' do
        let(:cookbook_collection) do
          {
            cookbook_name => {
            "url" => cookbook_url(cookbook_name),
            "versions" => [
              { "version" => cookbook_version,
                "url" => cookbook_version_url(cookbook_name, cookbook_version) }]}
          }
        end

        it 'should respond with a single cookbook in the collection' do
          make_cookbook(admin_user, cookbook_name, cookbook_version)
          should look_like expected_response
          delete_cookbook(admin_user, cookbook_name, cookbook_version)
        end
      end

      context 'with multiple, existing cookbooks' do
        let(:cookbook_collection) do
          {
            "cb1" => {
              "url" => cookbook_url("cb1"),
              "versions" => [
                { "version" => "0.0.1",
                  "url" => cookbook_version_url("cb1", "0.0.1") }]},
            "cb2" => {
              "url" => cookbook_url("cb2"),
              "versions" => [
                { "version" => "0.0.2",
                  "url" => cookbook_version_url("cb2", "0.0.2") }]}
          }
        end

        it "multiple cookbooks can be listed" do
          # Upload cookbook
          make_cookbook(admin_user, "cb1", "0.0.1")
          make_cookbook(admin_user, "cb2", "0.0.2")

          should look_like expected_response

          # cleanup
          delete_cookbook(admin_user, "cb1", "0.0.1")
          delete_cookbook(admin_user, "cb2", "0.0.2")
        end # it multiple cookbooks can be listed
      end # with multiple, existing cookbooks

    end # with varying numbers of existing cookbooks
  end # context GET /cookbooks

  context "GET /cookbooks/<name>/<version>" do
    let(:request_method) { :GET }
    let(:request_url)    { named_cookbook_url }

    let(:cookbook_name) { "the_cookbook_name" }
    let(:cookbook_version) { "1.2.3" }
    let(:recipe_name) { "test_recipe" }
    let(:recipe_content) { Pedant::Utility.with_unique_suffix("hello") }
    let(:recipe_spec) do
        {
          :name => recipe_name,
          :content => recipe_content
        }
    end

    let(:cookbooks) do
      {
        cookbook_name => {
          cookbook_version => [recipe_spec]
        }
      }
    end

    before(:each) { setup_cookbooks(cookbooks) }
    after(:each)  { remove_cookbooks(cookbooks) }

    let(:fetched_cookbook) do
      # NOTE: the cookbook returned will actually have some recipe
      # data. We aren't checking for that here, because we don't have
      # a nice way to do the required soft verification for the URL
      # and checksum.
      minimal_cookbook(cookbook_name, cookbook_version)
    end

    context 'as a normal user' do
      let(:expected_response) { fetch_cookbook_success_exact_response }
      let(:requestor) { normal_user }

      should_respond_with 200

      context "allows access to cookbook recipe files via" do
        # These tests verify that the pre-signed URL that comes back
        # within cookbook_version responses is usable. Validating both
        # the URL generation, but also the use of bookshelf via the
        # load balancer.
        let(:cbv) { parse(response) }
        let(:recipe_url) { cbv["recipes"].first["url"] }

        it "net/http" do
          uri = URI.parse(recipe_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE

          # Need to add headers if on Ruby, since Erlang uses pre-signed URLs
          headers = if ruby?
                      requestor.signing_headers(:get, uri.request_uri, "")
                    else
                      {}
                    end

          response = http.get(uri.request_uri, headers)
          response.body.should == recipe_content
        end

        it "curl" do
          # Need to add headers if on Ruby, since Erlang uses pre-signed URLs
          header_string = if ruby?
                            signing_headers = requestor.signing_headers(:get,recipe_url, "")
                            header_strings = signing_headers.inject([]) do |acc, pair|
              name, value = pair
              acc << "#{name}: #{value}"
            end
                            header_strings.map{|h| "--header '#{h}'" }.join(" ")
                          else
                            ""
                          end
          got = `curl -sk #{header_string} '#{recipe_url}'`
          got.should == recipe_content
        end
      end # access to recipe file content

    end # as a normal user

    context 'as an admin user' do
      let(:expected_response) { fetch_cookbook_success_exact_response }
      let(:requestor) { admin_user }

      should_respond_with 200
    end # as an admin user

    context 'as an user outside of the organization' do
      let(:expected_response) { unauthorized_access_credential_response }
      let(:requestor) { outside_user }

      should_respond_with 403
    end # as an outside user

    context 'with invalid user' do
      let(:expected_response) { invalid_credential_exact_response }
      let(:requestor) { invalid_user }

      should_respond_with 401
    end
  end # context GET /cookbooks/<name>/<version>
end # describe Cookbooks API endpoint