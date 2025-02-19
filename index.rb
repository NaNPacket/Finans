require 'date'

class Transaction
  attr_reader :date, :amount, :category, :description, :type

  def initialize(amount:, category:, description:, type:, date: Date.today)
    @date = date
    @amount = amount.to_f
    @category = category
    @description = description
    @type = type # :income veya :expense
  end
end

class Budget
  attr_reader :category, :amount, :spent

  def initialize(category:, amount:)
    @category = category
    @amount = amount.to_f
    @spent = 0.0
  end

  def add_expense(amount)
    @spent += amount
  end

  def remaining
    @amount - @spent
  end

  def percentage_used
    (@spent / @amount * 100).round(2)
  end
end

class FinancialGoal
  attr_reader :name, :target_amount, :current_amount, :deadline

  def initialize(name:, target_amount:, deadline:)
    @name = name
    @target_amount = target_amount.to_f
    @current_amount = 0.0
    @deadline = Date.parse(deadline)
  end

  def add_progress(amount)
    @current_amount += amount.to_f
  end

  def progress_percentage
    (@current_amount / @target_amount * 100).round(2)
  end

  def days_remaining
    (@deadline - Date.today).to_i
  end
end

class FinanceManager
  def initialize
    @transactions = []
    @budgets = {}
    @goals = []
  end

  # İşlem ekleme
  def add_transaction(transaction)
    @transactions << transaction
    
    if transaction.type == :expense && @budgets[transaction.category]
      @budgets[transaction.category].add_expense(transaction.amount)
    end
  end

  # Bütçe oluşturma
  def create_budget(category:, amount:)
    @budgets[category] = Budget.new(category: category, amount: amount)
  end

  # Hedef oluşturma
  def create_goal(name:, target_amount:, deadline:)
    @goals << FinancialGoal.new(
      name: name,
      target_amount: target_amount,
      deadline: deadline
    )
  end

  # Toplam gelir hesaplama
  def total_income(start_date = nil, end_date = nil)
    filter_transactions(:income, start_date, end_date).sum(&:amount)
  end

  # Toplam gider hesaplama
  def total_expenses(start_date = nil, end_date = nil)
    filter_transactions(:expense, start_date, end_date).sum(&:amount)
  end

  # Kategoriye göre gider raporu
  def expenses_by_category(start_date = nil, end_date = nil)
    expenses = filter_transactions(:expense, start_date, end_date)
    report = {}
    
    expenses.each do |transaction|
      report[transaction.category] ||= 0
      report[transaction.category] += transaction.amount
    end
    
    report
  end

  # Bütçe durumu raporu
  def budget_status_report
    @budgets.transform_values do |budget|
      {
        toplam_butce: budget.amount,
        harcanan: budget.spent,
        kalan: budget.remaining,
        kullanim_yuzdesi: budget.percentage_used
      }
    end
  end

  private

  def filter_transactions(type, start_date = nil, end_date = nil)
    transactions = @transactions.select { |t| t.type == type }
    
    if start_date
      transactions = transactions.select { |t| t.date >= start_date }
    end
    
    if end_date
      transactions = transactions.select { |t| t.date <= end_date }
    end
    
    transactions
  end
end

# Kullanım örneği
finance = FinanceManager.new

# Bütçe oluşturma
finance.create_budget(category: "Market", amount: 1000)
finance.create_budget(category: "Ulaşım", amount: 500)

# Hedef oluşturma
finance.create_goal(
  name: "Tatil Fonu",
  target_amount: 5000,
  deadline: "2024-08-01"
)

# İşlemler ekleme
finance.add_transaction(
  Transaction.new(
    amount: 3000,
    category: "Maaş",
    description: "Aylık maaş",
    type: :income
  )
)

finance.add_transaction(
  Transaction.new(
    amount: 150,
    category: "Market",
    description: "Haftalık market alışverişi",
    type: :expense
  )
)

finance.add_transaction(
  Transaction.new(
    amount: 50,
    category: "Ulaşım",
    description: "Otobüs kartı yükleme",
    type: :expense
  )
)

# Raporlama örnekleri
puts "Toplam Gelir: #{finance.total_income}"
puts "Toplam Gider: #{finance.total_expenses}"
puts "\nKategorilere Göre Giderler:"
puts finance.expenses_by_category
puts "\nBütçe Durumu:"
puts finance.budget_status_report
