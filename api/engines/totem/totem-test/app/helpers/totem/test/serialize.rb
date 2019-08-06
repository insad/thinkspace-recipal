module Totem::Test::Serialize
extend ActiveSupport::Concern
included do

  def get_serializer_options
    ::Totem::Settings.class.totem.serializer_options.new
  end

  def get_serializer_scope(serializer_options, username)
    scope                    = ActiveSupport::OrderedOptions.new
    scope.current_ability    = get_ability(username)
    scope.current_user       = get_user(username)
    scope.serializer_options = serializer_options
    scope
  end

  def serialize_records(records, scope)
    record     = records.respond_to?(:to_a) ? records.to_a.first : records
    serializer = record.active_model_serializer
    serializer.totem_serialize_as_json(records, scope: scope)
  end

  # Debug options:
  #   debug:         [true|FALSE]  # debug all
  #   debug_hash:    [true|FALSE]  # print the result serialized hash
  #   debug_options: [true|FALSE]  # print serializer run option values e.g. include_association, etc.
  #   debug_run:     [true|FALSE]  # print serializer log as they happen during the run (use if get errors during serialization)
  #   debug_log:     [true|FALSE]  # print serializer log after serialization completed (assumes serialization was successful)
  def serialize_as_json(records, username, serializer_options, options={})
    debug         = options[:debug]         || false
    debug_run     = options[:debug_run]     || false
    debug_log     = options[:debug_log]     || false
    debug_hash    = options[:debug_hash]    || false
    debug_options = options[:debug_options] || false
    debug_on      = debug || debug_run || debug_log
    scope         = get_scope(serializer_options, username)
    puts "\n***** Debug Test: #{method_name.inspect} *****\n\n"  if debug_on || debug_hash
    serializer_options.debug_on             if debug_on
    serializer_options.debug_run_on         if debug || debug_run
    serializer_options.print_debug_options  if debug || debug_options
    puts '--Debug Run:-- ("class" [record-id] :action :association-name)'   if debug || debug_run
    hash = serialize_records(records, scope)
    puts "--Serialized Hash:--"           if debug || debug_hash
    pp hash                               if debug || debug_hash
    puts "\n--Debug Log:-- (sorted by: \"class\" [record-id] :action :association-name [count-of-times-called-via-association])"   if debug || debug_log
    serializer_options.print_debug_log_sorted(unique: true)  if debug || debug_log
    hash
  end

  def serializer_attributes(object)
    serializer_class  = object.kind_of?(Class) ? object.name : object.class.name
    serializer_class += 'Serializer'
    klass = serializer_class.safe_constantize
    klass._attributes.keys
  end

  # ### Create a module based on the path.
  def serializer_path_to_module(path)
    path_mod_name = path.camelize
    path_mod      = path_mod_name.safe_constantize
    return path_mod  if path_mod.present? && path_mod.kind_of?(Module)
    raise "Path #{path.inspect} constant already exists as a #{path_mod.name} and is not a module."  if path_mod.present?
    parent_mod_name = path_mod_name.deconstantize
    parent_mod      = parent_mod_name.safe_constantize
    path_to_module(parent_mod_name.underscore)  if parent_mod.blank?  # recursive call for nesting modules
    parent_mod = parent_mod_name.safe_constantize
    raise "Path #{path.inspect} parent #{parent_mod.inspect} does not exist.  Is it defined?"  if parent_mod.blank?
    mod_name = path_mod_name.demodulize
    mod      = parent_mod.const_set(mod_name, Module.new)
    raise "Could not create module #{mod_name.inspect} in module #{parent_mod.inspect}."  if mod.blank?
    mod
  end

  # ### Serializer options module that just returns for the action.
  def create_serializer_options_module(action)
    raise "Action must be passed to create a serializer options module." if action.blank?
    namespace_name = @controller.class.name.split('::')[0..1].join('::')
    so_name        = @controller.class.name.demodulize.sub('Controller','')
    path           = "#{namespace_name}::Concerns::SerializerOptions::#{so_name}".underscore
    mod            = serializer_path_to_module(path)
    mod.send :define_method, action.to_sym do
      return
    end
  end

end; end
