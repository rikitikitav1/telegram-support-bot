# coding UTF-8

module Statistics
  #Модуль, который обслуживает работу с таблицей статистики
 
  def self.give(params= {})
    if (["internal", "admin", "testing"].include? params[:type]) && (['wallarm', 'admin'].include? params[:user_type])
      time_start = params[:start]        
      time_end = time_start + 3600 * 24
      dataset = DB['SELECT c.clientid, c.client, c.partnerid, s.duration, t.tickets
                    FROM (SELECT MAX(time) - MIN(time) duration, chatid 
                    FROM statistics
                    WHERE time BETWEEN ? AND ? GROUP BY chatid) s
                    INNER JOIN (SELECT * FROM chats WHERE type = "client_chat") c 
                    ON s.chatid = c.chatid
                    LEFT OUTER JOIN (SELECT chatid, GROUP_CONCAT(jira) tickets 
                    FROM tickets WHERE created BETWEEN ? AND ? GROUP BY chatid ) t 
                    ON s.chatid = t.chatid', time_start, time_end, time_start, time_end].all
      #Тикеты только актуальные показывать, а не все!
      result, count = [], 1
      dataset.each do |h|
        str = "#{count}) "
        count += 1
        h.each do |k, v|
          v = if k == :duration
            BotHelper.normalize_time(v)
          else; v; end
          str += (k.to_s + ": " + v.to_s + ", ") if v
        end
        result.push(str)
      end
      BotHelper.send_message(chat_id: params[:chatid], 
              text: "Статистика за #{params[:date]}:\n#{result.join("\n")}")      
    end
  end

  def self.drop()
    DB.drop_table :statistics
    SemanticLogger['statistics'].info("table dropped")
  end

  def self.create() 
    DB.create_table :statistics do
      Bigint  :id, primary_key: true
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
    SemanticLogger['statistics'].info("table created")
  end

  def self.backup()
    time_start = Time.now.to_i - 3600 * 24 * 7
    result = StatisticRecord.where(deleted: false,
                                    time: time_start..Time.now.to_i).all.map{ |sr|
                                          { time: sr.time,
                                            clientid: sr.clientid,
                                            message_id: sr.message_id,
                                            message_text: sr.message_text,
                                            username: sr.username,
                                            userid: sr.userid,
                                            chatid: sr.chatid }}
    SemanticLogger['statistics'].info("backup done")
    result
  end

  def self.seed(saved_data)
    saved_data.each{|sr| StatisticRecord.create(sr)} unless saved_data.nil?
    SemanticLogger['statistics'].info("table filled by backuped data")
  end

  def self.reroll(params={})
    if ((["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")) || (locked.include? params[:id])
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
