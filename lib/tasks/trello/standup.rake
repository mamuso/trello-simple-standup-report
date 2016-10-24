require 'dotenv'
require 'trello'
require 'slack-notifier'

namespace :trello do
  desc 'Call for standup in all the channesl you have configured as output'
  task :callforstandup do
    if run?

      # Load the .env file if exists
      Dotenv.load

      # Posting to slack if it is configured
      if ENV['SLACK_WEBHOOK_URL']

        notifier = Slack::Notifier.new ENV['SLACK_WEBHOOK_URL']
        notifier.ping "Howdy <!channel>! Go to https://trello.com/b/#{ENV['TRELLO_STANDUP_BOARD_ID']} and update your tasks. I'll be picking them up very soon :robot_face:"

      end
    end
  end

  desc 'Extract Trello Cards and post it to one or many channels'
  task :standup do
    if run?

      # Load the .env file if exists
      Dotenv.load

      # Configure the Trello gem
      Trello.configure do |config|
        config.developer_public_key = ENV['TRELLO_DEVELOPER_PUBLIC_KEY']
        config.member_token = ENV['TRELLO_MEMBER_TOKEN']
      end

      # Let's get the standup board
      standupBoard =  Trello::Board.find(ENV['TRELLO_STANDUP_BOARD_ID'])

      #let's look for label ids
      labelYesterday  = nil
      labelToday      = nil
      labelBlocked    = nil

      standupBoard.labels.each do |label|
        labelYesterday  = label.id if label.name == "Yesterday"
        labelToday      = label.id if label.name == "Today"
        labelBlocked    = label.id if label.name == "Blockers"
      end

      # Let's iterate on the lists and compose some text
      message = ""

      standupBoard.lists.each do |list|
        unless list.closed? || list.cards.size == 0
          cards = list.cards
          message += "*#{list.name}*\n"

          # Find all the cards labeled as "Yesterday"
          yesterdayCards = cards.select {|card| card.card_labels.include? labelYesterday } unless labelYesterday.nil?

          if yesterdayCards.size > 0 
            message += "What did you do yesterday?\n"
            yesterdayCards.each do |card|
              message += "> #{card.name}\n"
            end
            message += "\n"
          end


          # Find all the cards labeled as "Today"
          todayCards = cards.select {|card| card.card_labels.include? labelToday } unless labelToday.nil?

          if todayCards.size > 0 
            message += "What are you doing today?\n"
            todayCards.each do |card|
              message += "> #{card.name} #{ card.comments.first ? ': '+card.comments.first.text : '' }\n"
            end
            message += "\n"
          end


          # Find all the cards labeled as "Blockers"
          blockersCards = cards.select {|card| card.card_labels.include? labelBlocked } unless labelBlocked.nil?

          if blockersCards.size > 0 
            message += "\nWhat is blocking you?\n"
            blockersCards.each do |card|
              message += "> #{card.name}\n"
            end
            message += "\n"
          end

          message += "\n"
        end

      end

      # We have the text! let's deliver the message
      
      # Posting to slack if it is configured
      if ENV['SLACK_WEBHOOK_URL']

        notifier = Slack::Notifier.new ENV['SLACK_WEBHOOK_URL']
        notifier.ping message

      end
    end
  end
end

# only run the task from Monday to Friday
def run?
  !Time.now.saturday? && !Time.now.sunday?
end