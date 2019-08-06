import ember from 'ember'
import ns    from 'totem/ns'
import base_component from 'thinkspace-base/components/base'

## ### Configuration:
#
# modal content:
#   modal_partial: string of partial to render in place of the modal content
#   title                            string of text for the h4 element
#   subtitle                         string of text for the h5 element
#   description                      string of text for the p element
#   confirm_text:                    string of text for the confirm button
#   deny_text:                       string of text for the deny button
#   modal_class_names:               string of class names for the modal, separated by spaces
# modal reveal:                      
#   modal_reveal_anchor_class_names: string of class names for the anchor for the modal reveal, separated by spaces
#   modal_reveal_icon_class_names:   string of class names for the icon for the modal reveal, separated by spaces
#   modal_reveal_partial:            string of partial to render in place of the modal reveal icon
# modal actions:                     
#   confirm:                         action to send confirmation to
#   deny:                            action to send denial to
#
## ###


export default base_component.extend
  tagName: ''
  modal_id: ember.computed -> "ts-confirmation-modal-#{@get('elementId')}"

  title:        'Are you sure?'
  confirm_text: 'Yes'
  deny_text:    'Cancel'

  modal_class_names:         ''
  default_modal_class_names: 'ts-confirmation-modal reveal-modal'
  all_modal_class_names:     ember.computed 'modal_class_names', -> 
    class_names = @get('default_modal_class_names')
    unless ember.isEmpty @get('modal_class_names')
      class_names = class_names + ' ' + @get('modal_class_names')
    class_names

  get_$modal: -> $("##{@get('modal_id')}")

  didInsertElement: ->
    $(document).foundation 'reveal'

  actions:

    confirm: ->
      @send 'close'
      @sendAction 'confirm'

    deny: ->
      @send 'close'
      @sendAction 'deny'

    close: ->
      @get_$modal().foundation 'reveal', 'close'
