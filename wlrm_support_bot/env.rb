# coding UTF-8
TOKEN = ENV.fetch('TELEGRAM_TOKEN').freeze
LOGLEVEL = begin
  ENV.fetch('LOGLEVEL');
rescue;
  'info';
end

db_params = {adapter: 'mysql2',
             host: ENV.fetch('DBADDR'),
             database: ENV.fetch('DBNAME'),
             user: ENV.fetch('DBUSER'),
             password: ENV.fetch('DBPASS'),
             charset: 'utf8'}
DB = Sequel.connect(db_params)
DB.default_charset = 'utf8'

