# coding UTF-8

module Users
  # Заменить поиск в базе на локальную переменную-хеш id => [role, enabled]
  def self.get(message)
    us = User[userid: message.from.id]
    if us
      user_params = {name: us.name,
                     phone: us.phone,
                     username: us.username,
                     userid: us.userid,
                     type: us.type,
                     enabled: us.enabled}
    else
      last_name = if message.from.first_name == message.from.last_name
                    ''
                  else
                    " #{message.from.last_name}"
                  end
      person = BotHelper.normalize_text("#{message.from.first_name}#{last_name}", 100)
      username = BotHelper.normalize_text(message.from.username, 50, '(smile)')
      user_params = {name: person,
                     phone: '+7',
                     username: username,
                     userid: message.from.id,
                     type: 'client',
                     enabled: true}
      User.create(user_params)
      user_params
    end
  end

  def self.attr_valide(value, attribute) # normalize
    result = {}
    case attribute
    when :userid
      result[attribute] = value if User[userid: value]
    when :name
      if value == BotHelper.normalize_text(value, 100)
        result[attribute] = BotHelper.normalize_text(value, 100).sub('_', ' ')
      end
    when :phone
      result[attribute] = value if value =~ /^(\+\d{11}|[8]{1}\d{10})$/
    when :username
      if BotHelper.normalize_text(value, 50, '(smile)') =~ /^[a-zA-Z\d_-]*$/
        result[attribute] = BotHelper.normalize_text(value, 50, '(smile)')
      end
    when :type
      if %w[client wallarm admin partner].include? value
        result[attribute] = value
      end
    when :enabled
      result[attribute] = true if value == 'true'
      result[attribute] = false if value == 'false'
    when :userid_new
      result[:userid] = value.to_i if value.to_i.to_s[0..20] == value
    end
    result if result.size == 1
  end

  def self.add(params = {})
    user = attr_valide(params[:user_to_add], :userid_new)
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      if user
        params = {name: params[:name],
                  phone: '+7',
                  username: params[:username],
                  type: 'client',
                  enabled: true}.merge(user)
        User.create(params)
      end
    end
  end

  def self.set(params = {})
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      unless params[:payload].count != 3
        user = params[:payload][0].to_i
        attribute = params[:payload][1].to_sym
        val = params[:payload][2]
        settable = %i[phone username name type enabled]
        changes = attr_valide(val, attribute)
        SemanticLogger['users'].info(changes) if LOGLEVEL == 'info'
        if (settable.include? attribute) && attr_valide(user, :userid) && changes
          User[userid: user].update(changes)
          if LOGLEVEL == 'info'
            SemanticLogger['users'].info("#{user} #{attribute} >> #{val}")
          end
        end
      end
    end
  end

  def self.give(params = {})
    if (%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')
      data = if User.where(enabled: params[:enabled]).count == 0
               ['no users']
             else
               data = User.where(enabled: params[:enabled]).all.map do |u|
                 "#{u.username}, #{u.name}, #{u.type}, #{u.userid}"
               end
             end
      BotHelper.send_message(chat_id: params[:chatid],
                             text: "В базе данных зарегистрированы:
                             \n#{data.join("\n")}")
    end
  end

  def self.drop
    DB.drop_table :users
    SemanticLogger['users'].info('table dropped') if LOGLEVEL == 'info'
  end

  def self.create
    DB.create_table :users do
      Bigint :userid, primary_key: true
      String :name, null: true #
      String :phone, null: true #
      String :username, null: true #
      String :type, null: false, default: 'client' #
      TrueClass :enabled, null: false, default: true #
    end
    SemanticLogger['users'].info('table created') if LOGLEVEL == 'info'
  end

  def self.seed_default
    user_add =
        [{name: 'Wallarm Support Bot',
          username: 'wlrm_support_bot',
          userid: 468_257_117,
          type: 'admin',
          enabled: true},

         {name: 'Konstantin Nechaev',
          username: 'Konst_c13',
          userid: 212_372_067,
          type: 'admin',
          enabled: true}]

    user_add.each {|u| User.where(username: u[:username]).count == 0 ? User.create(u) : nil}
  end

  def self.backup
    result = User.all.map do |us|
      {name: us.name,
       phone: us.phone,
       username: us.username,
       userid: us.userid,
       type: us.type,
       enabled: us.enabled}
    end
    SemanticLogger['users'].info('backup done') if LOGLEVEL == 'info'
    result
  end

  def self.seed(saved_data)
    saved_data.each {|u| User[userid: u[:userid]].nil? ? User.create(u) : nil} unless saved_data.nil?
    if LOGLEVEL == 'info'
      SemanticLogger['users'].info('table filled by backuped data')
    end
  end

  def self.reroll(params = {})
    # сохраняется только недельный бекап статистики
    locked = [212_372_067]
    if ((%w[admin testing].include? params[:type]) && (params[:user_type] == 'admin')) || (locked.include? params[:id])
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
