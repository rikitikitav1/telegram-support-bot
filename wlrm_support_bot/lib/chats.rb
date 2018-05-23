# coding UTF-8

#Добавить проверку на удаленный чат

module Chats

  def self.get(message)
    denied_types = %w[private secret denied]
    chat_type = Telegram::Bot::Client.run(TOKEN) do |bot|
      begin
        bot.api.getChat(chat_id: message.chat.id)['result']['type']
      rescue
        'denied'
        next
      end
    end
    if denied_types.include? chat_type
      Telegram::Bot::Client.run(TOKEN) do |bot|
        bot.api.send_message(chat_id: message.chat.id,
                             text: "Sorry #{chat_type} chat type is not supported")
      end
      false
    else
      unless Chat[chatid: message.chat.id]
        clientid =  message.chat.title.scan(/\d+.*\d+/)[0].scan(/\d+/).to_s.gsub(/\]|\[|\"/,'') 
        #Заменить регулярку клиента, добавить учет часового пояса str.scan(/МСК[\+-]\d/) как нибудь
        client = message.chat.title.sub(/wallarm/i, '').gsub(/[\d|\|]/, '')
        chat_params = { created: Time.now.to_i, 
                        clientid: clientid, 
                        partnerid: "1",
                        chatid: message.chat.id,
                        language: "ru", 
                        type: "client_chat", 
                        client: client, 
                        enabled: true }
        Chat.create(chat_params)
        c = Chat[chatid: message.chat.id] 
        str =  "cl: #{c.clientid}, pa: #{c.partnerid}, #{c.language}, #{c.type}, #{c.chatid}"
        chats = Chat.where(type:['admin', 'testing']).all.map(&:chatid)
        chats.each do |cd|
          BotHelper.send_message(chat_id: cd, 
                              text: "Бот подключен новому клиенту:\n#{str}")
        end
        chat_params
      else
        Chat[chatid:message.chat.id].update(enabled: true)
        ch = Chat[chatid:message.chat.id]
        chat_params = { created: ch.created, 
                        clientid: ch.clientid,
                        partnerid: ch.partnerid, 
                        chatid: ch.chatid,
                        language: ch.language, 
                        type: ch.type, 
                        client: ch.client, 
                        enabled: true }           
      end
    end
  end

  def self.attr_valide(value, attribute)
    result = {} 
    case attribute
    when :clientid
      if (value.split(',').map(&:to_i)[0].is_a?(Integer)) && (value.size < 200)
        result[attribute] = BotHelper.normalize_text(value, 200)
      end
    when :partnerid
      if (value.split(',').map(&:to_i)[0].is_a?(Integer)) && (value.size < 200)
        result[attribute] = BotHelper.normalize_text(value, 200)
      end
    when :client
      if value == BotHelper.normalize_text(value, 50)
        result[attribute] = BotHelper.normalize_text(value, 50)
      end
    when :language
        result[attribute] = value if ['ru', 'en'].include? value
    when :type
      if ["client_chat", "internal", "testing", "admin"].include? value 
        result[attribute] = value
      end
    when :enabled
      result[attribute]  = true if value == 'true'
      result[attribute]  = false if value == 'false'
    when :chatid
      result[attribute]  = value if Chat[chatid: value]
    when :chatid_new
      result[:chatid] = value.to_i if value.to_i.to_s[0..20] == value
    end
    result if result.size == 1
  end

  def self.add(params= {})
    chat = attr_valide(params[:chat_to_add], :chatid_new)
    if (["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")
      if chat
        params = { created: Time.now.to_i, 
                   clientid: "10500",
                   language: 'ru',
                   type: "client_chat",
                   client: "",
                   enabled: true }.merge(chat)
        Chat.create(params)
      end
    end
  end

  def self.set(params= {})
    if (["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")
      unless params[:payload].count != 3
        chat = params[:payload][0].to_i
        attribute = params[:payload][1].to_sym
        val = params[:payload][2]
        settable = [:clientid, :partnerid, :client, :language, :type, :enabled]
        changes = attr_valide(val, attribute)
        SemanticLogger['chats'].info("#{attr_valide(chat, :chatid)}")
        if (settable.include? attribute) && attr_valide(chat, :chatid) && changes
          Chat[chatid: chat].update(changes)
          SemanticLogger['chats'].info("#{chat} changed #{attribute} to #{val}")
        end
      end
    end
  end
  
  def self.give(params= {})
    if (["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")
      data = if Chat.count == 0
        ['no chats']
      else
        data = Chat.where(enabled: params[:enabled]).all.map{|c| 
          "cl: #{c.clientid}, pa: #{c.partnerid}, #{c.language}, #{c.type}, #{c.chatid}"}
      end
      BotHelper.send_message(chat_id: params[:chatid], 
                            text: "Бот подключен в следующих чатах:\n#{data.join("\n")}")
    end
  end

  def self.drop()
      
    SemanticLogger['chats'].info("table dropped")
  end

  def self.create() 
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
    SemanticLogger['chats'].info("table created")
  end

  def self.seed_default()
    chat_add = 
    [{ chatid: -304890260,
      client: "test",
      type: "testing",
      created: Time.now.to_i,
      clientid: "1",
      partnerid: "1",
      language: "en",
      enabled: true },

    { chatid: -1001108274943,
      client: "Admins vs support",
      type: "internal",
      created: Time.now.to_i,
      clientid: "1",
      partnerid: "1",
      language: "ru",
      enabled: true },

    { chatid: -238879239,
      client: "support",
      type: "admin",
      created: Time.now.to_i,
      clientid: "1",
      partnerid: "1",
      language: "ru",
      enabled: true }]

    chat_add.each{|c| Chat[chatid: c[:chatid]].nil? ? Chat.create(c) : nil }
  end

  def self.backup()
    result = Chat.all.map{ |ch| 
              { chatid: ch.chatid,
                client: ch.client,
                type: ch.type,
                created: ch.created,
                clientid: ch.clientid,
                partnerid: ch.partnerid,
                language: ch.language,
                enabled: ch.created }}
    SemanticLogger['chats'].info("backup done")
    result
  end

  def self.seed(saved_data)
    saved_data.each{|c| Chat[chatid: c[:chatid]].nil? ? Chat.create(c) : nil } unless saved_data.nil?
    SemanticLogger['chats'].info("table filled by backuped data")
  end

  def self.reroll(params={})
    # сохраняется только недельный бекап статистики  
    if (["admin", "testing"].include? params[:type]) && (params[:user_type] == "admin")
      saved_tickets = Tickets.backup
      Tickets.drop
      saved_stat = Statistics.backup
      Statistics.drop
      saved_data = backup
      drop
      create
      seed_default
      seed(saved_data)
      Statistics.create
      Statistics.seed(saved_stat)
      Tickets.create
      Tickets.seed(saved_tickets)
    end
  end

end
