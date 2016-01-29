require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'tilt/erb'

def init_db
  @db = SQLite3::Database.new 'lepra.db'
  @db.results_as_hash = true
end

configure do
  enable :sessions
  init_db
  @db.execute 'CREATE TABLE IF NOT EXISTS posts (id INTEGER PRIMARY KEY AUTOINCREMENT, created_date DATE, content TEXT);'
  @db.execute 'CREATE TABLE IF NOT EXISTS comments (id INTEGER PRIMARY KEY AUTOINCREMENT, created_date DATE, comment TEXT, post_id INTEGER);'
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello stranger'
  end
end

before do
  init_db
end

before '/secure/*' do
  unless session[:identity]
    session[:previous_url] = request.path
    @error = 'Sorry, you need to be logged in to visit ' + request.path
    halt erb(:login_form)
  end
end

get '/' do
  @results = @db.execute 'select * from posts order by id desc'

  erb :index
end

get '/login/form' do
  erb :login_form
end

post '/login/attempt' do
  session[:identity] = params['username']
  where_user_came_from = session[:previous_url] || '/'
  redirect to where_user_came_from
end

get '/logout' do
  session.delete(:identity)
  erb "<div class='alert alert-message'>Logged out</div>"
end

get '/secure/place' do
  erb 'This is a secret place that only <%=session[:identity]%> has access to!'
end

get '/new' do
  erb :newpost
end

get '/post/:post_id' do
  post_id = params[:post_id]
  results = @db.execute 'select * from posts where id = ?', [post_id]
  @row = results[0]
  @results_comments = @db.execute 'select * from comments where post_id = ?', [post_id]

  erb :post
end

post '/new' do
  content = params[:content]

  if content.length <= 0
    @error = "Введите текст"
  else
    @message = "Новый пост создан!"
    @db.execute 'insert into posts (content, created_date) values (?, datetime())', [content]
  end

  erb :newpost
end

post '/post/:post_id' do
  post_id = params[:post_id]
  comment = params[:comment]
  results = @db.execute 'select * from posts where id = ?', [post_id]
  @row = results[0]
  @results_comments = @db.execute 'select * from comments where post_id = ?', [post_id]

  if comment.length <= 0
    @error = "Введите комментарий"
  else
    @message = "Комментарий добавлен!"
    @db.execute 'insert into comments (comment, created_date, post_id) values (?, datetime(), ?)', [comment, post_id]
    redirect to('/post/' + post_id)
  end

  erb :post
end