require 'sandbox/test_helper'

module Test; module Controller; class SandboxAssignmentsSelectTest < ActionController::TestCase
  include ::Thinkspace::Test::Sandbox::All

  add_test(Proc.new do |route|
    describe 'is sandbox' do
      let(:user)   {read_1}
      let(:record) {sandbox_assignment}
      before do; @route = route; end
      it 'master-sandbox space id replaced by read_1-sandbox space id' do
        json = send_route_request
        assert_assignments_space_id(json, read_1_space, record)
      end
    end
  end) # proc

  add_test(Proc.new do |route|
    describe 'NOT sandbox' do
      let(:user)       {read_1}
      let(:space)      {create_not_sandbox_space}
      let(:assignment) {create_not_sandbox_assignment(space)}
      let(:record)     {assignment}
      before do; @route = route; end
      it 'space id not changed' do
        json = send_route_request
        assert_assignments_space_id(json, space, assignment)
      end
    end
  end) # proc

  add_test(Proc.new do |route|
    describe 'is sandbox' do
      let(:user)   {read_2}
      let(:record) {sandbox_assignment}
      before do; @route = route; end
      it 'master-sandbox space id replaced by read_2-sandbox space id' do
        json = send_route_request
        assert_assignments_space_id(json, read_2_space, record)
      end
    end
  end) # proc

  add_test(Proc.new do |route|
    describe 'sandbox and NOT sandbox' do
      let(:user)        {read_1}
      let(:record)      {sandbox_assignment}
      let(:assignment)  {create_not_sandbox_assignment(space)}
      let(:space)       {read_1_space}
      let(:proc_params) {Hash(ids: [record.id, assignment.id])}
      before do; @route = route; end
      it 'master-sandbox space id replaced by read_1-sandbox space id and NOT sandbox space id unchanged' do
        json = send_route_request
        # assert_assignments_space_id(json, [sandbox_space, space], [record, assignment])
        assert_assignments_space_id(json, space, assignment)
      end
    end
  end) # proc

  co = new_route_config_options(tests: get_tests, test_action: :select)
  co.only :casespace, :assignments, :select

  run_tests_sandbox_controller(co)

end; end; end
