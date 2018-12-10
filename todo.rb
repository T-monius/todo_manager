require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure do
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && completed_todos(list) == todos_count(list)
  end

  def todos_count(list)
    list[:todos].count
  end

  def completed_todos(list)
    count = 0
    list[:todos].each { |todo| count += 1 if todo[:completed] }
    count
  end

  def class_for(list)
    "complete" if list_complete?(list)
  end

  def sort_lists_by_completion
    session[:lists].sort_by do |list|
      list_complete?(list) ? 1 : 0
    end
  end

  def sort_todos_in_a(list)
    list[:todos].sort_by { |todo| todo[:completed] ? 1 : 0 }
  end
end

def load_list(id)
  list = session[:lists].find { |list| list[:id] == id }
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

# View all of the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# View a single list
get '/lists/:id' do
  id = params[:id].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]

  if @list_id == nil
    session[:error] = 'The specified list was not found.'
    redirect '/'
  else
    erb :single_list, layout: :layout
  end
end

# Return an error message if the name is invalid. Return nil
# if name is valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'list name must be unique.'
  end
end

# Return an error message if the name is invalid. Return nil
# if name is valid
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end

def next_list_id(lists)
  max = lists.map { |list| list[:id]}.max || 0
  max + 1
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  lists = session[:lists]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id(lists)
    session[:lists] << {id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Add a new todo to a list
post '/lists/:id/todos' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Render the edit list form
get '/list/:id/edit' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Edit a list
post '/lists/:id/edit' do
  list_id = params[:id].to_i
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list = load_list(list_id)
    @list[:name]= list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{list_id}"
  end
end

# Delete a list
post '/lists/:id/delete' do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = 'The list has been deleted.'
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/"
  else
    redirect "/lists"
  end
end

# Delete a todo from a list
post "/lists/:id/todos/:todo_id/delete" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post "/lists/:id/todos/:todo_id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Check all todos as done
post '/lists/:id/complete_todos' do
  list_id = params[:id].to_i
  @list = load_list(list_id)
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'The todos have been marked complete.'
  redirect "/lists/#{list_id}"
end
