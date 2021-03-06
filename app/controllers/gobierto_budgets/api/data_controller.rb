module GobiertoBudgets
  module Api
    class DataController < ApplicationController
      include GobiertoBudgets::ApplicationHelper

      caches_action :total_budget, :total_budget_execution, :population, :total_budget_per_inhabitant, :lines,
                    :budget, :budget_execution, :budget_per_inhabitant, :budget_percentage_over_total, :debt

      def budget
        @year = params[:year].to_i
        @area = params[:area]
        @kind = params[:kind]
        @code = params[:code]

        @category_name = @kind == 'G' ? I18n.t("controllers.gobierto_budgets.api.data.expense") : I18n.t("controllers.gobierto_budgets.api.data.income")

        budget_data = budget_data(@year, 'amount')
        budget_data_previous_year = budget_data(@year - 1, 'amount', false)
        position = budget_data[:position].to_i
        sign = sign(budget_data[:value], budget_data_previous_year[:value])

        respond_to do |format|
          format.json do
            render json: {
              title: @category_name,
              sign: sign,
              value: format_currency(budget_data[:value]),
              delta_percentage: helpers.number_with_precision(delta_percentage(budget_data[:value], budget_data_previous_year[:value]), precision: 2),
              ranking_position: position,
              ranking_total_elements: helpers.number_with_precision(budget_data[:total_elements], precision: 0),
              ranking_url: ''
            }.to_json
          end
        end
      end

      def budget_per_inhabitant
        @year = params[:year].to_i
        @area = params[:area]
        @kind = params[:kind]
        @code = params[:code]

        @category_name = @kind == 'G' ? I18n.t("controllers.gobierto_budgets.api.data.expense") : I18n.t("controllers.gobierto_budgets.api.data.income")
        budget_data = budget_data(@year, 'amount_per_inhabitant')
        budget_data_previous_year = budget_data(@year - 1, 'amount_per_inhabitant', false)
        position = budget_data[:position].to_i
        sign = sign(budget_data[:value], budget_data_previous_year[:value])

        respond_to do |format|
          format.json do
            render json: {
              sign: sign,
              title: "#{@category_name} por habitante",
              value: format_currency(budget_data[:value]),
              delta_percentage: helpers.number_with_precision(delta_percentage(budget_data[:value], budget_data_previous_year[:value]), precision: 2),
              ranking_position: position,
              ranking_total_elements: helpers.number_with_precision(budget_data[:total_elements], precision: 0),
              ranking_url: ''
            }.to_json
          end
        end
      end

      def lines
        @place = INE::Places::Place.find(params[:ine_code])
        data_line = GobiertoBudgets::Data::Lines.new place: @place, year: params[:year], what: params[:what], kind: params[:kind], code: params[:code], area: params[:area]

        respond_lines_to_json data_line
      end

      def budget_execution_deviation
        year = params[:year].to_i
        kind = params[:kind]
        ine_code = params[:ine_code]
        total_budgeted = GobiertoBudgets::BudgetTotal.budgeted_for(ine_code,year,kind)
        total_executed = GobiertoBudgets::BudgetTotal.execution_for(ine_code,year,kind)
        deviation = total_executed - total_budgeted
        deviation_percentage = helpers.number_with_precision(delta_percentage(total_executed, total_budgeted), precision: 2)
        up_or_down = sign(total_executed, total_budgeted)
        evolution = deviation_evolution(ine_code, kind)

        heading = I18n.t("controllers.gobierto_budgets.api.data.budgets_execution_header", kind: kind_literal(kind), year: year)
        respond_to do |format|
          format.json do
            render json: {
              deviation_heading: heading,
              deviation_summary: deviation_message(kind, up_or_down, deviation_percentage, deviation),
              deviation_percentage: deviation_percentage,
              "#{kind}": {
                total_budgeted: format_currency(total_budgeted),
                total_executed: format_currency(total_executed),
                evolution: evolution,
                evolution_to_s: evolution.to_json
              }
            }.to_json
          end
        end
      end

      private

      def get_debt(year, ine_code)
        id = "#{ine_code}/#{year}"

        begin
          value = GobiertoBudgets::SearchEngine.client.get index: GobiertoBudgets::SearchEngineConfiguration::Data.index,
            type: GobiertoBudgets::SearchEngineConfiguration::Data.type_debt, id: id
          value['_source']['value'] * 1000
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
        end
      end

      def budget_data(year, field, ranking = true)
        ine_code = params[:ine_code].to_i

        opts = {year: year, code: @code, kind: @kind, area_name: @area, variable: field}
        results, total_elements = GobiertoBudgets::BudgetLine.for_ranking(opts)

        if ranking
          position = GobiertoBudgets::BudgetLine.place_position_in_ranking(opts.merge(ine_code: ine_code))
        else
          total_elements = 0
          position = 0
        end

        value = results.select {|r| r['ine_code'] == ine_code }.first.try(:[],field)

        return {
          value: value,
          position: position,
          total_elements: total_elements
        }
      end

      def budget_data_executed(year, field)
        id = "#{params[:ine_code]}/#{year}/#{@code}/#{@kind}"

        begin
          value = GobiertoBudgets::SearchEngine.client.get index: GobiertoBudgets::SearchEngineConfiguration::BudgetLine.index_executed, type: @area, id: id
          value = value['_source'][field]
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          value = nil
        end

        return {
          value: value
        }
      end


      def total_budget_data(year, field, ranking = true)
        query = {
          sort: [
            { field.to_sym => { order: 'desc' } }
          ],
          query: {
            filtered: {
              filter: {
                bool: {
                  must: [
                    {term: { year: year }},
                    {term: { kind: GobiertoBudgets::BudgetLine::EXPENSE }}
                  ]
                }
              }
            }
          },
          size: 10_000,
          _source: false
        }

        id = "#{params[:ine_code]}/#{year}/#{GobiertoBudgets::BudgetLine::EXPENSE}"

        if ranking
          response = GobiertoBudgets::SearchEngine.client.search index: GobiertoBudgets::SearchEngineConfiguration::TotalBudget.index_forecast, type: GobiertoBudgets::SearchEngineConfiguration::TotalBudget.type, body: query
          buckets = response['hits']['hits'].map{|h| h['_id']}
          position = buckets.index(id) + 1 rescue 0
        else
          buckets = []
          position = 0
        end

        begin
          value = GobiertoBudgets::SearchEngine.client.get index: GobiertoBudgets::SearchEngineConfiguration::TotalBudget.index_forecast, type: GobiertoBudgets::SearchEngineConfiguration::TotalBudget.type, id: id
          value = value['_source'][field]
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          value = 0
        end

        return {
          value: value,
          position: position,
          total_elements: buckets.length
        }
      end

      def total_budget_data_executed(year, field)
        id = "#{params[:ine_code]}/#{year}/#{GobiertoBudgets::BudgetLine::EXPENSE}"

        begin
          value = GobiertoBudgets::SearchEngine.client.get index: GobiertoBudgets::SearchEngineConfiguration::TotalBudget.index_executed, type: GobiertoBudgets::SearchEngineConfiguration::TotalBudget.type, id: id
          value = value['_source'][field]
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          value = nil
        end

        return {
          value: value
        }
      end

      def delta_percentage(value, old_value)
        return "" if value.nil? || old_value.nil?
        ((value.to_f - old_value.to_f)/old_value.to_f) * 100
      end

      def deviation_message(kind, up_or_down, percentage, diff)
        percentage = percentage.to_s.gsub('-', '')
        diff = format_currency(diff, true)
        final_message = if (kind == GobiertoBudgets::BudgetLine::INCOME)
          up_or_down == "sign-up" ? I18n.t("controllers.gobierto_budgets.api.data.income_up", percentage: percentage, diff: diff) : I18n.t("controllers.gobierto_budgets.api.data.income_down", percentage: percentage, diff: diff)
        else
          up_or_down == "sign-up" ? I18n.t("controllers.gobierto_budgets.api.data.expense_up", percentage: percentage, diff: diff) : I18n.t("controllers.gobierto_budgets.api.data.expense_down", percentage: percentage, diff: diff)
        end
        final_message
      end

      def deviation_evolution(ine_code, kind)
        response_budgeted = GobiertoBudgets::BudgetTotal.budget_evolution_for(ine_code, GobiertoBudgets::BudgetTotal::BUDGETED, kind)
        response_executed = GobiertoBudgets::BudgetTotal.budget_evolution_for(ine_code, GobiertoBudgets::BudgetTotal::EXECUTED, kind)

        response_budgeted.map do |budgeted_result|
          year = budgeted_result['year']
          total_budgeted = budgeted_result['total_budget']
          total_executed = response_executed.select {|te| te['year'] == year }.first.try(:[],'total_budget')
          next unless total_executed.present?

          deviation = delta_percentage(total_executed,total_budgeted)
          {
            year: year,
            deviation: helpers.number_with_precision(deviation, precision: 2,separator:'.').to_f
          }
        end.reject(&:nil?)
      end

      def get_places(ine_codes)
        ine_codes.split(':').map {|code| INE::Places::Place.find code}
      end

      def respond_lines_to_json(data_line)
        respond_to do |format|
          format.json do
            render json: data_line.generate_json
          end
        end
      end

    end
  end
end
