module Admin
  class EppLogsController < BaseController
    load_and_authorize_resource class: ApiLog::EppLog
    before_action :set_default_dates, only: [:index]

    def index
      @q = ApiLog::EppLog.ransack(params[:q])
      @q.sorts = 'id desc' if @q.sorts.empty?

      @epp_logs = @q.result
      if params[:q][:created_at_gteq].present?
        @epp_logs = @epp_logs.where("extract(epoch from created_at) >= extract(epoch from ?::timestamp)",
                                    Time.parse(params[:q][:created_at_gteq]))
      end
      if params[:q][:created_at_lteq].present?
        @epp_logs = @epp_logs.where("extract(epoch from created_at) <= extract(epoch from ?::timestamp)",
                                    Time.parse(params[:q][:created_at_lteq]))
      end
      @epp_logs = @epp_logs.page(params[:page])

      render_by_format('admin/epp_logs/index', 'epp_logs')
    end

    def show
      @epp_log = ApiLog::EppLog.find(params[:id])
    end

    def set_default_dates
      params[:q] ||= {}

      if params[:q][:created_at_gteq].nil? && params[:q][:created_at_lteq].nil? && params[:created_after].present?
        default_date = params[:created_after]

        if !['today', 'tomorrow', 'yesterday'].include?(default_date)
          default_date = 'today'
        end

        params[:q][:created_at_gteq] = Date.send(default_date).strftime("%Y-%m-%d")
      end
    end
  end
end
