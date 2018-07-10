# coding UTF-8

# Добавить проверку на удаленный чат

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
      ch = Chat[chatid: message.chat.id]
      if ch
        chat_params = {created: ch.created,
                       clientid: ch.clientid,
                       partnerid: ch.partnerid,
                       chatid: ch.chatid,
                       language: ch.language,
                       type: ch.type,
                       client: ch.client,
                       enabled: ch.enabled}
      else

        clientid = unless message.chat.title.scan(/\d+.*\d+/)[0].nil?
                     message.chat.title.scan(/\d+.*\d+/)[0].scan(/\d+/).to_s.gsub(/\]|\[|\"/, '')
                   else
                     '0'
                   end

        client = message.chat.title.sub(/wallarm/i, '').gsub(/[\d|\|]/, '')
        chat_params = {created: Time.now.to_i,
                       clientid: clientid,
                       partnerid: '1',
                       chatid: message.chat.id,
                       language: 'ru',
                       type: 'client_chat',
                       client: client,
                       enabled: true}
        Chat.create(chat_params)
        c = Chat[chatid: message.chat.id]
        str = "cl: #{c.clientid}, name: #{c.client}, pa: #{c.partnerid}, #{c.language}, #{c.type}, #{c.chatid}"
        chats = Chat.where(type: %w[admin testing], enabled: true).all.map(&:chatid)
        if LOGLEVEL == 'info'
          SemanticLogger['chats'].info("New client added:\n#{str}")
        end
        chats.each do |cd|
          BotHelper.send_message(chat_id: cd,
                                 text: "Бот подключен новому клиенту:\n#{str}")
        end
        chat_params
      end
    end
  end

  def self.attr_valide(value, attribute)
    result = {}
    case attribute
    when :clientid
      if value.split(',').map(&:to_i)[0].is_a?(Integer) && (value.size < 200)
        result[attribute] = BotHelper.normalize_text(value, 200)
      end
    when :partnerid
      if value.split(',').map(&:to_i)[0].is_a?(Integer) && (value.size < 200)
        result[attribute] = BotHelper.normalize_text(value, 200)
      end
    when :client
      if value == BotHelper.normalize_text(value, 50)
        result[attribute] = BotHelper.normalize_text(value, 50)
      end
    when :language
      result[attribute] = value if %w[ru en].include? value
    when :type
      if %w[client_chat internal testing partner admin].include? value
        result[attribute] = value
      end
    when :enabled
      result[attribute] = true if value == 'true'
      result[attribute] = false if value == 'false'
    when :chatid
      result[attribute] = value if Chat[chatid: value]
    when :chatid_new
      result[:chatid] = value.to_i if value.to_i.to_s[0..20] == value
    end
    result if result.size == 1
  end

  def self.add(params = {})
    chat = attr_valide(params[:chat_to_add], :chatid_new)
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      if chat
        params = {created: Time.now.to_i,
                  clientid: '10500',
                  language: 'ru',
                  type: 'client_chat',
                  client: '',
                  enabled: true}.merge(chat)
        Chat.create(params)
      end
    end
  end

  def self.set(params = {})
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      unless params[:payload].count != 3
          if params[:payload][0] == 'last'
            chat = DB['SELECT chatid FROM chats where created = (select MAX(created) from chats)'][:chatid][:chatid]
            SemanticLogger['chats'].info("#{chat}")
          else
            chat = params[:payload][0].to_i
          end
        attribute = params[:payload][1].to_sym
        val = params[:payload][2]
        settable = %i[clientid partnerid client language type enabled]
        changes = attr_valide(val, attribute)
        if LOGLEVEL == 'info'
          SemanticLogger['chats'].info(attr_valide(chat, :chatid).to_s)
        end
        if (settable.include? attribute) && attr_valide(chat, :chatid) && changes
          Chat[chatid: chat].update(changes)
          if LOGLEVEL == 'info'
            SemanticLogger['chats'].info("#{chat} #{attribute} >> #{val}")
          end
        end
      end
    end
  end

  def self.give(params = {})
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      if Chat.count == 0
        data =  ['no chats']
      else
        data = Chat.where(enabled: params[:enabled]).all.map do |c|
                 "cl: #{c.clientid}, name: #{c.client}, pa: #{c.partnerid}, #{c.language}, #{c.type}, #{c.chatid}"
      end
    end
      BotHelper.send_message(chat_id: params[:chatid],
                             text: "Бот подключен в следующих чатах:\n#{data.join("\n")}")
    end
  end

  def self.drop
    DB.drop_table :chats
    SemanticLogger['chats'].info('table dropped') if LOGLEVEL == 'info'
  end

  def self.create
    DB.create_table :chats do
      Bigint :chatid, primary_key: true
      String :clientid, null: true
      String :partnerid, null: true
      String :client, null: true
      Integer :created, null: false #
      String :language, null: false, default: 'ru'
      String :type, null: false, default: 'client_chat'
      TrueClass :enabled, null: false, default: true #
    end
    SemanticLogger['chats'].info('table created') if LOGLEVEL == 'info'
  end

  def self.backup
    result = Chat.all.map do |ch|
      {chatid: ch.chatid,
       client: ch.client,
       type: ch.type,
       created: ch.created,
       clientid: ch.clientid,
       partnerid: ch.partnerid,
       language: ch.language,
       enabled: ch.created}
    end
    SemanticLogger['chats'].info('backup done') if LOGLEVEL == 'info'
    result
  end

  def self.seed(saved_data)
    saved_data.each {|c| Chat[chatid: c[:chatid]].nil? ? Chat.create(c) : nil} unless saved_data.nil?
    if LOGLEVEL == 'info'
      SemanticLogger['chats'].info('table filled by backuped data')
    end
  end

  def self.reroll(params = {})
    # сохраняется только недельный бекап статистики
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      saved_tickets = Tickets.backup
      Tickets.drop
      saved_stat = Statistics.backup
      Statistics.drop
      saved_data = backup
      drop
      create
      Seed.chats
      seed(saved_data)
      Statistics.create
      Statistics.seed(saved_stat)
      Tickets.create
      Tickets.seed(saved_tickets)
    end
  end
end
