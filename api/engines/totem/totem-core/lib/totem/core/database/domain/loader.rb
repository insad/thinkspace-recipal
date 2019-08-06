module Totem; module Core; module Database; module Domain; class Loader

  attr_reader :totem_settings
  attr_reader :last_sequence_number
  attr_reader :run_messages

  def initialize(env=nil)
    @totem_settings    = env || ::Totem::Settings
    @ignore_timestamps = true
    @run_messages      = Array.new
  end

  # ###
  # ### Public Methods.
  # ###

  def create_files(args=nil)
    engines = get_args_engines_and_models(args)
    engines.each do |engine, models|
      create_engine_domain_directory(engine)
      models.each do |model|
        create_engine_domain_yml_file(engine, model)
      end
    end
    print_run_messages
  end

  def compare_files(args=nil)
    engines = get_args_engines_and_models(args)
    engines.each do |engine, models|
      models.each do |model|
        compare_model_domain_records(engine, model)
      end
    end
    print_run_messages
  end

  def load_files(args=nil)
    ActiveRecord::Base.transaction do
      engines = get_args_engines_and_models(args)
      engines.each do |engine, models|
        models.each do |model|
          load_model_domain_records(engine, model)
        end
      end
    end
    print_run_messages
  end

  def load_from_yml(*args)
    engine, model, data = validate_load_from_yml(args)
    ActiveRecord::Base.transaction do
      delete_all_model_records(model)
      load_model_domain_records(engine, model, data)
      create_engine_domain_directory(engine)
      create_engine_domain_yml_file(engine, model)
    end
    print_run_messages
  end

  # ###
  # ### Private Methods.
  # ###

  private

  def get_data_ids(data); data.select {|d| d[:id].present?}.map{|d| d[:id]}; end

  def create_model_yml_file_after_load?
    @archive_data && (@records_created > 0 || @records_updated > 0 || @records_destroyed > 0 || @records_recreated > 0)
  end

  def load_model_domain_records(engine, model, data=nil)
    @last_sequence_number = get_table_last_sequence_number(model)
    reset_counts
    @archive_data = model.count > 0  # if the table is empty, don't archive the data just load it e.g. after a totem:db:reset
    data = get_model_yml_data(engine, model)  if data.blank?
    validate_data(model, data)
    new_records     = Array.new
    data.each do |data_record|
      id = data_record[:id]
      if id.present?
        record = model.find_by(id: id)
        if record.present?
          update_record(record, data_record)
        else
          recreate_record(model, data_record, id)  # recreating a destroyed record or setting a specific id
        end
      else
        new_records.push(data_record)  # save data to create the new record
      end
    end
    # By now, all of the records with ids have been created.
    data_ids    = get_data_ids(data)
    db_ids      = get_domain_table_record_ids(model)
    destroy_ids = db_ids - data_ids
    destroy_ids.each do |id|
      destroy_record(model, id)
    end
    new_records.each do |data_record|
      create_record(model, data_record)
    end
    create_engine_domain_yml_file(engine, model)  if create_model_yml_file_after_load?
    print_model_results(model)
  end

  def validate_data(model, data)
    data_ids = get_data_ids(data)
    uniq_ids = data_ids.uniq
    unless data_ids.length == uniq_ids.length
      dup_ids = Array.new
      uniq_ids.each {|id| dup_ids.push(id)  if data_ids.count(id) > 1}
      raise_error "Model #{model.name.inspect} has duplicate yml data file ids #{dup_ids}."
    end
  end

  def update_record(record, data_record)
    return if same_record_attributes?(record, data_record)
    attributes = data_record.except(timestamps_columns + ['id'])
    rc         = record.update(attributes)
    check_validation_errors(record)
    raise_error "Error updating record #{record.inspect}."  if rc.blank?
    @records_updated += 1
  end

  def recreate_record(model, data_record, id)
    set_table_sequence_number_for_create(model)
    record = model.create(data_record)
    check_validation_errors(record)
    record.update_columns(id: id)
    @records_recreated += 1
    # When re-creating a record that was previouly destroyed, reset the sequence number back to the
    # original value e.g. reset the sequence increment generated by this 'create' for the recreated record.
    # Also ensure the 'next' sequence number is correct if only recreating records.
    if id >= last_sequence_number
      next_seq_num = get_available_table_sequence_number(model, last_sequence_number)
      set_domain_table_sequence_number(model, next_seq_num)
    end
    record
  end

  def destroy_record(model, id)
    record = model.find_by(id: id)
    raise_error "Destroy record id #{id} not found for class #{model.name.inspect}."  if record.blank?
    rc = record.destroy
    check_validation_errors(record)
    raise_error "Error destroying record #{record.inspect}."  if rc.blank?
    @records_destroyed += 1
  end

  def create_record(model, data_record)
    set_table_sequence_number_for_create(model)
    record = model.create(data_record)
    check_validation_errors(record)
    @records_created += 1
    record
  end

  def check_validation_errors(record)
    raise_error "Record is blank."  if record.blank?
    if record.errors.present?
      raise_error "Could not save record #{record.class.name}.#{record.id}.  Validation errors: #{record.errors.messages}."
    end
  end

  def same_record_attributes?(record, data_record, *except)
    @records_verified += 1
    except            += timestamps_columns  if ignore_timestamps?
    except_attributes  = [except].flatten.compact.uniq.map {|a| a.to_s}
    data_record.except(*except_attributes) == record.attributes.except(*except_attributes)
  end

  # ###
  # ### Load from Yml.
  # ###

  def validate_load_from_yml(args)
    args = args.flatten
    stop_run "load_from_yml arguments must be engine_name, model_path, yml-string not #{args.inspect}"  unless args.length == 3
    engine_name, model_path, content = args
    stop_run "YAML argument is not a string but #{content.class.name.inspect}."  unless content.is_a?(String)
    engine = totem_engine_by_name(engine_name)
    model  = get_model_class(model_path)
    stop_run "Model path #{model_path.inspect} could not be constantized."  if model.blank?
    stop_run "Domain model #{model_path.inspect} is not a model for engine #{engine.engine_name.inspect}." unless is_engine_model?(engine, model_path)
    data = YAML.load(content)
    stop_run "Yml argument is not an array of domain records but #{data.class.name.inspect}."  unless data.is_a?(Array)
    format_data_records(data)
    [engine, model, data]
  end

  # ###
  # ### Compare files and db.
  # ###

  def compare_model_domain_records(engine, model)
    reset_counts
    if @compare_model_count.blank?
      @compare_model_count = 1
      print_message "\n"
      header  = "Comparing database record attributes and domain_data yml file attributes "
      header += ignore_timestamps? ? "(ignoring timestamps #{timestamps_columns}):" : "(including timestampes #{timestamps_columns}):"
      print_message header
      print_message "\n"
    else
      @compare_model_count += 1
    end
    begin
      data = get_model_yml_data(engine, model)
    rescue DomainFileNotFound
      model_name = domain_model_filename(model).sub('.yml', '')
      run_messages.push "WARNING: #{model.name.inspect} domain_data file does not exist.  Run: rake totem:db:domain:create[#{engine.engine_name},#{model_name}]"
      return
    end
    validate_data(model, data)
    data.each do |data_record|
      id = data_record[:id]
      if id.present?
        record = model.find_by(id: id)
        if record.present?
          if same_record_attributes?(record, data_record)
            @records_verified_attributes.push(data_record)
          else
            @records_updated += 1
            @records_updated_attributes.push(data_record)
          end
        else
          @records_recreated += 1
          @records_recreated_attributes.push(data_record)
        end
      else
        @records_created += 1
        @records_created_attributes.push(data_record)
      end
    end
    data_ids    = get_data_ids(data)
    db_ids      = get_domain_table_record_ids(model)
    destroy_ids = db_ids - data_ids
    destroy_ids.each do |id|
      @records_destroyed += 1
      @records_destroyed_attributes.push(record.attributes)
    end
    print_model_results(model)
  end

  # ###
  # ### Model Sequence Number.
  # ###

  def get_available_table_sequence_number(model, seq_num)
    record = model.find_by(id: seq_num)
    return seq_num if record.blank?  # can create a record at this sequence number
    seq_num += 1
    get_available_table_sequence_number(model, seq_num)
  end

  def set_table_sequence_number_for_create(model)
    seq_num = get_available_table_sequence_number(model, last_sequence_number)
    set_domain_table_sequence_number(model, seq_num)
  end

  # The sequence 'last_value' is the next row id for a record create.
  def get_table_last_sequence_number(model)
    seq_name = model.sequence_name
    raise_error "Model sequence name is blank for #{model.name.inspect}."  if seq_name.blank?
    res = ActiveRecord::Base.connection.execute("SELECT last_value FROM #{seq_name}")
    raise_error "Model sequence select response is blank for #{model.name.inspect}."  if res.blank?
    result = res[0]
    raise_error "Model sequence select response if invalid for #{model.name.inspect}."  if result.blank?
    last_value = result['last_value']
    raise_error "Model sequence select response 'last_value' is blank for #{model.name.inspect}."  if last_value.blank?
    last_value.to_i
  end

  # Reset the sequence number after recreating a destroyed record.
  def set_domain_table_sequence_number(model, seq_num)
    raise_error "Reset sequence number is blank for #{model.name.inspect}."  if seq_num.blank?
    raise_error "Reset sequence number is not a number for #{model.name.inspect}."  unless seq_num.is_a?(Fixnum)
    seq_name = model.sequence_name
    raise_error "Reset sequence name is blank for #{model.name.inspect}."  if seq_name.blank?
    ActiveRecord::Base.connection.execute("ALTER SEQUENCE #{seq_name} RESTART WITH #{seq_num}") # reset id sequence number
    @last_sequence_number = seq_num
  end

  # If something bad happens and the table is out of sync, can start over by running this truncate.
  # All yml data records should have an id, otherwise new records may be a different id.
  def delete_all_model_records(klass)
    klass.delete_all
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{klass.table_name} RESTART IDENTITY") # restart ids at 1
  end

  # ###
  # ### Engine Paths/Filenames.
  # ###

  def domain_model_filename(model); "#{model.name.demodulize.underscore.pluralize}.yml"; end  # e.g. user.yml
  # def domain_model_filename(model); "#{model.table_name}.yml"; end  # e.g. thinkspace_common_user.yml

  def domain_directory;         'domain_data'; end
  def domain_archive_directory; 'archive'; end

  def engine_db_path(engine);                       File.join(engine.root, 'db'); end
  def engine_domain_path(engine);                   File.join(engine_db_path(engine), domain_directory); end
  def engine_domain_archive_path(engine);           File.join(engine_domain_path(engine), domain_archive_directory); end
  def engine_domain_model_file_path(engine, model); File.join(engine_domain_path(engine), domain_model_filename(model)); end

  def engine_has_domain_path?(engine); File.directory? engine_domain_path(engine); end

  # ###
  # ### Read/Write Model YAML Data.
  # ###

  def create_engine_domain_yml_file(engine, model)
    data       = get_domain_table_record_scope(model).map {|record| record.attributes}
    file_path  = engine_domain_model_file_path(engine, model)
    domain_dir = engine_domain_path(engine)
    filename   = domain_model_filename(model)
    if File.file?(file_path)
      archive_engine_domain_yml_file(engine, model)
    end
    Dir.chdir(domain_dir) do
      if data.present?
        File.open(filename, 'w') {|f| f.write(data.to_yaml)}
      else
        File.open(filename, 'w') {|f| f.write(get_model_sample_record(model))}
      end
    end
    print_engine_message engine, :created, "#{domain_directory}/#{filename}"
  end

  def get_model_sample_record(model)
    columns = get_table_column_names_without_timestamps(model)
    return '# model does not have any non-timestamp columns'  if columns.blank?
    sample_record          = columns.map {|col| "#   #{col}:"}
    sample_record[0][0..2] = '# -'
    sample_record.join("\n")
  end

  def archive_engine_domain_yml_file(engine, model)
    filename         = domain_model_filename(model)
    archive_filename = "#{Time.now.to_s(:db)}_#{filename}".gsub(':', '-').gsub(' ', '_')
    source_file      = engine_domain_model_file_path(engine, model)
    source_content   = File.read(source_file)
    domain_dir       = engine_domain_path(engine)
    archive_dir      = engine_domain_archive_path(engine)
    unless File.directory?(archive_dir)
      Dir.chdir(domain_dir) do
        Dir.mkdir(domain_archive_directory)
      end
    end
    raise_error "Archive #{archive_dir.inspect} directory does not exist."  unless File.directory?(archive_dir)
    Dir.chdir(archive_dir) do
      File.open(archive_filename, 'w') {|f| f.write(source_content)}
    end
    print_engine_message engine, :archived, "#{domain_directory}/#{domain_archive_directory}/#{archive_filename}"
  end

  def create_engine_domain_directory(engine)
    domain_dir = engine_domain_path(engine)
    if File.exists?(domain_dir)
      raise_error "Invalid domain directory #{domain_dir.inspect} in engine #{engine.engine_name.inspect}."  unless File.directory?(domain_dir)
      print_engine_message engine, :kept, "db/#{domain_directory}."
      return
    end
    db_dir = engine_db_path(engine)
    raise_error "No 'db' directory in engine #{engine.engine_name.inspect}."  unless File.directory?(db_dir)
    Dir.chdir(db_dir) do
      Dir.mkdir(domain_directory)
    end
    print_engine_message engine, :created, "db/#{domain_directory} directory."
  end

  def get_model_yml_data(engine, model)
    file_path = engine_domain_model_file_path(engine, model)
    raise DomainFileNotFound, "Domain file #{file_path.inspect} does not exist."  unless File.file?(file_path)
    data = read_yml_file(file_path)
    raise_error "Domain file #{file_path.inspect} data is not an array."  unless data.is_a?(Array)
    format_data_records(data)
    data
  end

  def format_data_records(data)
    data.each do |data_record|
      id               = data_record[:id]
      id               = id.strip  if id.is_a?(String)
      data_record[:id] = id.blank? ? nil : id.to_i
    end
  end

  def read_yml_file(file_path)
    content = File.read(file_path)
    data    = YAML.load(content)
    data    = Array.new if data.blank?
    raise_error "YAML data file id not an array #{file_path.inspect}." unless data.is_a?(Array)
    data.map {|h| h.is_a?(Hash) ? h.with_indifferent_access : h}
  end

  # ###
  # ### Engines.
  # ###

  def get_args_engines_and_models(args)
    hash         = Hash.new
    args         = [args].flatten.compact
    name         = args.shift
    models       = args
    engine_names = totem_registered_engines
    if name.present?
      engine_names = name.end_with?('*') ? engine_names.select {|n| n.start_with?(name.chop)} : [name]
    end
    engine_names.sort.each do |name|
      engine        = totem_engine_by_name(name)
      engine_models = get_engine_models(engine, models)
      hash[engine]  = engine_models  if engine_models.present?
    end
    stop_run "No registered engines found matching the arguments engine: #{name.inspect} models: #{models.inspect}"  if hash.blank?
    hash
  end

  def get_engine_models(engine, models)
    filename  = 'associations.yml'
    file_path = File.join(engine_db_path(engine), filename)
    return nil unless File.file?(file_path)
    associations  = read_yml_file(file_path)
    raise_error "Associations file is not an array #{file_path.inspect}." unless associations.is_a?(Array)
    domain_models = Array.new
    associations.each do |hash|
      hash = hash.with_indifferent_access
      next unless hash[:domain] == true
      model_path = hash[:model]
      next if models.present? && (!models.find {|m| model_path.end_with?(m.singularize)})
      stop_run "Domain model #{model_path.inspect} is not a model for engine #{engine.engine_name.inspect}." unless is_engine_model?(engine, model_path)
      klass = get_model_class(model_path)
      stop_run "Domain model #{model_path.inspect} could not be constantized for engine #{engine.engine_name.inspect}." if klass.blank?
      domain_models.push(klass)
    end
    domain_models.sort_by {|m| m.name}
  end

  def is_engine_model?(engine, model_path); model_path.classify.start_with?(engine.class.name.deconstantize); end

  def get_model_class(model_path)
    raise_error "Model path is blank."  if model_path.blank?
    model_path.classify.safe_constantize
  end

  def totem_engine;             totem_settings.engine; end
  def totem_registered_engines; totem_settings.registered.engines; end

  def totem_engine_by_name(name)
    engine = totem_engine.get_by_name(name)
    stop_run "Engine #{name.inspect} not found."              if engine.blank?
    stop_run "More than one engine matched #{name.inspect}."  if engine.length > 1
    engine.first
  end

  def totem_engines_by_starts_with(name)
    engines = totem_engine.find_by_starts_with(name)
    stop_run "No engines start with #{name.inspect}."   if engines.blank?
    engines
  end

  # ###
  # ### Tables.
  # ###

  def timestamps_columns; ['created_at', 'updated_at']; end
  def ignore_timestamps?; @ignore_timestamps == true; end

  def get_domain_table_record_scope(model)
    has_domain_column?(model) ? model.where(domain: true).order(:id) : model.all.order(:id)
  end

  def get_domain_table_record_ids(model); get_domain_table_record_scope(model).pluck(:id); end

  def get_table_column_names(model); model.column_names; end

  def get_table_column_names_without_timestamps(model); get_table_column_names(model) - timestamps_columns; end
  
  def has_domain_column?(model); get_table_column_names(model).include?('domain'); end

  # ###
  # ### Run Results.
  # ###

  def reset_counts
    @records_created   = 0
    @records_recreated = 0
    @records_updated   = 0
    @records_destroyed = 0
    @records_verified  = 0
    
    @records_created_attributes   = Array.new
    @records_recreated_attributes = Array.new
    @records_updated_attributes   = Array.new
    @records_destroyed_attributes = Array.new
    @records_verified_attributes  = Array.new

    @file_messages                = Array.new
  end

  def print_model_results(model)
    print_message "--Domain model: #{model.name} ".ljust(80,'-')
    print_count :created,   @records_created,   @records_created_attributes
    print_count :recreated, @records_recreated, @records_recreated_attributes
    print_count :updated,   @records_updated,   @records_updated_attributes
    print_count :destroyed, @records_destroyed, @records_destroyed_attributes
    print_count :verified,  @records_verified,  @records_verified_attributes
    @file_messages.each do |message|
      print_message '  ' + message
    end
    print_message "\n"
  end

  def print_count(type, num, attributes=[])
    return if num == 0
    c_len         = 5
    t_len         = 15
    m_len         = 130
    message       = "  #{type}".ljust(t_len) + ': ' + num.to_s.rjust(c_len)
    print_message message
    attributes.each do |hash|
      hash_str = hash.except(*timestamps_columns).inspect
      more     = hash_str.length - m_len
      if more <= 12
        message = hash_str
        more    = 0
      else
        message = hash_str[0..m_len]
      end
      message += " (+#{more} more...)"  if more > 0
      print_message (' ' * 24) + message
    end
  end

  def print_run_messages
    return if run_messages.blank?
    @run_messages.each do |message|
      print_message message
    end
    print_message "\n"
  end

  def print_engine_message(engine, key, message=nil)
    if message.present?
      message = key.to_s.ljust(10) + ': ' + message
    end
    message = "[#{engine.engine_name}] " + message
    self.instance_variable_defined?(:@file_messages) ? @file_messages.push(message) : print_message(message)
  end

  def print_message(message='')
    puts '[db-domain] ' + message
  end

  def stop_run(message='')
    print_message "\n"
    print_message message
    print_message "Run stopped."
    print_message "\n"
    exit
  end

  def raise_error(message='')
    raise DomainError, message
  end

  class DomainFileNotFound < StandardError; end
  class DomainError        < StandardError; end

end; end; end; end; end
