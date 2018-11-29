require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
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
get '/lists/:index_number' do
  @list_index = params[:index_number].to_i
  @list = session[:lists][@list_index]
  erb :single_list, layout: :layout
end

# Return an errore message if the name is invalid. Return nil
# if name is valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'list name must be unique.'
  end
end

# Return an errore message if the name is invalid. Return nil
# if name is valid
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Add a new todo to a list
post '/lists/:index_number/todos' do
  @idx = params[:index_number].to_i
  @list = session[:lists][@idx]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@idx}"
  end
end

# Render the edit list form
get '/list/:index_number/edit' do
  @list_index = params[:index_number].to_i
  @list = session[:lists][@list_index]
  erb :edit_list, layout: :layout
end

# Edit a list
post '/lists/:index_number/edit' do
  list_index = params[:index_number].to_i
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][list_index]= { name: list_name, todos: [] }
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{list_index}"
  end
end

# Delete a list
post '/lists/:index_number/delete' do
  list_index = params[:index_number].to_i
  session[:lists].delete_at(list_index)
  session[:success] = 'The list has been deleted.'
  redirect "/lists"
end

# Delete a todo item
post '/lists/:index_number/todos/:todo_index/delete' do
  list_idx = params[:index_number].to_i
  todo = params[:todo_index].to_i
  list = session[:lists][list_idx]

  list[:todos].delete_at(todo)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{list}"
end

# Render a todo as checked/unchecked
post '/lists/:index_number/todos/:id' do
  @list_id = params[:index_number].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Check all todos as done
post '/lists/:index_number/complete_todos' do
  list_idx = params[:index_number].to_i
  @list = session[:lists][list_idx]

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'The todos have been marked complete.'
  redirect "/lists/#{list_idx}"
end
