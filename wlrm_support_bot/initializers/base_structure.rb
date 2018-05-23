# coding UTF-8

#[:statistics, :chats, :users].each{|t| (DB.tables.include? t) ? DB.drop_table : nil}

unless DB.tables.include? :users
  DB.create_table :users do
    Bigint :userid, primary_key: true
    String :name, null: true #
    String :phone, null: true #
    String :username, null: true #
    String :type, null: false, default: "client" #
    TrueClass :enabled, null: false, default: true #
  end
end

unless DB.tables.include? :chats
  DB.create_table :chats do
    Bigint :chatid, primary_key: true
    String :clientid, null: true
    String :partnerid, null: true
    String :client, null: true
    Integer :created, null: false #
    String :language, null: false, default: "ru"
    String :type, null: false, default: "client_chat"
    TrueClass :enabled, null: false, default: true #
  end
end

unless DB.tables.include? :statistics
  DB.create_table :statistics do
    primary_key :id
    Integer :time, null: false #
    String :clientid, null: true
    Bigint :message_id, null: false
    String :message_text, null: true
    String :username, null: true #
    TrueClass :deleted, null: false, default: false #
    Bigint :userid, null: false
    Bigint :chatid, null: false
    foreign_key [:chatid], :chats, key: :chatid, unique: false
    foreign_key [:userid], :users, key: :userid, unique: false
  end
end

unless DB.tables.include? :tickets
  DB.create_table :tickets do
    String :jira, size: 10, primary_key: true
    String :clientid, null: true
    Integer :created, null: false #
    String :status, null: false, default: "open" #
    TrueClass :resolved, null: false, default: false #
    Bigint :userid, null: false
    Bigint :chatid, null: false
    foreign_key [:chatid], :chats, key: :chatid, unique: false
    foreign_key [:userid], :users, key: :userid, unique: false
    foreign_key :statid, :statistics, key: :id, unique: true
  end
end
#Добавить учет тикетов
#Добавить роут переключения статуса "open", "l2", "waiting for customer", "waiting for develop", "done"
#Добавить роут отчета всех
#Добавить роут отчета по клиенту (чату)
