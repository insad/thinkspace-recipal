import ember from 'ember'
import ns from 'totem/ns'
import base_component from 'thinkspace-base/components/base'

export default base_component.extend
  # ### Properties
  tagName:           'li'
  classNameBindings: ['is_selected:is-selected']

  manager:    null
  reviewable: null
  review:     null

  # ### Computed properties
  is_selected: ember.computed 'model', 'reviewable', -> ember.isEqual @get('model'), @get('reviewable')
  is_balance:  ember.computed.reads 'manager.is_balance'

  points_expended: ember.computed 'review', 'manager.points_remaining', ->
    return unless @get('is_balance')
    review = @get 'review'
    review.get_expended_points()

  # ### Components
  c_user_avatar: ns.to_p 'user', 'avatar'

  # ### Events
  init: ->
    @_super()
    model  = @get 'model'
    review = @get('manager').get_review_for_reviewable(model)
    @set 'review', review
  
  click: -> 
    manager = @get 'manager'
    manager.set_reviewable @get('model')
