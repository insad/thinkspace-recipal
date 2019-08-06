require 'serializer_asm10/test_helper'

module Test; module Controller; class SerializerAsm10SpacesIndexTest < ActionController::TestCase
  include ::Thinkspace::Test::SerializerAsm10::All

  add_test(Proc.new do |route|
    describe 'read_1 space index' do
      let(:user)   {read_1}
      let(:record) {serializer_space}
      before do; @route = route; end
      it 'SerializerAsm10 space' do
        json = send_route_request
        # assert_space_assignment_ids(json, record, user_cases)
      end
    end
  end) # proc

  co = new_route_config_options(tests: get_tests, test_action: :index)
  co.only :common, :spaces, :index
  run_tests_serializer(co)

end; end; end
