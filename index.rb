# Gemfile
source 'https://rubygems.org'

gem 'sinatra'
gem 'sinatra-contrib'
gem 'sqlite3'
gem 'activerecord'
gem 'sinatra-activerecord'
gem 'rake'
gem 'json'
gem 'puma'

# config.ru
require './app'
run Sinatra::Application

# Rakefile
require 'sinatra/activerecord/rake'
require './app'

# config/database.yml
development:
  adapter: sqlite3
  database: db/finance_development.sqlite3
  pool: 5
  timeout: 5000

production:
  adapter: postgresql
  url: <%= ENV['DATABASE_URL'] %>
  pool: 5
  timeout: 5000

# db/migrate/20240219_create_tables.rb
class CreateTables < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions do |t|
      t.date :date
      t.decimal :amount, precision: 10, scale: 2
      t.string :category
      t.string :description
      t.string :type
      t.timestamps
    end

    create_table :budgets do |t|
      t.string :category
      t.decimal :amount, precision: 10, scale: 2
      t.decimal :spent, precision: 10, scale: 2
      t.timestamps
    end

    create_table :goals do |t|
      t.string :name
      t.decimal :target_amount, precision: 10, scale: 2
      t.decimal :current_amount, precision: 10, scale: 2
      t.date :deadline
      t.timestamps
    end
  end
end

# models/transaction.rb
class Transaction < ActiveRecord::Base
  validates :amount, presence: true, numericality: true
  validates :category, presence: true
  validates :type, presence: true
end

# models/budget.rb
class Budget < ActiveRecord::Base
  validates :category, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: true

  def remaining
    amount - spent
  end

  def percentage_used
    ((spent / amount) * 100).round(2)
  end
end

# models/goal.rb
class Goal < ActiveRecord::Base
  validates :name, presence: true
  validates :target_amount, presence: true, numericality: true

  def progress_percentage
    ((current_amount / target_amount) * 100).round(2)
  end

  def days_remaining
    (deadline - Date.today).to_i
  end
end

# app.rb
require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/json'
require './models/transaction'
require './models/budget'
require './models/goal'

set :database_file, 'config/database.yml'

# Ana sayfa
get '/' do
  erb :index
end

# İşlemler
post '/transactions' do
  transaction = Transaction.new(JSON.parse(request.body.read))
  if transaction.save
    json transaction
  else
    status 422
    json errors: transaction.errors
  end
end

get '/transactions' do
  json Transaction.all
end

# Bütçeler
post '/budgets' do
  budget = Budget.new(JSON.parse(request.body.read))
  if budget.save
    json budget
  else
    status 422
    json errors: budget.errors
  end
end

get '/budgets' do
  json Budget.all
end

# Hedefler
post '/goals' do
  goal = Goal.new(JSON.parse(request.body.read))
  if goal.save
    json goal
  else
    status 422
    json errors: goal.errors
  end
end

get '/goals' do
  json Goal.all
end

# views/layout.erb
<!DOCTYPE html>
<html>
<head>
  <title>Kişisel Finans Yönetimi</title>
  <link rel="stylesheet" href="/styles.css">
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
  <%= yield %>
  <script src="/app.js"></script>
</body>
</html>

# views/index.erb
<div class="container">
  <h1>Kişisel Finans Yönetimi</h1>
  
  <div class="section">
    <h2>İşlemler</h2>
    <form id="transaction-form">
      <input type="number" name="amount" placeholder="Miktar" required>
      <input type="text" name="category" placeholder="Kategori" required>
      <input type="text" name="description" placeholder="Açıklama">
      <select name="type" required>
        <option value="income">Gelir</option>
        <option value="expense">Gider</option>
      </select>
      <button type="submit">Ekle</button>
    </form>
    <div id="transactions-list"></div>
  </div>

  <div class="section">
    <h2>Bütçeler</h2>
    <form id="budget-form">
      <input type="text" name="category" placeholder="Kategori" required>
      <input type="number" name="amount" placeholder="Miktar" required>
      <button type="submit">Bütçe Oluştur</button>
    </form>
    <div id="budgets-list"></div>
  </div>

  <div class="section">
    <h2>Hedefler</h2>
    <form id="goal-form">
      <input type="text" name="name" placeholder="Hedef Adı" required>
      <input type="number" name="target_amount" placeholder="Hedef Miktar" required>
      <input type="date" name="deadline" required>
      <button type="submit">Hedef Oluştur</button>
    </form>
    <div id="goals-list"></div>
  </div>

  <div class="section">
    <h2>Raporlar</h2>
    <canvas id="expense-chart"></canvas>
  </div>
