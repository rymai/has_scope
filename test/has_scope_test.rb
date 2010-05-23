require File.dirname(__FILE__) + '/test_helper'

class Tree
end

class TreesController < ApplicationController
  has_scope :color, :unless => :show_all_colors?
  has_scope :only_tall, :type => :boolean, :only => :index, :if => :restrict_to_only_tall_trees?
  has_scope :shadown_range, :default => 10, :except => [ :index, :show, :new ]
  has_scope :always_shadown_range, :default => 20, :always => true, :only => :other_edit
  has_scope :ignored_always_shadown_range, :always => true, :only => :another_edit
  has_scope :root_type, :as => :root, :allow_blank => true
  has_scope :calculate_height, :default => proc {|c| c.session[:height] || 20 }, :only => :new
  has_scope :paginate, :type => :hash
  has_scope :args_paginate, :type => :hash, :using => [:page, :per_page]
  has_scope :categories, :type => :array

  has_scope :only_short, :type => :boolean do |controller, scope|
    scope.only_really_short!(controller.object_id)
  end

  has_scope :by_category do |controller, scope, value|
    scope.by_given_category(controller.object_id, value + "_id")
  end

  def index
    @trees = apply_scopes(Tree).all
  end

  def new
    @tree = apply_scopes(Tree).new
  end

  def show
    @tree = apply_scopes(Tree).find(params[:id])
  end
  alias :edit :show
  alias :other_edit :show
  alias :another_edit :show

  protected
  def restrict_to_only_tall_trees?
    true
  end

  def show_all_colors?
    false
  end

  def default_render
    render :text => action_name
  end
end

class HasScopeTest < ActionController::TestCase
  tests TreesController

  def test_boolean_scope_is_called_when_boolean_param_is_true
    Tree.expects(:only_tall).with().returns(Tree).in_sequence
    Tree.expects(:all).returns([mock_tree]).in_sequence
    get :index, :only_tall => 'true'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :only_tall => true }, current_scopes)
  end

  def test_boolean_scope_is_not_called_when_boolean_param_is_false
    Tree.expects(:only_tall).never
    Tree.expects(:all).returns([mock_tree])
    get :index, :only_tall => 'false'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({}, current_scopes)
  end

  def test_scope_is_called_only_on_index
    Tree.expects(:only_tall).never
    Tree.expects(:find).with('42').returns(mock_tree)
    get :show, :only_tall => 'true', :id => '42'
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ }, current_scopes)
  end

  def test_scope_is_skipped_when_if_option_is_false
    @controller.stubs(:restrict_to_only_tall_trees?).returns(false)
    Tree.expects(:only_tall).never
    Tree.expects(:all).returns([mock_tree])
    get :index, :only_tall => 'true'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ }, current_scopes)
  end

  def test_scope_is_skipped_when_unless_option_is_true
    @controller.stubs(:show_all_colors?).returns(true)
    Tree.expects(:color).never
    Tree.expects(:all).returns([mock_tree])
    get :index, :color => 'blue'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ }, current_scopes)
  end

  def test_scope_is_called_except_on_index
    Tree.expects(:shadown_range).with().never
    Tree.expects(:all).returns([mock_tree])
    get :index, :shadown_range => 20
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ }, current_scopes)
  end

  def test_scope_is_called_with_arguments
    Tree.expects(:color).with('blue').returns(Tree).in_sequence
    Tree.expects(:all).returns([mock_tree]).in_sequence
    get :index, :color => 'blue'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :color => 'blue' }, current_scopes)
  end

  def test_scope_is_not_called_if_blank
    Tree.expects(:color).never
    Tree.expects(:all).returns([mock_tree]).in_sequence
    get :index, :color => ''
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ }, current_scopes)
  end

  def test_scope_is_called_when_blank_if_allow_blank_is_given
    Tree.expects(:root_type).with('').returns(Tree)
    Tree.expects(:all).returns([mock_tree]).in_sequence
    get :index, :root => ''
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :root => '' }, current_scopes)
  end

  def test_multiple_scopes_are_called
    Tree.expects(:only_tall).with().returns(Tree)
    Tree.expects(:color).with('blue').returns(Tree)
    Tree.expects(:all).returns([mock_tree])
    get :index, :color => 'blue', :only_tall => 'true'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :color => 'blue', :only_tall => true }, current_scopes)
  end

  def test_scope_of_type_hash
    hash = { "page" => "1", "per_page" => "10" }
    Tree.expects(:paginate).with(hash).returns(Tree)
    Tree.expects(:all).returns([mock_tree])
    get :index, :paginate => hash
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :paginate => hash }, current_scopes)
  end

  def test_scope_of_type_hash_with_using
    hash = { "page" => "1", "per_page" => "10" }
    Tree.expects(:args_paginate).with("1", "10").returns(Tree)
    Tree.expects(:all).returns([mock_tree])
    get :index, :args_paginate => hash
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :args_paginate => hash }, current_scopes)
  end

  def test_scope_of_type_array
    array = %w(book kitchen sport)
    Tree.expects(:categories).with(array).returns(Tree)
    Tree.expects(:all).returns([mock_tree])
    get :index, :categories => array
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :categories => array }, current_scopes)
  end

  def test_invalid_type_hash_for_default_type_scope
    assert_raise RuntimeError do
      get :index, :color => { :blue => :red }
    end
  end

  def test_invalid_type_string_for_hash_type_scope
    assert_raise RuntimeError do
      get :index, :paginate => "1"
    end
  end

  def test_scope_is_called_with_default_value
    Tree.expects(:shadown_range).with(10).returns(Tree).in_sequence
    Tree.expects(:find).with('42').returns(mock_tree).in_sequence
    get :edit, :id => '42'
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ :shadown_range => 10 }, current_scopes)
  end

  def test_default_scope_value_can_be_overwritten
    Tree.expects(:shadown_range).with('20').returns(Tree).in_sequence
    Tree.expects(:find).with('42').returns(mock_tree).in_sequence
    get :edit, :id => '42', :shadown_range => '20'
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ :shadown_range => '20' }, current_scopes)
  end

  def test_default_scope_should_not_be_called_if_any_scope_is_given
    Tree.expects(:color).with('red').returns(Tree).in_sequence
    Tree.expects(:find).with('42').returns(mock_tree).in_sequence
    get :edit, :id => '42', :color => 'red'
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ :color => 'red' }, current_scopes)
  end
  
  def test_default_scope_should_not_be_called_if_any_scope_is_given_unless_scope_has_the_always_options
    Tree.expects(:always_shadown_range).with(20).returns(Tree).in_sequence
    Tree.expects(:color).with('red').returns(Tree).in_sequence
    Tree.expects(:find).with('42').returns(mock_tree).in_sequence
    get :other_edit, :id => '42', :color => 'red'
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ :always_shadown_range => 20, :color => 'red' }, current_scopes)
  end

  def test_always_option_should_be_ignored_if_no_default_value_is_given
    Tree.expects(:color).with('red').returns(Tree).in_sequence
    Tree.expects(:find).with('42').returns(mock_tree).in_sequence
    get :another_edit, :id => '42', :color => 'red'
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ :color => 'red' }, current_scopes)
  end

  def test_scope_with_different_key
    Tree.expects(:root_type).with('outside').returns(Tree).in_sequence
    Tree.expects(:find).with('42').returns(mock_tree).in_sequence
    get :show, :id => '42', :root => 'outside'
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ :root => 'outside' }, current_scopes)
  end

  def test_scope_with_default_value_as_proc
    session[:height] = 100
    Tree.expects(:calculate_height).with(100).returns(Tree).in_sequence
    Tree.expects(:new).returns(mock_tree).in_sequence
    get :new
    assert_equal(mock_tree, assigns(:tree))
    assert_equal({ :calculate_height => 100 }, current_scopes)
  end

  def test_scope_with_boolean_block
    Tree.expects(:only_really_short!).with(@controller.object_id).returns(Tree)
    Tree.expects(:all).returns([mock_tree])
    get :index, :only_short => 'true'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :only_short => true }, current_scopes)
  end

  def test_scope_with_other_block_types
    Tree.expects(:by_given_category).with(@controller.object_id, 'for_id').returns(Tree)
    Tree.expects(:all).returns([mock_tree])
    get :index, :by_category => 'for'
    assert_equal([mock_tree], assigns(:trees))
    assert_equal({ :by_category => 'for' }, current_scopes)
  end

  protected

  def mock_tree(stubs={})
    @mock_tree ||= mock(stubs)
  end

  def current_scopes
    @controller.send :current_scopes
  end
