#!/usr/bin/env ruby
 
require 'twitter_ebooks'
include Ebooks
 
CONSUMER_KEY = ""
CONSUMER_SECRET = ""
OATH_TOKEN = "" # oauth token for ebooks account
OAUTH_TOKEN_SECRET = "" # oauth secret for ebooks account

ROBOT_ID = "book" # Avoid infinite reply chains
TWITTER_USERNAME = "RealGamer9001" # Ebooks account username
TEXT_MODEL_NAME = "GamerGate" # This should be the name of the text model
 
DELAY = 2..30 # Simulated human reply delay range in seconds
BLACKLIST = ['insomnius', 'upulie'] # Grumpy users to avoid interaction with
SPECIAL_WORDS = ['ebooks', 'clone', 'singularity', 'world domination']
TRIGGER_WORDS = ['cunt', 'bot', 'bitch', 'zoe', 'anita', 'tranny', 'shemale', 'faggot', 'fag']
 
# Track who we've randomly interacted with globally
$have_talked = {}
 
class GenBot
  def initialize(bot, modelname)
    @bot = bot
    @model = nil
    @mild = nil
    @medium = nil
    @hot = nil
    @sgg = nil
 
    bot.consumer_key = CONSUMER_KEY
    bot.consumer_secret = CONSUMER_SECRET
 
    bot.on_startup do
      @model = Model.load("model/#{modelname}.model")
      @mild = Model.load("model/mild.model")
      @medium = Model.load("model/medium.model")
      @hot = Model.load("model/hot.model")
      @sgg = Model.load("model/sgg.model")
      
      @top100 = @model.keywords.top(100).map(&:to_s).map(&:downcase)
      @top20 = @model.keywords.top(20).map(&:to_s).map(&:downcase)
    end
 
    bot.on_message do |dm|
      bot.delay DELAY do
        bot.reply dm, @model.make_response(dm[:text])
      end
    end
 
    bot.on_follow do |user|
      bot.delay DELAY do
        bot.follow user[:screen_name]
      end
    end
 
    bot.on_mention do |tweet, meta|
      # Avoid infinite reply chains (very small chance of crosstalk)
      next if tweet[:user][:screen_name].downcase.include?(ROBOT_ID) && rand > 0.05
      next if tweet[:user][:screen_name].downcase.include?('bot') && rand > 0.05
 
      tokens = NLP.tokenize(tweet[:text])
 
      very_interesting = tokens.find_all { |t| @top20.include?(t.downcase) }.length > 2
      special = tokens.find { |t| SPECIAL_WORDS.include?(t.downcase) }
      trigger = tokens.find { |t| TRIGGER_WORDS.include?(t.downcase) }
 
      if very_interesting || special
        favorite(tweet)
      elsif trigger
        block(tweet)
      end
      
