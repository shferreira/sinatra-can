require 'spec_helper'

describe 'sinatra-can' do
  include Rack::Test::Methods

  class MyApp < Sinatra::Application
  end

  def app
    MyApp
  end

  DataMapper.setup(:default, 'sqlite::memory:')

  class Article
    include DataMapper::Resource

    property :id, Serial
    property :title, String
  end

  DataMapper.auto_migrate!
  DataMapper.finalize

  before :all do
    class User
      def initialize(name = "guest")
        @name = name
      end

      def name
        @name
      end

      def is_admin?
        @name == "admin"
      end
    end

    app.ability do |user|
      can :edit, :all if user.is_admin?
      can :read, :all
      can :read, Article
      cannot :create, Article
    end

    app.set :dump_errors, true
    app.set :raise_errors, true
    app.set :show_exceptions, false
  end

  it "should allow management to the admin user" do
    app.user { User.new('admin') }
    app.get('/1') { can?(:edit, :all).to_s }
    get '/1'
    last_response.body.should == 'true'
  end

  it "shouldn't allow management to the guest" do
    app.user { User.new('guest') }
    app.get('/2') { cannot?(:edit, :all).to_s }
    get '/2'
    last_response.body.should == 'true'
  end

  it "should act naturally when authorized" do
    app.user { User.new('admin') }
    app.get('/3') { authorize!(:edit, :all); 'okay' }
    get '/3'
    last_response.body.should == 'okay'
  end

  it "should raise errors when not authorized" do
    app.user { User.new('guest') }
    app.get('/4') { authorize!(:edit, :all); 'okay' }
    get '/4'
    last_response.status.should == 403
  end

  it "shouldn't allow a rule if it's not declared" do
    app.user { User.new('admin') }
    app.get('/6') { can?(:destroy, :all).to_s }
    get '/6'
    last_response.body.should == "false"
  end

  it "should throw 403 errors upon failed conditions" do
    app.user { User.new('admin') }
    app.get('/7', :can => [ :create, User ]) { 'ok' }
    get '/7'
    last_response.status.should == 403
  end

  it "should accept conditions" do
    app.user { User.new('admin') }
    app.get('/8', :can => [ :edit, :all ]) { 'ok' }
    get '/8'
    last_response.status.should == 200
  end

  it "should accept not_auth and redirect when not authorized" do
    app.user { User.new('guest') }
    app.get('/login') { 'login here' }
    app.get('/9') { authorize! :manage, :all, :not_auth => '/login'  }
    get '/9'
    follow_redirect!
    last_response.body.should == 'login here'
  end

  it "should autoload and autorize the model" do
    article = Article.create(:title => 'test1')

    app.user { User.new('admin') }
    app.get('/10/:id') { load_and_authorize!(Article); @article.title }
    get '/10/' + article.id.to_s
    last_response.body.should == article.title
  end

  it "should shouldn't allow creation of the model" do
    article = Article.create(:title => 'test2')

    app.user { User.new('admin') }
    app.post('/11', :model => [ Article ]) { }
    post '/11'
    last_response.status.should == 403
  end

  it "should autoload and autorize the model when using the condition" do
    article = Article.create(:title => 'test3')

    app.user { User.new('admin') }
    app.get('/12/:id', :model => [ Article ]) { @article.title }
    get '/12/' + article.id.to_s
    last_response.body.should == article.title
  end

  it "should autoload when using the before do...end block" do
    article = Article.create(:title => 'test4')

    app.user { User.new('admin') }
    app.before('/13/:id', :model => [ Article ]) { }
    app.get('/13/:id') { @article.title }
    get '/13/' + (article.id).to_s
    last_response.body.should == article.title
  end

  it "should return a 404 when the autoload fails" do
    dummy = Article.create(:title => 'test4')

    app.user { User.new('admin') }
    app.get('/14x/:id', :model => [ Article ]) { @article.title }
    get '/14x/999'
    last_response.status.should == 404
  end
end
