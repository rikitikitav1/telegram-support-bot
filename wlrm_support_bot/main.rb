# coding UTF-8


root = Dir.getwd.to_s
require 'telegram/bot'
require 'sequel'
require 'rest-client'
require 'semantic_logger'
require 'webrick'
require './env.rb'

Dir['./initializers/*.rb'].each { |f| require f }
Dir['./lib/*.rb'].each { |f| require f }



  logger = SemanticLogger['wlrm_support_bot']

  class StatisticRecord < Sequel::Model(DB[:statistics]); end
  class User < Sequel::Model(DB[:users])
    unrestrict_primary_key
  end
  class Chat < Sequel::Model(DB[:chats])
    unrestrict_primary_key
  end
  class Ticket < Sequel::Model(DB[:tickets])
    unrestrict_primary_key
  end

  Chats.seed_default
  Users.seed_default

probes = Thread.new do
        server = WEBrick::HTTPServer.new(
          Port: 8080,
          Logger: WEBrick::Log.new('/dev/null'),
          AccessLog: []
        )

        server.mount_proc '/liveness' do |_req, res|
          res.body = 'pong'
        end

        server.mount_proc '/readiness' do |_req, res|
          begin
            
            res.body = 'pong'
          rescue StandardError => ex
            logger.error(
              payload: { msg: 'Readiness probe failed' },
              exception: ex
            )
            res.status = 503
            res.body = 'Service Unavailable'
          end
        end

        server.start
      end
  Telegram::Bot::Client.run(TOKEN) do |bot|
    begin
      bot.listen do |message|
        chatid = message.chat.id
        username = message.from.username
        clientid = message.chat.title.scan(/\d+/)[0].to_i
        client = message.chat.title.sub(/wallarm/i, '').gsub(/[\d|\|]/, '')
        chat_params = Chats.get(message)  
        user_type = Users.get(message)[:type]
        if chat_params
          clientid = chat_params[:clientid]
          clientname = chat_params[:client]
          language = chat_params[:language]
          case message.text
          when '/start', '/start@wlrm_support_bot'
            BotHelper.send_message(chat_id: chatid, text: MULTILANG['/start'][language], input: username)
            logger.info("start launched at the #{chatid} by #{username}")

          when '/help', '/help@wlrm_support_bot'
            BotHelper.send_message(chat_id: chatid, text: MULTILANG['/help'][language])
            logger.info("help launched at the #{chatid} by #{username}")
          when '/language ru', '/language en'
            langcode = message.text.sub('/language ', '')
            if Chat[chatid: chatid]
              Chat[chatid: chatid].update(language: langcode)
            else 
              chat_params[:language] = langcode
              Chat.create(chat_params)
            end
            BotHelper.send_message(chat_id: chatid, text: MULTILANG['/language'][langcode])
            logger.info("language switched to #{langcode} at #{chatid} by #{username}")
          when /^\/report\s{1}\d{1,2}\.\d{2}\.\d{4}$/
              date = message.text.scan(/\d{1,2}\.\d{2}.\d{4}/)[0]
              if date
                logger.info("#{date}")
                start = Time.parse(date).to_i 
                params = chat_params.merge({user_type: user_type, start: start, date: date})
                Statistics.give(params)
              else
                logger.info("#{date}")
                logger.info("Некорректный формат даты")
                BotHelper.send_message(chat_id: chatid, text: "Дату задавайте в формате (dd.mm.yyyy)")
              end
          when /^\/give_(users|chats|tickets)$/
            target = message.text[6..-2].to_sym
            params = chat_params.merge({user_type: user_type, enabled: true, resolved: false})
            case target
            when :chat then Chats.give(params)
            when :user then Users.give(params)
            when :ticket then Tickets.give(params)
            end
          when /^\/give_(users|chats|tickets)_(disabled|resolved)$/
            target = message.text[6..-11].to_sym
            params = chat_params.merge({user_type: user_type, enabled: false, resolved: true})
            case target
            when :chat then Chats.give(params)
            when :user then Users.give(params)
            when :ticket then Tickets.give(params)
            end
          when /^\/set_(chat|user|ticket)\s/
            target = message.text.scan(/chat|user|ticket/)[0].to_sym
            payload = message.text.sub("/set_#{target} ", '').split(" ")
            params = chat_params.merge({user_type: user_type, payload: payload})
            case target
            when :chat then Chats.set(params)
            when :user then Users.set(params)
            when :ticket then Tickets.set(params)
            end
          when /^\/delete_(user|chat)\s{1}\d+$/
            target = message.scan(/chat|user/)[0].to_sym
            payload = [message.text.scan(/\d+/)[0].to_i, :enabled, 'false']
            params = chat_params.merge({user_type: user_type, payload: payload})
            case target
            when :chat then Chats.set(params)
            when :user then Users.set(params)
            end
          when /^\/close_ticket\s{1}\w+\-\d+$/
            payload = [message.text.scan(/\w+\-\d+/)[0].to_s, :status, 'closed']
            params = chat_params.merge({user_type: user_type, payload: payload})
            Tickets.set(params)
            #проверить
          when /^\/(add_chat|chat_add)\s{1}\d+$/
            str = message.text.scan(/\d+/)[0].to_i
            params = chat_params.merge({user_type: user_type, chat_to_add: str})
            Chats.add(params)
          when /^\/(add_ticket|ticket_add)\s*(\w+.?\d+)+$/
            ticket_new = message.text.sub(/^\/(add_ticket|ticket_add)\s*/, '')
            params = chat_params.merge({user_type: user_type, jira: ticket_new})
            Tickets.admin_add(params)
          when /^\/(chat|user|stat|ticket)_table_reroll$/
            target = message.text.scan(/\/[a-z]+/)[0][1..-1].to_sym
            params = chat_params.merge({id: message.from.id, user_type: user_type})
            case target
            when :chat then Chats.reroll(params)
            when :user then Users.reroll(params)
            when :stat then Statistics.reroll(params)
            when :ticket then Tickets.reroll(params)
            end
          when /^\/my_tickets$/
            Tickets.give_client(chat_params)
          when '/give_env'
            params = chat_params.merge({id: message.from.id})
            BotHelper.env(params)
          when /^\/(clean_chat|chat_clean)(\s{1}\d+|)$/
            if ['wallarm', 'admin'].include? user_type
              chatid = chat_params[:chatid]
              chatid = message.text.scan(/\d+/)[0].to_i unless message.text.scan(/\d+/).empty?
              messages = StatisticRecord.where(chatid: chatid, username:"wlrm_support_bot",
                 deleted: false).all.select{|sr| sr.time > (Time.now.to_i - (3600 * 24))}.map(&:message_id)
              unless messages.empty?
                messages.each do |m|
                  bot.api.deleteMessage(chat_id: chatid, message_id: m)
                  StatisticRecord[message_id: m].update(deleted: true)
                end
                logger.info("#{chatid} cleaned") 
              end
            end
            #прикрутить аргумент или новую фичу, чтобы выбирать тип чатов, а так же язык, запилить хелп
          when /^\/say_to_(wallarm|admin|en|ru) /
            target = message.text.scan(/say_to_(wallarm|admin|en|ru)/).flatten[0]
            if ['wallarm', 'admin'].include? user_type
              txt = bot.api.getUpdates(allowed_updates: 
                "message")['result'][0]['message']['text'].gsub(/^\/say_to_(wallarm|admin|en|ru)/,'')
              chats = case target
              when 'wallarm' then Chat.where(type: 'internal').all.map(&:chatid)
              when 'admin' then Chat.where(type: target).all.map(&:chatid)
              when 'en' then Chat.where(type: "client_chat", language: target).all.map(&:chatid)
              when 'ru' then Chat.where(type: "client_chat", language: target).all.map(&:chatid)
              end
              logger.info("Someone asked for mass sending at #{chatid}")
              if (["internal", "admin", "testing"].include? chat_params[:type]) && chats  &&
                chats.each{|id| BotHelper.send_message(chat_id: id, text: txt)} 
              end
            end
          when /^\/fas\shttp.*/
            unless message.text.sub('/fas ', '').empty?
              url = message.text.sub('/fas ', '')
              BotHelper.send_attacks(chat_id: chatid, url: url)
            else
              BotHelper.send_message(chat_id: chatid, 
                                      text: 'Wrong parameters, use something like /fas https://google.com')
            end
          else
            ticket_new = message.text.scan(/(\#ticket|\#тикет)\s*(\w+.?\d+)+/).flatten[1] unless message.text.nil?
            text = BotHelper.normalize_text(message.text, 200, '(smile)')
            stat_params = { time: message.date,
                            clientid: clientid,
                            chatid: chat_params[:chatid],
                            username: username, 
                            message_text: text,
                            message_id: message.message_id,
                            userid: message.from.id }
            sr = StatisticRecord.create(stat_params)
            ticket_params = stat_params.merge({jira: ticket_new, statid: sr.id})
            Tickets.add(ticket_params)
          end
        end
      end
    rescue => e
      logger.error("#{e.inspect} #{e.backtrace}")
      puts "#{e.inspect} #{e.backtrace}"
      retry
    end
  end
# end


