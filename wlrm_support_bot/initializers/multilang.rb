# coding UTF-8
MULTILANG = {
      '/start' => {
        'ru' => "Привет inputable_val!
          Я бот поддержки Wallarm, 
          для получения справки по моим возможностям просто наберите /help",

        'en' => "Hi inputable_val!
              I am a Wallarm support bot, 
              for obtaining a manual please use  /help"
      },
      'help' => {
        'ru' => "Сегодня для клиентов доступно следующее:
          /start@wlrm_support_bot или /start - описание
          /language ru - переключение на русскую версию
          /language en - переключение на английскую версию
          /my_tickets - статус тикетов, связанных с этим клиентом",  

        'en' => "Today permitted options for the clients are:
              /start@wlrm_support_bot or /start - description
              /language ru - switching to the russian mode
              /language en - switching to the english mode
              /my_tickets - view info about thickes, linked to this client"
      },
      'help_partner' => {
        'ru' => "Команды для партнеров:
          /client_tickets - информация по всем активным тикетам клиентов партнера",  

        'en' => "Commands for partners:
          /client_tickets - view info about tickets linked to this partner clients"
      },
      'help_internal' => {
        'ru' => "Команды для сотрудников компании:
          /report DD.MM.YYYY - статистика за выбранный день по чатам
          /give_tickets - информация по всем активным тикетам
          /(clean_chat|chat_clean) - удаление сообщений бота из текущего чата
          /say_to_(wallarm|admin|en|ru) text - написать сообщение во внутренние|админские|англоязычные|русскоязычные чаты",  

        'en' => "Commands for internal usage:
              /report DD.MM.YYYY - dayly report
              /give_tickets - open tickets summary
              /(clean_chat|chat_clean) - cleaning the current chat from bot's messages
              /say_to_(wallarm|admin|en|ru) text - writing to each chat with the chosen chat type"
      },
      'help_admin' => {
        'ru' => "Команды для администраторов бота (поддержки):
          /give_(users|chats|tickets) - активные пользователи, чаты, тикеты
          /give_(users|chats)_disabled - отключенные пользователи, чаты
          /give_tickets_resolved - закрытые тикеты
          /set_(chat|user|ticket) - задание определенных параметров для чатов, пользователей, тикетов:
            Для пользователей, параметры: 
            [phone, username, name, type, enabled]
            пример: /set_user userid type admin
            Для чатов, параметры: 
            [clientid, partnerid, client, language, type, enabled]
            Для тикетов, параметры: 
            [status, clientid, resolved]
          /delete_(chat|user) id - отключение чатов, пользователей
          /close_ticket id - закрыть тикет        
          /language en - переключение на английскую версию
          /add_(chat|ticket) id или /(chat|ticket)_add id - добавить вручную новый чат, тикет",  

        'en' => "Нет уж, читайте русскую версию"
      },
      '/language' => {
        'ru' => 'Переключено на русский',

        'en' => 'Switched to english'
      }
    }







