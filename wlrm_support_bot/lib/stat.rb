# coding UTF-8

module Statistics
  # Модуль, который обслуживает работу с таблицей статистики

  # Отчет по тикетам и потраченному времени
  def self.time_stat_report(time_start, time_end, chat_type)
    dataset = DB['SELECT c.clientid, c.client, c.partnerid, s.duration, t.tickets
                    FROM (SELECT MAX(time) - MIN(time) duration, chatid
                    FROM statistics
                    WHERE time BETWEEN ? AND ? GROUP BY chatid) s
                    INNER JOIN (SELECT * FROM chats WHERE type = ?) c
                    ON s.chatid = c.chatid
                    LEFT OUTER JOIN (SELECT chatid, GROUP_CONCAT(jira) tickets
                    FROM tickets WHERE created BETWEEN ? AND ? GROUP BY chatid ) t
                    ON s.chatid = t.chatid', time_start, time_end, chat_type, time_start, time_end].all
    result = []
    dataset.each_with_index do |data_hash, index|
      result_string = "#{index.succ}) "
      data_hash.each do |key, value|
        value = BotHelper.normalize_time(value) if key == :duration
        result_string += (key.to_s + ': ' + value.to_s + ', ') if value
      end
      result.push(result_string)
    end
    result
  end

  def self.give(params = {})
    if (%w[internal admin testing].include? params[:type]) && (%w[wallarm admin].include? params[:user_type])
      time_start = params[:start]
      time_end = time_start + 3600 * 24
      client_report = time_stat_report(time_start, time_end, 'client_chat')
      BotHelper.send_message(chat_id: params[:chatid],
                             text: "Клиентские чаты: #{params[:date]}:\n#{client_report.join("\n")}")
      partner_report = time_stat_report(time_start, time_end, 'partner')
      BotHelper.send_message(chat_id: params[:chatid],
                             text: "Партнерские чаты: #{params[:date]}:\n#{partner_report.join("\n")}")
    end
  end

  def self.drop
    DB.drop_table :statistics
    SemanticLogger['statistics'].info('table dropped') if LOGLEVEL == 'info'
  end

  def self.create
    DB.create_table :statistics do
      Bigint :id, primary_key: true
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
    SemanticLogger['statistics'].info('table created') if LOGLEVEL == 'info'
  end

  def self.backup
    time_start = Time.now.to_i - 3600 * 24 * 7
    result = StatisticRecord.where(deleted: false,
                                   time: time_start..Time.now.to_i).all.map do |sr|
      {time: sr.time,
       clientid: sr.clientid,
       message_id: sr.message_id,
       message_text: sr.message_text,
       username: sr.username,
       userid: sr.userid,
       chatid: sr.chatid}
    end
    SemanticLogger['statistics'].info('backup done') if LOGLEVEL == 'info'
    result
  end

  def self.seed(saved_data)
    saved_data.each {|sr| StatisticRecord.create(sr)} unless saved_data.nil?
    if LOGLEVEL == 'info'
      SemanticLogger['statistics'].info('table filled by backuped data')
    end
  end

  def self.reroll(params = {})
    if ((%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')) || (locked.include? params[:id])
      saved_tickets = Tickets.backup
      Tickets.drop
      saved_data = backup
      drop
      create
      seed(saved_data)
      Tickets.create
      Tickets.seed(saved_tickets)
    end
  end
end
