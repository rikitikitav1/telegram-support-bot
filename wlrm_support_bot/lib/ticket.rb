# coding UTF-8

module Tickets
  
  def self.add(params= {})
    unless params[:jira].nil?
      ticket_params = { created: params[:time],
                         jira: params[:jira],
                         clientid: params[:clientid],
                         statid: params[:statid],
                         userid: params[:userid],
                         chatid: params[:chatid] }
      Ticket.create(ticket_params)
      SemanticLogger['tickets'].info("#{params[:jira]} created in #{params[:chatid]}")
    end
  end

   def self.admin_add(params= {})
    if (["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")
      BotHelper.send_message(chat_id: params[:chatid], jira: params[:jira],
                            text: "\n#{params[:jira]} успешно занесен в базу")

      SemanticLogger['tickets'].info("#{params[:jira]} created in #{params[:chatid]}")
    end
  end


  def self.attr_valide(value, attribute)
    result = {}
    case attribute
    when :jira then result[attribute] = value if (Ticket[jira: value])
    when :clientid
      if (value.split(',').map(&:to_i)[0].is_a?(Integer)) && (value.size < 200)
        result[attribute] = BotHelper.normalize_text(value, 200)
      end
    when :status
      if ["open", "wait_for_development", "wait_for_customer", "closed", "wait_for_admin"].include? value
      result[attribute] = value
        if value == "closed"
          result[:resolved] = true
        else
          result[:resolved] = false
        end
      end 
    end
    result if ([1, 2].include? result.size)
  end

  def self.set(params= {})
    if (["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")
      unless params[:payload].count != 3  
        jira = params[:payload][0].to_s
        attribute = params[:payload][1].to_sym
        val = params[:payload][2]
        settable = [:status, :jira, :clientid, :resolved]
        changes = attr_valide(val, attribute)
        SemanticLogger['tickets'].info(changes)
        if (settable.include? attribute) && changes && attr_valide(jira, :jira)
          Ticket[jira: jira].update(changes)
          ti = Ticket[jira: jira]
          BotHelper.send_message(chat_id: ti.chatid, 
                    text: "Ticket #{ti.jira} #{attribute} >> #{val}")
        end
      end
    end
  end


  def self.give(params= {})
    if (["internal", "admin", "testing"].include? params[:type]) && (['wallarm', 'admin'].include? params[:user_type])
      data = if Ticket.where(resolved: params[:resolved]).count == 0
          ['no tickets']
        else
          data = Ticket.where(resolved: params[:resolved]).all
          data = data.map{|t| "Ticket: #{t.jira}, #{t.status}, cl: #{t.clientid}, в работе: #{BotHelper.normalize_time(Time.now.to_i - t.created)}"}
        end
        BotHelper.send_message(chat_id: params[:chatid], 
                              text: "Данные по тикетам:\n#{data.join("\n")}")
    end
  end

  def self.give_client(params= {})
    multilang = {
            "ru" => { 1 => "в работе: ",
                      2 => "Данные по тикетам"},
            "en" => { 1 => "processing: ",
                      2 => "Tickets report"}}
    lang = params[:language]
    if Ticket.where(chatid: params[:chatid]).count == 0
      data = ['no tickets']
    else
      data = Ticket.where(chatid: params[:chatid]).all.map{|t| 
        ["Ticket: "+t.jira,
         t.status,
         !(t.resolved) ? (multilang[lang][1]+BotHelper.normalize_time((Time.now.to_i - t.created), lang)) : nil ].join(", ")}
    end
    BotHelper.send_message(chat_id: params[:chatid], 
                            text: "#{multilang[lang][2]}:\n#{data.join("\n")}")
  end
  def self.drop()
    DB.drop_table :tickets
    SemanticLogger['tickets'].info("table dropped")
  end

  def self.create() 
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
    SemanticLogger['tickets'].info("table created")
  end

  def self.backup()
    time_start = Time.now.to_i - 3600 * 24 * 7
    result = Ticket.where(time: time_start..Time.now.to_i).all.map{ |t|
                                          { created: t.created,
                                            jira: t.jira,
                                            clientid: t.clientid,
                                            status: t.status,
                                            resolved: t.resolved,
                                            statid: t.statid,
                                            userid: t.userid,
                                            chatid: t.chatid }}
    SemanticLogger['tickets'].info("backup done")
    result
  end

  def self.seed(saved_data)
    saved_data.each{|t| Ticket.create(t)} unless saved_data.nil?
    SemanticLogger['tickets'].info("table filled by backuped data")
  end

  def self.reroll(params={})
    if (["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")
      saved_data = backup
      drop
      create
      seed(saved_data)
    end
  end

end
