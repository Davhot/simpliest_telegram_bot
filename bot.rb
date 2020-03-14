# frozen_string_literal: true

require 'telegram/bot'
require 'byebug'
require 'json'

token = ENV['TOKEN']

def time_greeting
  hour = Time.now.hour
  if hour >= 0 && hour < 12
    'Доброе утро'
  elsif hour >= 12 && hour < 16
    'Добрый день'
  elsif hour >= 16 && hour < 23
    'Добрый вечер'
  else
    'Доброй ночи'
  end
end

class GuessNumber
  attr_reader :mid

  def initialize(username, min: nil, max: nil, mid: nil)
    @filepath = "bot_dump/#{username}.json"
    if min && max
      @min = min
      @max = max
      calc_mid
      write_to_file
    else
      read_from_file
    end
  end

  def more
    refresh_data do
      @min = mid
      calc_mid
    end
  end

  def less
    refresh_data do
      @max = mid
      calc_mid
    end
  end

  def has_answer?
    @min >= @max - 1
  end

  private

  def write_to_file
    data = File.open(@filepath, 'w') { |f| f.print to_json }
  end

  def refresh_data
    read_from_file
    yield
    puts "#{to_json} #{@filepath}"
    write_to_file
  end

  def to_json(*_args)
    { min: @min, max: @max, mid: @mid }.to_json
  end

  def calc_mid
    @mid = (@min + @max) / 2
  end

  def read_from_file
    data = JSON.parse(File.read(@filepath))
    @min = data['min']
    @max = data['max']
    @mid = data['mid']
  end
end

class GuessBot
  attr_accessor :bot, :message, :guess_number
  def initialize(bot:, message:, guess_number:)
    @bot = bot
    @message = message
    @guess_number = guess_number
  end

  def ask
    if guess_number.has_answer?
      win
    else
      question = "Ваше число >, < или = #{guess_number.mid}?"
      answers = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w[> < =]], one_time_keyboard: true)
      bot.api.send_message(chat_id: message.chat.id, text: question, reply_markup: answers)
    end
  end

  def win
    bot.api.send_message(chat_id: message.chat.id, text: "Ваше число: #{guess_number.mid}")

    question = 'Заново?'
    answers = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w[/start /stop]], one_time_keyboard: true)
    bot.api.send_message(chat_id: message.chat.id, text: question, reply_markup: answers)
  end
end

Telegram::Bot::Client.run(token) do |bot|
  puts 'start bot'
  bot.listen do |message|
    case message.text
    when '/start'
      mes = "#{time_greeting}, #{message.from.first_name}\nЗагадай число от 1 до 100."
      bot.api.send_message(chat_id: message.chat.id, text: mes)

      guess_number = GuessNumber.new(message.from.username, min: 1, max: 100)

      question = "Ваше число >, < или = #{guess_number.mid}?"
      answers = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w[> < =]], one_time_keyboard: true)
      bot.api.send_message(chat_id: message.chat.id, text: question, reply_markup: answers)
    when '>'
      guess_number = GuessNumber.new(message.from.username)
      guess_number.more

      guess_bot = GuessBot.new(bot: bot, message: message, guess_number: guess_number)
      guess_bot.ask
    when '<'
      guess_number = GuessNumber.new(message.from.username)
      guess_number.less

      guess_bot = GuessBot.new(bot: bot, message: message, guess_number: guess_number)
      guess_bot.ask
    when '='
      guess_number = GuessNumber.new(message.from.username)
      guess_bot = GuessBot.new(bot: bot, message: message, guess_number: guess_number)
      guess_bot.win
    when '/stop'
      bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
    end
    sleep 1
  end
  puts 'end bot'
end