#      if tweet[:text].include?('debug')
#        block(tweet)
#      end
      
      if rand > 0.95
        hotreply(tweet, meta)
        block(tweet) if rand < 0.5
      elsif rand < 0.35
        medreply(tweet, meta)
      else
        mildreply(tweet, meta)
      end
      
    end
 
    bot.on_timeline do |tweet, meta|
      next if tweet[:retweeted_status] || tweet[:text].start_with?('RT')
      next if BLACKLIST.include?(tweet[:user][:screen_name])
 
      tokens = NLP.tokenize(tweet[:text])
 
      # We calculate unprompted interaction probability by how well a
      # tweet matches our keywords
      interesting = tokens.find { |t| @top100.include?(t.downcase) }
      very_interesting = tokens.find_all { |t| @top20.include?(t.downcase) }.length > 2
      special = tokens.find { |t| SPECIAL_WORDS.include?(t.downcase) }
      trigger = tokens.find { |t| TRIGGER_WORDS.include?(t.downcase) }
 
      if special
        favorite(tweet)
        favd = true # Mark this tweet as favorited
 
        bot.delay DELAY do
          bot.follow tweet[:user][:screen_name]
        end
      end
 
      # Any given user will receive at most one random interaction per day
      # (barring special cases)
      next if $have_talked[tweet[:user][:screen_name]]
      $have_talked[tweet[:user][:screen_name]] = true
 
      if very_interesting || special
        favorite(tweet) if (rand < 0.5 && !favd) # Don't fav the tweet if we did earlier
        retweet(tweet) if rand < 0.1
        medreply(tweet, meta) if rand < 0.1
      elsif interesting
        favorite(tweet) if rand < 0.1
        mildreply(tweet, meta) if rand < 0.05
      elsif trigger
        block(tweet) if rand < 0.2
        hotreply(tweet, meta) if rand < 0.75
      end
    end
 
    # Schedule a tweet for every 15 minutes
    bot.scheduler.every '1800' do
      if rand < 0.1
        words = @model.make_statement
      elsif rand < 0.5
        words = "#StopGamerGate2014 " + @sgg.make_statement
      else
        words = @model.make_statement + " #Gamergate"
      end
 
      sing = Dir.entries("pictures/") - %w[.. . .DS_Store]
      pic = sing.shuffle.sample
      # We use 2 variables here simply so we can echo the image to log. #{pics.shuffle.sample} below would be valid for a 1 variable method.
     
      # this has a 15% chance of tweeting a picture from a specified folder, otherwise it will tweet normally.  
      if rand < 0.30
        bot.twitter.update_with_media("#{words}", File.new("pictures/#{pic}"))
        # A bit hacky of a method, calling up the twitter gem, but it works.
        bot.log "Tweeting @#{TWITTER_USERNAME}: #{words} #{pic}"    
      else
        bot.twitter.update("#{words}")
        # For consistancy, and because we already have a tweet stored, we use the twitter update method versus @bot.tweet
        bot.log "Tweeting @#{TWITTER_USERNAME}: #{words}"
      end
 
    end
   
    # Clears the have_talked variable daily at midnight.
    bot.scheduler.cron '0 0 * * *' do
      $have_talked = {}
      # This is just for fun and to make her post like a porn star at midnight (lewd).
      bot.tweet @model.make_statement
    end
  end
 
  def hotreply(tweet, meta)
    resp = @hot.make_response(meta[:mentionless], meta[:limit])
    @bot.delay DELAY do
      @bot.reply tweet, meta[:reply_prefix] + resp
    end
  end
  
  def medreply(tweet, meta)
    resp = @medium.make_response(meta[:mentionless], meta[:limit])
    @bot.delay DELAY do
      @bot.reply tweet, meta[:reply_prefix] + resp
    end
  end
  
  def mildreply(tweet, meta)
    resp = @mild.make_response(meta[:mentionless], meta[:limit])
    @bot.delay DELAY do
      @bot.reply tweet, meta[:reply_prefix] + resp
    end
  end
 
  def favorite(tweet)
    @bot.log "Favoriting @#{tweet[:user][:screen_name]}: #{tweet[:text]}"
    @bot.delay DELAY do
      @bot.twitter.favorite(tweet[:id])
    end
  end
 
  def retweet(tweet)
    @bot.log "Retweeting @#{tweet[:user][:screen_name]}: #{tweet[:text]}"
    @bot.delay DELAY do
      @bot.twitter.retweet(tweet[:id])
    end
  end
 
  def block(tweet)
    @bot.log "Blocking and reporting @#{tweet[:user][:screen_name]}"
    @bot.twitter.block(tweet[:user][:screen_name])
    @bot.twitter.report_spam(tweet[:user][:screen_name])
  end
end
 
def make_bot(bot, modelname)
  GenBot.new(bot, modelname)
end
 
Ebooks::Bot.new(TWITTER_USERNAME) do |bot|
  bot.oauth_token = OATH_TOKEN
  bot.oauth_token_secret = OAUTH_TOKEN_SECRET
 
  make_bot(bot, TEXT_MODEL_NAME)
end