require 'phase_actions/test_helper'

module Test; module PhaseActions; class LockTest < ActionController::TestCase
  include ::Thinkspace::Test::PhaseActions::All

  describe 'unlock' do
    let (:current_user)    {get_user(:read_1)}
    let (:ownerable)       {current_user}
    let (:current_phase)   {get_phase(:phase_actions_phase_B)}
    let (:debug)           {false}

      it 'next' do
        set_submit_settings(state: :complete, lock: :next)
        process_action
        assert_phase_state(:completed)
        assert_next_phase_state(:locked)
      end

      it 'next_all' do
        set_submit_settings(state: :complete, lock: :next_all)
        process_action
        assert_phase_state(:completed)
        next_phases.each {|phase| assert_phase_state(:locked, phase)}
      end

      it 'previous_all' do
        set_submit_settings(state: :complete, lock: :previous_all)
        process_action
        assert_phase_state(:completed)
        prev_phases.each {|phase| assert_phase_state(:locked, phase)}
      end

      it 'previous' do
        set_submit_settings(state: :complete, lock: :previous)
        process_action
        assert_phase_state(:completed)
        assert_prev_phase_state(:locked)
      end

      describe 'next on last phase' do
        let (:current_phase)   {get_phase(:phase_actions_phase_D)}
        it 'next' do
          set_submit_settings(state: :complete, lock: :next)
          process_action
          assert_phase_state(:completed)
        end
      end

      describe 'previous on first phase' do
        let (:current_phase)   {get_phase(:phase_actions_phase_A)}
        it 'next' do
          set_submit_settings(state: :complete, lock: :previous)
          process_action
          assert_phase_state(:completed)
        end
      end

  end

end; end; end
