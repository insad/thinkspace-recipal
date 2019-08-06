require 'serializer_asm10/test_helper'

module Test; module Controller; class SerializerAsm10SpacesShowTest < ActionController::TestCase
  include ::Thinkspace::Test::SerializerAsm10::All

  add_test(Proc.new do |route|
    describe 'read_1 space show' do
      let(:user)   {read_1}
      let(:record) {serializer_space}
      before do; @route = route; end
      it 'SerializerAsm10 space' do
        add_space_owner
        json = send_route_request
        # assert_space_assignment_ids(json, record, user_cases)
      end
    end
  end) # proc

  co = new_route_config_options(tests: get_tests, test_action: :show)
  co.only :common, :spaces, :show
  run_tests_serializer(co)

end; end; end
