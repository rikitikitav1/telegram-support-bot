# coding UTF-8

module Tickets
  def self.add(params = {})
    unless params[:jira].nil?
      ticket_params = { created: params[:time],
                        jira: params[:jira],
                        clientid: params[:clientid],
                        statid: params[:statid],
                        userid: params[:userid],
                        partnerid: params[:partnerid],
                        chatid: params[:chatid] }
      Ticket.create(ticket_params)
      if LOGLEVEL == 'info'
        SemanticLogger['tickets'].info("#{params[:jira]} created
                                         in #{params[:chatid]}")
      end
    end
  end

  def self.admin_add(params = {})
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      BotHelper.send_message(chat_id: params[:chatid], jira: params[:jira],
                             text: "\n#{params[:jira]} успешно занесен в базу")
      if LOGLEVEL == 'info'
        SemanticLogger['tickets'].info("#{params[:jira]} created
                                         in #{params[:chatid]}")
      end
    end
 end

  def self.attr_valide(value, attribute)
    result = {}
    case attribute
    when :jira then result[attribute] = value if Ticket[jira: value]
    when :clientid
      if value.split(',').map(&:to_i)[0].is_a?(Integer) && (value.size < 200)
        result[attribute] = BotHelper.normalize_text(value, 200)
      end
    when :partnerid
      result[attribute] = value.to_i if value.to_i.to_s == value
    when :status
      if %w[open wait_for_development wait_for_customer closed wait_for_admin].include? value
        result[attribute] = value
        result[:resolved] = value == 'closed'
      end
    end
    result if [1, 2].include? result.size
  end

  def self.set(params = {})
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      unless params[:payload].count != 3
        jira = params[:payload][0].to_s
        attribute = params[:payload][1].to_sym
        val = params[:payload][2]
        settable = %i[status jira clientid partnerid resolved]
        changes = attr_valide(val, attribute)
        SemanticLogger['tickets'].info(changes) if LOGLEVEL == 'info'
        if (settable.include? attribute) && changes && attr_valide(jira, :jira)
          Ticket[jira: jira].update(changes)
          ti = Ticket[jira: jira]
          BotHelper.send_message(chat_id: ti.chatid,
                                 text: "Ticket #{ti.jira} #{attribute} >> #{val}")
        end
      end
    end
  end

  def self.give(params = {})
    if (%w[admin testing internal].include? params[:type]) && (%w[wallarm admin].include? params[:user_type])
      data = if Ticket.where(resolved: params[:resolved]).count == 0
               ['no tickets']
             else
               data = Ticket.where(resolved: params[:resolved]).all
               data = data.map { |t| "Ticket: #{t.jira}, #{t.status}, cl: #{t.clientid}, pa: #{t.partnerid} в работе: #{BotHelper.normalize_time(Time.now.to_i - t.created)}" }
        end
      BotHelper.send_message(chat_id: params[:chatid],
                             text: "Данные по тикетам:\n#{data.join("\n")}")
    end
  end

  def self.give_client(params = {})
    multilang = {
      'ru' => { 1 => 'в работе: ',
                2 => 'Данные по тикетам' },
      'en' => { 1 => 'processing: ',
                2 => 'Tickets report' }
    }
    lang = params[:language]
    if Ticket.where(clientid: params[:clientid]).count == 0
      data = ['no tickets']
    else
      data = Ticket.where(clientid: params[:clientid]).all.map do |t|
        ['Ticket: ' + t.jira,
         t.status,
         !t.resolved ? (multilang[lang][1] + BotHelper.normalize_time((Time.now.to_i - t.created), lang)) : nil].join(', ')
      end
    end
    BotHelper.send_message(chat_id: params[:chatid],
                           text: "#{multilang[lang][2]}:\n#{data.join("\n")}")
  end

  def self.give_partner(params = {})
    if (%w[admin testing internal partner].include? params[:type]) && (%w[wallarm admin partner].include? params[:user_type])
      multilang = {
        'ru' => { 1 => 'в работе: ',
                  2 => "Данные по тикетам партнера #{params[:partnerid]}" },
        'en' => { 1 => 'processing: ',
                  2 => "Tickets report for partner #{params[:partnerid]}" }
      }
      lang = params[:language]
      if Ticket.where(partnerid: params[:partnerid].to_i).count == 0
        data = ['no tickets']
      else
        data = Ticket.where(partnerid: params[:partnerid].to_i).all.map do |t|
          ['Ticket: ' + t.jira, t.clientid,
           t.status,
           !t.resolved ? (multilang[lang][1] + BotHelper.normalize_time((Time.now.to_i - t.created), lang)) : nil].join(', ')
        end
      end
      BotHelper.send_message(chat_id: params[:chatid],
                             text: "#{multilang[lang][2]}:\n#{data.join("\n")}")
    end
  end

  def self.drop
    DB.drop_table :tickets
    SemanticLogger['tickets'].info('table dropped') if LOGLEVEL == 'info'
  end

  def self.create
    DB.create_table :tickets do
      String :jira, size: 10, primary_key: true
      String :clientid, null: true
      Integer :created, null: false #
      String :status, null: false, default: 'open' #
      TrueClass :resolved, null: false, default: false #
      Bigint :userid, null: false
      Bigint :chatid, null: false
      Integer :partnerid, null: false, default: 1
      foreign_key [:chatid], :chats, key: :chatid, unique: false
      foreign_key [:userid], :users, key: :userid, unique: false
      foreign_key :statid, :statistics, key: :id, unique: true
    end
    SemanticLogger['tickets'].info('table created') if LOGLEVEL == 'info'
  end

  def self.backup
    time_start = Time.now.to_i - 3600 * 24 * 7
    result = Ticket.where(time: time_start..Time.now.to_i).all.map do |t|
      { created: t.created,
        jira: t.jira,
        clientid: t.clientid,
        status: t.status,
        resolved: t.resolved,
        statid: t.statid,
        userid: t.userid,
        chatid: t.chatid }
    end
    SemanticLogger['tickets'].info('backup done') if LOGLEVEL == 'info'
    result
  end

  def self.seed(saved_data)
    saved_data.each { |t| Ticket.create(t) } unless saved_data.nil?
    if LOGLEVEL == 'info'
      SemanticLogger['tickets'].info('table filled by backuped data')
    end 
  end

  def self.reroll(params = {})
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      saved_data = backup
      drop
      create
      seed(saved_data)
    end
  end
end
