module Thinkspace; module Reporter; module Api
class ReportsController < ::Totem::Settings.class.thinkspace.authorization_api_controller
  load_and_authorize_resource class: totem_controller_model_class
  totem_action_serializer_options

  def index
    @reports = @reports.scope_for_index.limit(10)
    controller_render(@reports)
  end

  def generate
    authable         = get_and_authorize_authable
    @report          = Thinkspace::Reporter::Report.new
    @report.authable = authable
    @report.value    = params
    @report.user_id  = current_user.id
    @report.title    = @report.get_title_from_type

    if @report.save
      @report.generate
      controller_render_no_content
    else
      permission_denied("Could not generate report, please try again later.")
    end
  end

  def access
    token = params[:id] # Token is the ID for the member route.
    permission_denied('Token has expired or could not be found.') unless token.present?
    report_token = Thinkspace::Reporter::ReportToken.find_by(token: token)
    if report_token.present? && report_token.is_valid? && is_current_user_on_report_token?(report_token)
      report = report_token.get_report
      permission_denied('Token has expired or could not be found.') unless report.present?
      controller_render(report)
    else
      permission_denied('Token has expired or could not be found.')
    end
  end

  def destroy
    authable = @report.authable
    authorize! :report, authable
    authorize! :update, authable
    controller_destroy_record(@report)
  end

  private

  def get_and_authorize_authable
    authable = get_authable_from_params
    authorize! :report, authable
    authorize! :update, authable
    authable
  end

  def get_authable_from_params
    auth_params = params[:auth]
    permission_denied('Invalid authorization parameters supplied.') unless auth_params.present?
    type = auth_params[:authable_type]
    id   = auth_params[:authable_id]
    permission_denied('Invalid authorization parameters supplied - ID') unless id.present?
    permission_denied('Invalid authorization parameters supplied - Type') unless type.present?
    klass = type.classify.safe_constantize
    permission_denied("Invalid authorization parameters supplied - #{type}") unless klass.present?
    record = klass.find_by(id: id)
    permission_denied('Invalid record supplied.') unless record.present?
    record
  end

  def is_current_user_on_report_token?(report_token)
    report_token.get_user == current_user
  end

  def permission_denied(message='Cannot access this report.', options={})
    action = options[:action] ||= :unknown
    options[:user_message] = message
    raise_access_denied_exception(message, action, nil, options)
  end

end; end; end; end