</div>

# public/styles.css
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.section {
  margin-bottom: 30px;
  padding: 20px;
  border: 1px solid #ddd;
  border-radius: 5px;
}

form {
  display: grid;
  gap: 10px;
  margin-bottom: 20px;
}

input, select, button {
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

button {
  background-color: #007bff;
  color: white;
  border: none;
  cursor: pointer;
}

button:hover {
  background-color: #0056b3;
}

# public/app.js
document.addEventListener('DOMContentLoaded', function() {
  // İşlem formu
  document.getElementById('transaction-form').addEventListener('submit', async function(e) {
    e.preventDefault();
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData);
    
    try {
      const response = await fetch('/transactions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      });
      
      if (response.ok) {
        loadTransactions();
        e.target.reset();
      }
    } catch (error) {
      console.error('Hata:', error);
    }
  });

  // Bütçe formu
  document.getElementById('budget-form').addEventListener('submit', async function(e) {
    e.preventDefault();
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData);
    
    try {
      const response = await fetch('/budgets', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      });
      
      if (response.ok) {
        loadBudgets();
        e.target.reset();
      }
    } catch (error) {
      console.error('Hata:', error);
    }
  });

  // Hedef formu
  document.getElementById('goal-form').addEventListener('submit', async function(e) {
    e.preventDefault();
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData);
    
    try {
      const response = await fetch('/goals', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      });
      
      if (response.ok) {
        loadGoals();
        e.target.reset();
      }
    } catch (error) {
      console.error('Hata:', error);
    }
  });

  // Verileri yükleme
  async function loadTransactions() {
    const response = await fetch('/transactions');
    const transactions = await response.json();
    
    const list = document.getElementById('transactions-list');
    list.innerHTML = transactions.map(t => `
      <div class="transaction">
        <strong>${t.amount} TL</strong> - ${t.category}
        <span>${t.description}</span>
        <small>${new Date(t.date).toLocaleDateString()}</small>
      </div>
    `).join('');

    updateChart(transactions);
  }

  async function loadBudgets() {
    const response = await fetch('/budgets');
    const budgets = await response.json();
    
    const list = document.getElementById('budgets-list');
    list.innerHTML = budgets.map(b => `
      <div class="budget">
        <strong>${b.category}</strong>
        <div class="progress">
          <div class="progress-bar" style="width: ${b.percentage_used}%">
            ${b.percentage_used}%
          </div>
        </div>
        <span>${b.spent} / ${b.amount} TL</span>
      </div>
    `).join('');
  }

  async function loadGoals() {
    const response = await fetch('/goals');
    const goals = await response.json();
    
    const list = document.getElementById('goals-list');
    list.innerHTML = goals.map(g => `
      <div class="goal">
        <strong>${g.name}</strong>
        <div class="progress">
          <div class="progress-bar" style="width: ${g.progress_percentage}%">
            ${g.progress_percentage}%
          </div>
        </div>
        <span>${g.current_amount} / ${g.target_amount} TL</span>
        <small>Kalan: ${g.days_remaining} gün</small>
      </div>
    `).join('');
  }

  // Grafik güncelleme
  function updateChart(transactions) {
    const ctx = document.getElementById('expense-chart').getContext('2d');
    const expenses = transactions.filter(t => t.type === 'expense');
    const categories = [...new Set(expenses.map(t => t.category))];
    
    const data = categories.map(category => {
      return expenses
        .filter(t => t.category === category)
        .reduce((sum, t) => sum + parseFloat(t.amount), 0);
    });

    new Chart(ctx, {
      type: 'pie',
      data: {
        labels: categories,
        datasets: [{
          data: data,
          backgroundColor: [
            '#FF6384',
            '#36A2EB',
            '#FFCE56',
            '#4BC0C0',
            '#9966FF'
          ]
        }]
      }
    });
  }

  // İlk yükleme
  loadTransactions();
  loadBudgets();
  loadGoals();
});
