require 'twitter_ebooks'
require 'set'

# This is an example bot definition with event handlers commented out
# You can define and instantiate as many bots as you like
CONSUMER_KEY = ""
CONSUMER_SECRET = ""
OAUTH_TOKEN = ""
OAUTH_TOKEN_SECRET = ""

TWITTER_USERNAME = "RealGamer9001" # Ebooks account username

BLACKLIST = ['kylelehk', 'friedrichsays', 'Sudieofna', 'tnietzschequote', 'NerdsOnPeriod', 'FSR', 'BafflingQuotes', 'Obey_Nxme']
TRIGGER_WORDS = ['tranny', 'shemale', 'cunt', 'bitch', 'pussy', 'faggot', 'nigger']


DELAY = 15..45

# Information about a particular Twitter user we know
class UserInfo
  attr_reader :username
  # @return [Integer] how many times we can pester this user unprompted
  attr_accessor :pesters_left
  # @param username [String]
  def initialize(username)
    @username = username
    @pesters_left = 3
  end

end

class CloneBot < Ebooks::Bot
  attr_accessor :original, :model, :model_path
  def configure
    # Configuration for all CloneBots
    self.consumer_key = CONSUMER_KEY
    self.consumer_secret = CONSUMER_SECRET
    self.blacklist = ['kylelehk', 'friedrichsays', 'Sudieofna', 'tnietzschequote', 'NerdsOnPeriod', 'FSR', 'BafflingQuotes', 'Obey_Nxme']
    self.delay_range = DELAY
    @userinfo = {}
  end

  def top100; @top100 ||= model.keywords.take(100); end

  def top20; @top20 ||= model.keywords.take(20); end

  def on_startup
    # UNCOMMENT THESE TWO TO BUILD INITIAL def def CORPUS
    # Pira, eventually turn this into a 2nd function plx
    # make_corpus("recent","GamerGate",3500)
    # make_corpus("popular","GamerGate",150)
    
    load_model!

    @pics = (Dir.entries("pictures/") - %w[.. . .DS_Store]).sort()
    log @pics.take(5) # poll for consistency and tracking purposes.
    @status_count = twitter.user.statuses_count

    prune_following
    
    post_tweet
    
    # search("recent","GamerGate",2)

    posttime = rand(1800..3600)
    puts "#{posttime} between tweets"
    
    scheduler.every "#{posttime}" do
      # Each day at midnight, post a single tweet
      post_tweet
    end
    
    scheduler.every "3600" do
      randnum = rand(1..7)
      search("recent","GamerGate",randnum)
    end

  end

  def on_message(dm)
    delay do
      reply(dm, model.make_response(dm.text))
    end

  end

  def on_mention(tweet)
    # Become more inclined to pester a user when they talk to us
    userinfo(tweet.user.screen_name).pesters_left += 1
    delay do
      reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
    end

  end

  def on_timeline(tweet)
    return if tweet.retweeted_status?
    return unless can_pester?(tweet.user.screen_name)
    tokens = Ebooks::NLP.tokenize(tweet.text)
    interesting = tokens.find { |t| top100.include?(t.downcase) }
    very_interesting = tokens.find_all { |t| top20.include?(t.downcase) }.length > 2
    delay do
      if very_interesting
        favorite(tweet) if rand < 0.5
        retweet(tweet) if rand < 0.1
        if rand < 0.01
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
        end

      elsif interesting
        favorite(tweet) if rand < 0.05
        if rand < 0.001
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
        end

      end

    end

  end

  # Find information we've collected about a user
  # @param username [String]
  # @return [Ebooks::UserInfo]
  def userinfo(username)
    @userinfo[username] ||= UserInfo.new(username)
  end

  # Check if we're allowed to send unprompted tweets to a user
  # @param username [String]
  # @return [Boolean]
  def can_pester?(username)
    userinfo(username).pesters_left > 0
  end

  # Only follow our original user or people who are following our original user
  # @param user [Twitter::User]
  def can_follow?(username)
    @original.nil? || username == @original || twitter.friendship?(username, @original)
  end

  def favorite(tweet)
    if can_follow?(tweet.user.screen_name)
      super(tweet)
    else
      log "Unfollowing @#{tweet.user.screen_name}"
      twitter.unfollow(tweet.user.screen_name)
    end

  end

  def on_follow(user)
    if can_follow?(user.screen_name)
      follow(user.screen_name)
    else
      log "Not following @#{user.screen_name}"
    end

  end

  def all_uppercase?(str)
    str.gsub(/[A-Z]/, '').strip.empty?
  end
  
  def word_cleanup(tweet)
    words = tweet.text
    split_words = words.split(' ')
    split_words =
    split_words.each_with_index.map do |word, i|
      words = split_words.reject{|x| TRIGGER_WORDS.include?(x.downcase)}.join(' ')
      return words
    end
  end

  def prune_following
    # Method for pruning followers
    following = Set.new(twitter.friend_ids.to_a)
    followers = Set.new(twitter.follower_ids.to_a)
    to_unfollow = (following - followers).to_a
    log("Unfollowing user ids: #{to_unfollow}")
    twitter.unfollow(to_unfollow)
  end


  def next_index()
    seq = (0..(@pics.size - 1)).to_a
    seed = @status_count / @pics.size
    r = Random.new(seed)
    seq.shuffle!(random: r)
    res = seq[@status_count % @pics.size]
    @status_count = @status_count + 1
    return res
  end


  def make_corpus(type,keyword,size)
    twitter.search(keyword, result_type: type).take(size).each do |tweet|
      saved_tweets = File.open('corpus/RealGamer9001.txt', 'a')
      saved_tweets.puts word_cleanup(tweet) + "\n"
      saved_tweets.close
    end
    
    puts "Built corpus of #{size} #{type} tweets"

  end


  def search(type,keyword,size)
    twitter.search(keyword, result_type: type).take(size).each do |tweet|
      delay do
        reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
      end

    end

  end


  def post_tweet
    if rand < 0.25
      pic = @pics[next_index]
      pictweet(model.make_statement, "pictures/#{pic}")
    else
      tweet(model.make_statement)
    end

  end


  private
  def load_model!
    return if @model
    @model_path ||= "model/#{original}.model"
    log "Loading model #{model_path}"
    @model = Ebooks::Model.load(model_path)
  end

end

CloneBot.new(TWITTER_USERNAME) do |bot|
  bot.access_token = OAUTH_TOKEN
  bot.access_token_secret = OAUTH_TOKEN_SECRET
  bot.original = "RealGamer9001"
end