end

class Flower
end

class FlowersController < ApplicationController
  has_scope :color
  has_scope :size
  has_scope :shadown_range, :default => 10, :only => :show

  def index
    @flowers = apply_scopes(Flower, :default => { :color => 'red', :size => 'huge' }).all
  end

  def show
    @flower = apply_scopes(Flower, :hash => params).find(params[:id])
  end
  
  def edit
    # Deprecated
    @flower = apply_scopes(Flower, { :color => 'red' }).find(params[:id])
  end

  protected
  def default_render
    render :text => action_name
  end

end

class HasDefaultScopeTest < ActionController::TestCase
  tests FlowersController

  def test_global_default_scope_is_called_if_no_current_scope_is_given
    Flower.expects(:color).with('red').returns(Flower).in_sequence
    Flower.expects(:size).with('huge').returns(Flower).in_sequence
    Flower.expects(:all).returns([mock_flower]).in_sequence
    get :index # without scope, should apply the default scope
    assert_equal([mock_flower], assigns(:flowers))
    assert_equal({ :color => 'red', :size => 'huge' }, current_scopes)
  end

  def test_global_default_scope_is_not_called_if_a_current_scope_is_given
    Flower.expects(:size).with('tiny').returns(Flower).in_sequence
    Flower.expects(:all).returns([mock_flower]).in_sequence
    get :index, :size => 'tiny' # without a given scope, should not apply the default scope
    assert_equal([mock_flower], assigns(:flowers))
    assert_equal({ :size => 'tiny' }, current_scopes)
  end

  def test_scope_with_default_value_are_called_when_no_scopes_given_and_no_global_default_scope_are_given
    Flower.expects(:shadown_range).with(10).returns(Flower).in_sequence
    Flower.expects(:find).with('42').returns(mock_flower).in_sequence
    get :show, :id => '42'
    assert_equal(mock_flower, assigns(:flower))
    assert_equal({ :shadown_range => 10 }, current_scopes)
  end

  def test_deprecated_call_of_apply_scopes_should_still_work
    Flower.expects(:color).with('red').returns(Flower).in_sequence
    Flower.expects(:find).with('42').returns(mock_flower).in_sequence
    get :edit, :id => '42'
    assert_equal(mock_flower, assigns(:flower))
    assert_equal({ :color => 'red' }, current_scopes)
  end

  protected

  def mock_flower(stubs={})
    @mock_flower ||= mock(stubs)
  end

  def current_scopes
    @controller.send :current_scopes
  end

end