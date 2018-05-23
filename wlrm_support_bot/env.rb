# coding UTF-8
TOKEN = ENV.fetch('TELEGRAM_TOKEN').freeze

db_params = {adapter: 'mysql2',
	host: ENV.fetch('DBADDR'),
  database: ENV.fetch('DBNAME'),
  user: ENV.fetch('DBUSER'), 
  password: ENV.fetch('DBPASS'),
  encoding: 'utf8'}


DB = Sequel.connect(db_params)

