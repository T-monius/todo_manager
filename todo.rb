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

def load_list(idx)
  list = session[:lists][idx] if idx && session[:lists][idx]
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
get '/lists/:index_number' do
  @list_idx = params[:index_number].to_i
  @list = session[:lists].fetch(@list_idx, 'no such index')

  if @list == 'no such index'
    session[:error] = 'The specified list was not found.'
    redirect '/'
  else
    erb :single_list, layout: :layout
  end
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

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Add a new todo to a list
post '/lists/:index_number/todos' do
  @list_idx = params[:index_number].to_i
  @list = load_list(@list_idx)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_idx}"
  end
end

# Render the edit list form
get '/list/:index_number/edit' do
  @list_idx = params[:index_number].to_i
  @list = load_list(@list_idx)
  erb :edit_list, layout: :layout
end

# Edit a list
post '/lists/:index_number/edit' do
  list_idx = params[:index_number].to_i
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][list_idx]= { name: list_name, todos: [] }
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{list_idx}"
  end
end

# Delete a list
post '/lists/:index_number/delete' do
  list_idx = params[:index_number].to_i
  session[:lists].delete_at(list_idx)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/"
  else
    session[:success] = 'The list has been deleted.'
    redirect "/lists"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Check all todos as done
post '/lists/:index_number/complete_todos' do
  list_idx = params[:index_number].to_i
  @list = load_list(list_idx)
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'The todos have been marked complete.'
  redirect "/lists/#{list_idx}"
end

=begin
This is another optional way of keeping track of todo items
in a single list. Rendering this in `single_list.erb` would
require removing the reference to `todo_idx` in the url for the
form which submits the post for deleting an item. As my code
takes another approach and renders properly, I chose not to
implement this.

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Add a new todo to a list
post '/lists/:index_number/todos' do
  @idx = params[:index_number].to_i
  @list = load_list(@list_idx)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@idx}"
  end
end

Original w/o modification
# Add a todo to a list
post '/lists/:index_number/todos' do
  @list_idx = params[:index_number].to_i
  @list = load_list(@list_idx)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_idx}"
  end
end

# Delete a todo item
post '/lists/:index_number/todos/:todo_index/delete' do
  list_idx = params[:index_number].to_i
  list = load_list(list_idx)

  todo = params[:todo_index].to_i
  list[:todos].delete_at(todo)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{list}"
  end
end

# Update the status of a todo
post '/lists/:index_number/todos/:id' do
  @list_idx = params[:index_number].to_i
  @list = load_list(@list_idx)

  todo_id = @list[params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_idx}"
end
=end