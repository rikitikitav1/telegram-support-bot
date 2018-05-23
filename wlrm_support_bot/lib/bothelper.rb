# coding UTF-8


module BotHelper

  def self.send_message(params = {})
    #params = { chat_id: 0, text: 'text', input: nil }.merge(params)
    jira = params[:jira]
    begin
      mes = Telegram::Bot::Client.run(TOKEN) do |bot|
        text = if params[:input]
          params[:text].sub('inputable_val', params[:input])
        else
          params[:text].sub('inputable_val', '') unless params[:text].is_a?(Hash)    
        end
        bot.api.send_message(chat_id: params[:chat_id], text: text)
      end 
      text = if mes['result']['text']
         mes['result']['text'].gsub(/\n/, ' ')[0..25].gsub(/[\u{10000}-\u{FFFFF}]/,'(smile)') 
      else
        ""
      end
      params = {chatid: params[:chat_id],
                clientid: params[:clientid],
                username: mes['result']['from']['username'],
                message_id: mes['result']['message_id'], 
                time: mes['result']['date'],
                message_text: text,
                userid: mes['result']['from']['id']}
      sr = StatisticRecord.create(params)
      Tickets.add(params.merge({jira: jira, statid: sr.id})) if jira
    rescue => e
      SemanticLogger['bothelper'].info("something happened 
      when I was truying to send a message
      to the chat #{params[:chat_id]}")  
    end
  end
  
  def self.normalize_text(text, size, replace = '')
    unless text.nil? #в модуль и на проверку
      text[0..(size-1)].gsub(/[\u{10000}-\u{FFFFF}]/, replace) 
    else
      text = ""
    end
  end

  def self.normalize_time(secs = 1, lang = "ru")
    secs = secs[0] if secs.is_a?(Array)
    secs = secs.to_i unless secs.is_a?(Integer)
    time = secs.round
    multilang = {
      "ru" => { min: "минут",
                day: "днeй",
                hrs: "часов"},
      "en" => { min: "min",
                day: "days",
                hrs: "hours"}}
    unless time == 0   
      sec = time % 60
      time /= 60
      mins = time % 60
      time /= 60
      hrs = time % 24
      time /= 24                  
      days = time
      str = ""
      str += "#{days} #{multilang[lang][:day]}, " if days > 0 
      str += "#{hrs} #{multilang[lang][:hrs]}, " if hrs > 0 
      str += "#{mins} #{multilang[lang][:min]}."
    else
      str = "0"
    end
  end


  def self.env(params = {})
    locked = [212372067]
    if locked.include? params[:id]
      env_params = {host: ENV.fetch('DBADDR'),
                    database: ENV.fetch('DBNAME'),
                    user: ENV.fetch('DBUSER'), 
                    password: ENV.fetch('DBPASS')}
    bot.api.send_message(chat_id: chatid, text: "env_params: #{env_params}")
    end

  end


  def self.send_attacks(params = {})
    params = { chat_id: 0, url: 'https://google.ru' }.merge(params)
    result_array = []
    begin
      my_ip = RestClient::Request.execute(method: :get, url: 'http://ifconfig.co/ip').body
    rescue RestClient::ExceptionWithResponse => e
      puts 'my_ip broken http://ifconfig.co/ip'
      my_ip = 'Broken'
    end
    send_request = proc do |http_method, url|
      begin
        response = RestClient::Request.execute(method: http_method, url: url).code
      rescue RestClient::ExceptionWithResponse => e
        response = e.response.code
      rescue RestClient::ServerBrokeConnection => e
        response = 'Server Broke Connection'
      rescue RestClient::SSLCertificateNotVerified => e
        response = 'SSL Certificate Not Verified'
      rescue
        response = 'Error'
      end
      result_array.push(response)
    end
    url = if params[:url][-1] == '/'
            params[:url]
          else
            params[:url] + '/'
          end
    #Idea - vectors DB
    send_request.call(:get, url + '/?<script>alert(123)</script>', 
                      headers: { 'User-Agent' => 'wrm_support_bot' })
    send_request.call(:post, url + '/?<script>alert(123)</script>', 
                      headers: { 'User-Agent' => 'wrm_support_bot' })
    send_request.call(:get, url, 
                      headers: { 'User-Agent' => 'wrm_support_bot',
                      'test' => '<script>alert(123)</script>' })
    result = result_array.count.to_s + " attacks from:\n" + my_ip + result_array.uniq.map { |rk| rk.to_s + ' - ' + result_array.select { |r| r == rk }.count.to_s }.join("\n")
    send_message(chat_id: params[:chat_id], text: result)

  end
end
