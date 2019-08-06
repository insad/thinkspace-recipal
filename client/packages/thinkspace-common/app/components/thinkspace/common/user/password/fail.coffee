import ember from 'ember'
import ns         from 'totem/ns'
import base_component from 'thinkspace-base/components/base'

export default base_component.extend
  layoutName: 'thinkspace/common/user/password/fail'

  message: 'There was a problem with resetting your password.'
  contact_us: 'Please request another email or contact support@thinkspace.org if the problem persists.'
  display_message: ember.computed 'message', -> "#{@get('message')} #{@get('contact_us')}"

  c_checkbox:        ns.to_p 'common', 'shared', 'checkbox'
  c_validated_input: ns.to_p 'common', 'shared', 'validated_input'
  c_loader:          ns.to_p 'common', 'shared', 'loader'
