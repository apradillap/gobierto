require "test_helper"

class GobiertoBudgets::BudgetLinesTest < ActionDispatch::IntegrationTest
  def setup
    super
    @path = gobierto_budgets_budget_lines_path(last_year, GobiertoBudgets::BudgetLine::ECONOMIC, GobiertoBudgets::BudgetLine::INCOME)
  end

  def site
    @site ||= sites(:madrid)
  end

  def last_year
    2016
  end

  def test_budget_lines
    with_current_site(site) do
      visit @path

      assert has_content?("Explore the detail")
      assert has_content?("Impuestos directos")
      assert has_content?("Impuestos indirectos")
    end
  end

  def test_change_budget_line_area
    with_current_site(site) do
      visit @path

      click_link "Expenses"
      assert has_content?("Deuda pública")

      click_link "To do what is spent"
      assert has_content?("Gastos de personal")
    end
  end
end
